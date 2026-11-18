#!/usr/bin/env python3
"""Extract quest facts from the pinned QuestieDB Forever data files.

Source of truth for bulk generation:
  https://github.com/Questie/QuestieDB  data/Forever/foreverQuestDB.lua
                                         data/Forever/foreverNpcDB.lua

The output is deterministic JSON: same input bytes and same selection give
byte-identical output. Generated files are never hand-edited; fix this
extractor and regenerate.

Only facts present in the database are emitted. Coordinates are copied from
NPC spawn data and are never guessed; an NPC without spawn data yields an
empty spawn table, which is a signal for a manual in-game check.

Forever-only quests (IDs 9xxxx) are not in the pinned QuestieDB. With
--pandabase-fallback, an ID that Questie lacks is read from its PandaBase
quest page instead; the fact then has "source": "pandabase" and its points
are PandaBase's recorded positions.

Usage:
  python tools/extract_questie.py --download              # fetch pinned DB into tools/.cache
  python tools/extract_questie.py --ids 7,783 --out -
  python tools/extract_questie.py --race Human --out facts_human.json
  python tools/extract_questie.py --ids 291,98323 --pandabase-fallback --out -
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
import urllib.request

PINNED_REF = "v1.0.16"
RAW_URL = "https://raw.githubusercontent.com/Questie/QuestieDB/{ref}/data/Forever/{name}"
QUEST_FILE = "foreverQuestDB.lua"
NPC_FILE = "foreverNpcDB.lua"
# sha256 of the files at PINNED_REF; --download refuses anything else.
PINNED_SHA256 = {
    QUEST_FILE: "621d4a1670232c047e7d171d8f1fdbd31581458935ee59dd70836016838dc942",
    NPC_FILE: "a8c4169690726323dac3c6441f74f7a4d9cafcc08ec42231d72ff28c9471f0ee",
}
CACHE_DIR = pathlib.Path(__file__).resolve().parent / ".cache"

# QuestieDB quest field positions (see questKeys in foreverQuestDB.lua).
QK = {
    "name": 1, "startedBy": 2, "finishedBy": 3, "requiredLevel": 4,
    "questLevel": 5, "requiredRaces": 6, "requiredClasses": 7,
    "objectivesText": 8, "preQuestGroup": 12, "preQuestSingle": 13,
    "childQuests": 14, "inGroupWith": 15, "exclusiveTo": 16,
    "zoneOrSort": 17, "nextQuestInChain": 22, "specialFlags": 24,
    "parentQuest": 25, "breadcrumbForQuestId": 27, "breadcrumbs": 28,
}
# QuestieDB NPC field positions (see npcKeys in foreverNpcDB.lua).
NK = {"name": 1, "spawns": 7, "zoneID": 9}

# Classic race IDs map to bit (id - 1). Skyborne bits per QuestieDB
# docs/questiedb-integration.md: IDs 95/96 use bits 32/33.
RACE_BITS = {
    0: "Human", 1: "Orc", 2: "Dwarf", 3: "Night Elf", 4: "Undead",
    5: "Tauren", 6: "Gnome", 7: "Troll",
    32: "Skyborne (Alliance)", 33: "Skyborne (Horde)",
}
CLASS_BITS = {
    0: "Warrior", 1: "Paladin", 2: "Hunter", 3: "Rogue", 4: "Priest",
    6: "Shaman", 7: "Mage", 8: "Warlock", 10: "Druid",
}

# Questie zone (AreaTable) ID -> (zone name, UiMapID). Spawns in QuestieDB
# are keyed by the zone ID; waypoints need the UiMapID. tools/gen_saga.py
# checks each UiMapID against the mapId on the PandaBase quest pages, so a
# wrong row fails the build instead of a waypoint. Add a row only when a
# saga needs that zone.
ZONES = {
    1: ("Dun Morogh", 1426),
    3: ("Badlands", 1418),
    4: ("Blasted Lands", 1419),
    8: ("Swamp of Sorrows", 1435),
    10: ("Duskwood", 1431),
    11: ("Wetlands", 1437),
    12: ("Elwynn Forest", 1429),
    14: ("Durotar", 1411),
    15: ("Dustwallow Marsh", 1445),
    16: ("Azshara", 1447),
    17: ("The Barrens", 1413),
    28: ("Western Plaguelands", 1422),
    33: ("Stranglethorn Vale", 1434),
    38: ("Loch Modan", 1432),
    40: ("Westfall", 1436),
    44: ("Redridge Mountains", 1433),
    45: ("Arathi Highlands", 1417),
    46: ("Burning Steppes", 1428),
    47: ("The Hinterlands", 1425),
    51: ("Searing Gorge", 1427),
    85: ("Tirisfal Glades", 1420),
    130: ("Silverpine Forest", 1421),
    139: ("Eastern Plaguelands", 1423),
    141: ("Teldrassil", 1438),
    148: ("Darkshore", 1439),
    215: ("Mulgore", 1412),
    267: ("Hillsbrad Foothills", 1424),
    331: ("Ashenvale", 1440),
    357: ("Feralas", 1444),
    361: ("Felwood", 1448),
    400: ("Thousand Needles", 1441),
    405: ("Desolace", 1443),
    440: ("Tanaris", 1446),
    406: ("Stonetalon Mountains", 1442),
    490: ("Un'Goro Crater", 1449),
    493: ("Moonglade", 1450),
    618: ("Winterspring", 1452),
    1377: ("Silithus", 1451),
    1497: ("Undercity", 1458),
    1519: ("Stormwind City", 1453),
    1537: ("Ironforge", 1455),
    1637: ("Orgrimmar", 1454),
    1638: ("Thunder Bluff", 1456),
    1657: ("Darnassus", 1457),
}
ZONE_IDS = {name: zone_id for zone_id, (name, _) in ZONES.items()}


# ---------------------------------------------------------------- Lua literals
class LuaParseError(ValueError):
    pass


_NUM = re.compile(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")
_DEC = re.compile(r"\d{1,3}")  # Lua \ddd decimal escape
_ESC ={"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "0": "\0"}


def parse_lua(text: str):
    """Parse one Lua literal (table/string/number/bool/nil) from ``text``."""
    value, pos = _value(text, _ws(text, 0))
    if _ws(text, pos) != len(text):
        raise LuaParseError(f"trailing data at {pos}: {text[pos:pos + 30]!r}")
    return value


def _ws(s: str, i: int) -> int:
    n = len(s)
    while i < n:
        if s[i] in " \t\r\n":
            i += 1
        elif s.startswith("--", i):
            j = s.find("\n", i)
            i = n if j < 0 else j + 1
        else:
            break
    return i


def _value(s: str, i: int):
    if i >= len(s):
        raise LuaParseError("unexpected end of input")
    c = s[i]
    if c == "{":
        return _table(s, i)
    if c in "\"'":
        return _string(s, i)
    for word, val in (("nil", None), ("true", True), ("false", False)):
        if s.startswith(word, i) and not (s[i + len(word):i + len(word) + 1].isalnum()):
            return val, i + len(word)
    m = _NUM.match(s, i)
    if not m:
        raise LuaParseError(f"unexpected {s[i:i + 20]!r} at {i}")
    txt = m.group(0)
    num = float(txt) if any(ch in txt for ch in ".eE") else int(txt)
    return num, m.end()


def _string(s: str, i: int):
    quote = s[i]
    out = []
    i += 1
    n = len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            i += 1
            if s[i].isdigit():
                m = _DEC.match(s, i)
                out.append(chr(int(m.group(0))))
                i = m.end()
                continue
            out.append(_ESC.get(s[i], s[i]))
        elif c == quote:
            return "".join(out), i + 1
        else:
            out.append(c)
        i += 1
    raise LuaParseError("unterminated string")


def _table(s: str, i: int):
    """Parse a table. Returns a dict when any explicit key is used, else a list.

    Lists keep ``None`` for ``nil`` slots so positional indexes survive.
    """
    i = _ws(s, i + 1)
    items: list = []
    keyed: dict = {}
    while True:
        i = _ws(s, i)
        if s[i] == "}":
            break
        if s[i] == "[":
            j = _ws(s, i + 1)
            key, j = _value(s, j)
            j = _ws(s, j)
            if s[j] != "]":
                raise LuaParseError(f"expected ] at {j}")
            j = _ws(s, j + 1)
            if s[j] != "=":
                raise LuaParseError(f"expected = at {j}")
            val, i = _value(s, _ws(s, j + 1))
            keyed[key] = val
        else:
            val, i = _value(s, i)
            items.append(val)
        i = _ws(s, i)
        if s[i] in ",;":
            i += 1
    result = keyed if keyed else items
    if keyed and items:
        for idx, v in enumerate(items, 1):
            keyed.setdefault(idx, v)
    return result, i + 1


# ------------------------------------------------------------------ DB loading
_ENTRY = re.compile(r"^\[(\d+)\] = (\{.*\}),?\s*$")


class EntityDB:
    """Lazily parsed ``[id] = {...},`` rows from a QuestieDB data file."""

    def __init__(self, text: str):
        self._raw: dict[int, str] = {}
        self._cache: dict[int, list] = {}
        for line in text.splitlines():
            m = _ENTRY.match(line)
            if m:
                self._raw[int(m.group(1))] = m.group(2)

    @classmethod
    def from_path(cls, path: pathlib.Path) -> "EntityDB":
        return cls(pathlib.Path(path).read_text(encoding="utf-8"))

    def __len__(self) -> int:
        return len(self._raw)

    def __contains__(self, entity_id: int) -> bool:
        return entity_id in self._raw

    def ids(self) -> list[int]:
        return sorted(self._raw)

    def get(self, entity_id: int) -> list | None:
        if entity_id not in self._raw:
            return None
        if entity_id not in self._cache:
            self._cache[entity_id] = parse_lua(self._raw[entity_id])
        return self._cache[entity_id]


def _field(row: list, key: int):
    return row[key - 1] if key - 1 < len(row) else None


def decode_mask(mask: int | None, table: dict[int, str]) -> tuple[list[str], list[int]]:
    """Return (known names, unknown bit positions) for a bitmask."""
    if not mask:
        return [], []
    names, unknown = [], []
    for bit in range(mask.bit_length()):
        if mask >> bit & 1:
            if bit in table:
                names.append(table[bit])
            else:
                unknown.append(bit)
    return names, unknown


def _npc_fact(npc_db: EntityDB | None, npc_id: int) -> dict:
    fact: dict = {"id": npc_id, "name": None, "zoneID": None, "spawns": {}}
    row = npc_db.get(npc_id) if npc_db else None
    if row is None:
        return fact
    fact["name"] = _field(row, NK["name"])
    fact["zoneID"] = _field(row, NK["zoneID"])
    spawns = _field(row, NK["spawns"]) or {}
    fact["spawns"] = {str(z): [list(p) for p in pts] for z, pts in sorted(spawns.items())}
    return fact


def _endpoint(raw, npc_db: EntityDB | None) -> dict:
    """Decode startedBy/finishedBy: {{creatures},{objects},{items}}."""
    raw = raw or []
    creatures = (raw[0] if len(raw) > 0 else None) or []
    objects = (raw[1] if len(raw) > 1 else None) or []
    items = (raw[2] if len(raw) > 2 else None) or []
    return {
        "creatures": [_npc_fact(npc_db, c) for c in creatures],
        "objects": list(objects),
        "items": list(items),
    }


def quest_fact(quest_id: int, quest_db: EntityDB, npc_db: EntityDB | None) -> dict | None:
    row = quest_db.get(quest_id)
    if row is None:
        return None
    races, race_unknown = decode_mask(_field(row, QK["requiredRaces"]), RACE_BITS)
    classes, class_unknown = decode_mask(_field(row, QK["requiredClasses"]), CLASS_BITS)
    return {
        "id": quest_id,
        "source": "questie",
        "name": _field(row, QK["name"]),
        "requiredLevel": _field(row, QK["requiredLevel"]),
        "questLevel": _field(row, QK["questLevel"]),
        "requiredRaces": _field(row, QK["requiredRaces"]) or 0,
        "races": races,
        "unmappedRaceBits": race_unknown,
        "requiredClasses": _field(row, QK["requiredClasses"]) or 0,
        "classes": classes,
        "unmappedClassBits": class_unknown,
        "zoneOrSort": _field(row, QK["zoneOrSort"]),
        "objectivesText": _field(row, QK["objectivesText"]) or [],
        "startedBy": _endpoint(_field(row, QK["startedBy"]), npc_db),
        "finishedBy": _endpoint(_field(row, QK["finishedBy"]), npc_db),
        "preQuestGroup": _field(row, QK["preQuestGroup"]) or [],
        "preQuestSingle": _field(row, QK["preQuestSingle"]) or [],
        "exclusiveTo": _field(row, QK["exclusiveTo"]) or [],
        "nextQuestInChain": _field(row, QK["nextQuestInChain"]),
        "parentQuest": _field(row, QK["parentQuest"]),
        "breadcrumbForQuestId": _field(row, QK["breadcrumbForQuestId"]),
        "breadcrumbs": _field(row, QK["breadcrumbs"]) or [],
        "specialFlags": _field(row, QK["specialFlags"]) or 0,
    }


def _pandabase_endpoint(ep: dict) -> dict:
    """A PandaBase start/end in the Questie endpoint shape.

    PandaBase gives no NPC ID, so ``id`` is None. The point is PandaBase's
    own recorded position, never a guess: an unknown zone or an unlocated
    endpoint gives an empty spawn table (the manual-check signal).
    """
    out = {"creatures": [], "objects": [], "items": [], "pandabase": ep}
    if ep.get("kind") == "npc":
        zone_id = ZONE_IDS.get(ep.get("zone"))
        spawns = {str(zone_id): [[ep["x"], ep["y"]]]} if zone_id and ep.get("located") else {}
        out["creatures"].append({"id": None, "name": ep.get("name"), "zoneID": zone_id, "spawns": spawns})
    return out


def pandabase_fact(quest_id: int, pb: dict) -> dict:
    """Quest facts from a parsed PandaBase page, for a quest Questie lacks.

    Forever adds quests (IDs 9xxxx) that the pinned QuestieDB does not have.
    The shape matches quest_fact(); ``source`` tells the two apart.
    """
    after = pb.get("after") or []
    start_zone = (pb.get("startedBy") or {}).get("zone")
    return {
        "id": quest_id,
        "source": "pandabase",
        "name": pb.get("name"),
        "requiredLevel": pb.get("requiredLevel"),
        "questLevel": pb.get("questLevel"),
        "requiredRaces": None,
        "races": list(pb.get("races") or []),
        "unmappedRaceBits": [],
        "requiredClasses": None,
        "classes": list(pb.get("classes") or []),
        "unmappedClassBits": [],
        "zoneOrSort": ZONE_IDS.get(start_zone),
        "objectivesText": [pb["objective"]] if pb.get("objective") else [],
        "startedBy": _pandabase_endpoint(pb.get("startedBy") or {}),
        "finishedBy": _pandabase_endpoint(pb.get("finishedBy") or {}),
        "preQuestGroup": list(pb.get("beforeAll") or []),
        "preQuestSingle": list(pb.get("beforeAny") or []),
        "exclusiveTo": [],
        "nextQuestInChain": after[0] if len(after) == 1 else None,
        "parentQuest": None,
        "breadcrumbForQuestId": None,
        "breadcrumbs": [],
        "specialFlags": 0,
    }


def race_bit(name: str) -> int:
    for bit, label in RACE_BITS.items():
        if label.lower() == name.lower():
            return bit
    raise SystemExit(f"unknown race {name!r}; known: {', '.join(RACE_BITS.values())}")


def select_ids(quest_db: EntityDB, ids: list[int] | None, race: str | None) -> list[int]:
    if ids is not None:
        return sorted(set(ids))
    selected = quest_db.ids()
    if race:
        bit = race_bit(race)
        # Mask 0 means "any race"; those are excluded so output stays race-specific.
        selected = [
            q for q in selected
            if (_field(quest_db.get(q), QK["requiredRaces"]) or 0) >> bit & 1
        ]
    return selected


def build_output(quest_db: EntityDB, npc_db: EntityDB | None, ids: list[int],
                 source: dict, fallback=None) -> dict:
    """Facts for ``ids``. ``fallback(qid)`` returns a parsed PandaBase page
    (or None) for an ID that Questie lacks; without it such IDs are missing."""
    quests, missing, from_pb = [], [], []
    for qid in ids:
        fact = quest_fact(qid, quest_db, npc_db)
        if fact is None and fallback is not None:
            pb = fallback(qid)
            if pb is not None:
                fact = pandabase_fact(qid, pb)
                from_pb.append(qid)
        (quests if fact else missing).append(fact or qid)
    out = {"source": source, "missing": sorted(missing), "quests": quests}
    if fallback is not None:
        out["pandabase"] = sorted(from_pb)
    return out


def fetch_pandabase(quest_id: int) -> dict | None:
    import verify_pandabase  # same folder; only needed for the fallback

    page = verify_pandabase.fetch_page(quest_id)
    return verify_pandabase.parse_quest_page(page) if page else None


def dumps(data: dict) -> str:
    return json.dumps(data, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


# -------------------------------------------------------------------- download
def sha256_file(path: pathlib.Path) -> str:
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def download(ref: str = PINNED_REF, cache: pathlib.Path = CACHE_DIR) -> dict[str, pathlib.Path]:
    """Fetch the data files for ``ref`` into the cache, verifying pinned hashes."""
    cache = pathlib.Path(cache) / ref
    cache.mkdir(parents=True, exist_ok=True)
    paths = {}
    for name in (QUEST_FILE, NPC_FILE):
        dest = cache / name
        if not dest.exists():
            req = urllib.request.Request(RAW_URL.format(ref=ref, name=name),
                                         headers={"User-Agent": "wow-forever-saga-guide-tools"})
            with urllib.request.urlopen(req, timeout=120) as resp:  # noqa: S310 (pinned https URL)
                dest.write_bytes(resp.read())
        if ref == PINNED_REF and sha256_file(dest) != PINNED_SHA256[name]:
            actual = sha256_file(dest)
            dest.unlink()
            raise SystemExit(f"{name}: sha256 {actual} does not match the pin for {ref}")
        paths[name] = dest
    return paths


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--download", action="store_true", help="fetch the pinned DB into tools/.cache first")
    ap.add_argument("--ref", default=PINNED_REF, help="QuestieDB tag (default: %(default)s)")
    ap.add_argument("--quest-db", type=pathlib.Path)
    ap.add_argument("--npc-db", type=pathlib.Path)
    ap.add_argument("--ids", help="comma-separated quest IDs")
    ap.add_argument("--race", help="select quests restricted to this race, e.g. Human")
    ap.add_argument("--out", default="-", help="output path, or - for stdout")
    ap.add_argument("--pandabase-fallback", action="store_true",
                    help="with --ids: read PandaBase for IDs the Questie DB lacks (Forever-only quests)")
    args = ap.parse_args(argv)

    if args.download:
        paths = download(args.ref)
        args.quest_db = args.quest_db or paths[QUEST_FILE]
        args.npc_db = args.npc_db or paths[NPC_FILE]
    else:
        cached = CACHE_DIR / args.ref
        args.quest_db = args.quest_db or cached / QUEST_FILE
        args.npc_db = args.npc_db or cached / NPC_FILE
    if not args.quest_db.exists():
        ap.error(f"{args.quest_db} not found; run with --download or pass --quest-db")
    if bool(args.ids) == bool(args.race):
        ap.error("pass exactly one of --ids or --race")
    if args.pandabase_fallback and not args.ids:
        ap.error("--pandabase-fallback needs --ids")

    quest_db = EntityDB.from_path(args.quest_db)
    npc_db = EntityDB.from_path(args.npc_db) if args.npc_db.exists() else None
    ids = [int(x) for x in args.ids.split(",")] if args.ids else None
    selected = select_ids(quest_db, ids, args.race)
    source = {
        "ref": args.ref,
        "questDbSha256": sha256_file(args.quest_db),
        "npcDbSha256": sha256_file(args.npc_db) if npc_db else None,
    }
    fallback = fetch_pandabase if args.pandabase_fallback else None
    text = dumps(build_output(quest_db, npc_db, selected, source, fallback))
    if args.out == "-":
        sys.stdout.write(text)
    else:
        pathlib.Path(args.out).write_text(text, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
