#!/usr/bin/env python3
"""Generate a race saga's Data_<Saga>.lua and Route_<Saga>.lua (issue #13).

Inputs, both in tools/sagas/:
  <name>.json        hand-written spec: chain IDs, names, summaries, quest
                     order, kinds, notes and route task text. No coordinates.
  <name>.facts.json  facts snapshot: Questie facts for each quest (PandaBase
                     facts for Forever-only IDs Questie lacks) plus the parsed
                     PandaBase page of each quest. Made by the `facts` command.

Every quest name, giver, level, class gate and point comes from the facts.
A giver with no recorded point gets no x/y and goes on the manual-check list
(<name>.manual.json); points are never guessed. The output is the same for
the same inputs, carries the generated-file marker, and must never be
hand-edited: change the spec or this tool, then regenerate. A run never
overwrites a file that lacks the marker.

A spec with "chainsOnly": true (issue #38) writes only Data_<file>.lua, for a
chain that another saga's route walks (the Human Missing Diplomat). It needs
"file", and its route stays hand-written in Route_<Saga>.lua.

A side-zone spec (issue #21, key "sideZones") writes MainStoryGuide/ZoneSideQuests.lua:
one list of side quests for each zone, never on a saga route. It is built from the
same kind of facts snapshot (tools/sagas/side_zones.facts.json).

A side-zone spec (issue #21, key "sideZones") writes MainStoryGuide/ZoneSideQuests.lua:
one list of side quests for each zone, never on a saga route. It uses the same kind of
facts snapshot (tools/sagas/side_zones.facts.json).

Usage:
  python tools/gen_saga.py facts --spec tools/sagas/dwarf.json   # network: Questie cache + PandaBase
  python tools/gen_saga.py build --spec tools/sagas/dwarf.json   # offline, deterministic
  python tools/gen_saga.py build --all                           # every spec in tools/sagas
  python tools/genmanifest.py update
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import math
import pathlib
import re
import sys

import extract_questie as eq
import genmanifest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SAGA_DIR = pathlib.Path(__file__).resolve().parent / "sagas"
ADDON = ROOT / "MainStoryGuide"
KINDS = {"lead", "dungeon", "item", "drop"}
# Spec keys per quest; anything else is a typo and fails the build.
# exclusiveWith (issue #56): IDs of quests of the same chain that the player takes
# instead of this one; the resolver counts the group as one step.
QUEST_KEYS = {"id", "kind", "note", "requires", "task", "deferUntilAvailable", "startSource", "giverFrom",
              "exclusiveWith"}
# Top-level spec keys; routeTasks holds this saga's task text for routeExternal quests.
# chainsOnly (issue #38): write Data_<file>.lua only; the route stays hand-written.
# pandabaseFacts (issue #69): quest IDs whose facts come from the PandaBase page.
SPEC_KEYS = {"saga", "file", "comment", "chains", "route", "routeExternal", "routeTasks", "chainsOnly",
             "pandabaseFacts"}
# giverFrom: "pandabase" takes the giver name and point from the PandaBase
# page when Forever moved the start away from the Questie giver.
GIVER_SOURCES = {"pandabase"}
# faction (issue #20): a Neutral chain that only one faction can take (a dungeon
# coda with Alliance-only or Horde-only quests); Sagas.ChainGroup reads it.
# after (issue #74): chain IDs that must come before this chain in a saga view, because a quest
# of this chain needs a quest of each of them; ns.RebuildView follows it. It may name a chain
# of another spec, so the generator checks the form only (tests/test_race_sagas.py checks the IDs).
# classSpecific (issue #41): the chain is a class chain. Every quest in it needs a class gate in the
# facts (written as `class = ".."`), and none may be on the route. Core.lua shows the chain only to
# a player of that class.
CHAIN_KEYS = {"id", "name", "zone", "summary", "walkers", "quests", "faction", "after", "classSpecific"}
FACTIONS = {"Alliance", "Horde"}
# Side-zone spec (issue #21): ZoneSideQuests.lua, one quest list for each zone.
SIDE_SPEC_KEYS = {"sideZones", "file", "comment", "zones"}
SIDE_ZONE_KEYS = {"name", "quests"}
# Side rows: prerequisites come from the facts; noTurnPoint leaves the hand-in point to an
# in-game check when the two sources disagree on where it is (quest 6601).
SIDE_QUEST_KEYS = (QUEST_KEYS - {"requires", "exclusiveWith"}) | {"noTurnPoint"}
ALLIANCE_RACES = {"Human", "Dwarf", "Night Elf", "Gnome", "Skyborne (Alliance)"}
HORDE_RACES = {"Orc", "Undead", "Tauren", "Troll", "Skyborne (Horde)"}
# Quest rows of every hand-written or generated Data file: `{ id = 123,`.
MAIN_ROW = re.compile(r"\{\s*id\s*=\s*(\d+)\s*,")
# Saga key (the UnitRace token) -> race name in the Questie and PandaBase data.
RACE_LABELS = {"NightElf": "Night Elf", "Scourge": "Undead"}
SAGA_NAME = re.compile(r"[A-Za-z]+")
CHAIN_ID = re.compile(r"[a-z0-9_]+")


class SpecError(ValueError):
    pass


# ------------------------------------------------------------------ helpers
def lua_str(value: str) -> str:
    """A Lua string literal for text from Questie, PandaBase or a spec.

    The text is untrusted: a quote, backslash or line break must not end
    the literal, and a control character is written as a \\ddd escape. A
    WoW UI escape (|c colour, |T texture, |H link) is neutralised by
    doubling the pipe, which the client shows as one literal "|".
    """
    out = []
    for ch in str(value):
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "|":
            out.append("||")
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append(f"\\{ord(ch):03d}")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def lua_num(value: float) -> str:
    return f"{value:.1f}"


def lua_point(point: dict) -> str:
    """`map = .., x = .., y = ..` for a point from _place()."""
    return f"map = {point['map']}, x = {lua_num(point['x'])}, y = {lua_num(point['y'])}"


def spec_paths(spec_path: pathlib.Path) -> dict[str, pathlib.Path]:
    stem = spec_path.name[: -len(".json")]
    return {
        "facts": spec_path.with_name(f"{stem}.facts.json"),
        "manual": spec_path.with_name(f"{stem}.manual.json"),
    }


def load_spec(spec_path: pathlib.Path) -> dict:
    spec = json.loads(pathlib.Path(spec_path).read_text(encoding="utf-8"))
    for key in ("saga", "chains", "route"):
        if key not in spec:
            raise SpecError(f"{spec_path}: missing '{key}'")
    extra = {k for k in set(spec) - SPEC_KEYS if not str(k).startswith("_")}
    if extra:
        raise SpecError(f"{spec_path}: unknown keys {sorted(extra)}")
    # saga/file name output paths (Data_<file>.lua): letters only, so a
    # spec can never write outside MainStoryGuide/.
    for key in ("saga", "file"):
        if key in spec and not SAGA_NAME.fullmatch(str(spec[key])):
            raise SpecError(f"{spec_path}: '{key}' must be letters only, got {spec[key]!r}")
    if "chainsOnly" in spec:
        if type(spec["chainsOnly"]) is not bool:
            raise SpecError(f"{spec_path}: chainsOnly must be true or false")
        if spec["chainsOnly"] and "file" not in spec:
            raise SpecError(f"{spec_path}: chainsOnly needs 'file', so it cannot write the saga's own Data file")
        if spec["chainsOnly"] and (spec["route"] or spec.get("routeExternal") or spec.get("routeTasks")):
            raise SpecError(f"{spec_path}: chainsOnly takes no route, routeExternal or routeTasks")
    pb_ids = spec.get("pandabaseFacts", [])
    held = {q["id"] for c in spec["chains"] for q in c["quests"]}
    if not isinstance(pb_ids, list) or not all(type(i) is int and i in held for i in pb_ids):
        raise SpecError(f"{spec_path}: pandabaseFacts must list quest IDs that a chain holds")
    for chain in spec["chains"]:
        extra = set(chain) - CHAIN_KEYS
        if extra:
            raise SpecError(f"chain {chain.get('id')}: unknown keys {sorted(extra)}")
        if "faction" in chain and chain["faction"] not in FACTIONS:
            raise SpecError(f"chain {chain.get('id')}: faction must be one of {sorted(FACTIONS)}")
        if "classSpecific" in chain and chain["classSpecific"] is not True:
            raise SpecError(f"chain {chain.get('id')}: classSpecific must be true (or left out)")
        if not CHAIN_ID.fullmatch(str(chain.get("id"))):
            raise SpecError(f"chain id {chain.get('id')!r}: use lower-case letters, digits and _")
        chain_ids = {q["id"] for q in chain["quests"]}
        if "after" in chain:
            after = chain["after"]
            if (not isinstance(after, list) or not after or len(set(map(str, after))) != len(after)
                    or not all(isinstance(a, str) and CHAIN_ID.fullmatch(a) and a != chain["id"] for a in after)):
                raise SpecError(f"chain {chain['id']}: after must be a list of other chain IDs, each once")
        for q in chain["quests"]:
            extra = set(q) - QUEST_KEYS
            if extra:
                raise SpecError(f"quest {q.get('id')}: unknown keys {sorted(extra)}")
            if "exclusiveWith" in q:
                ex = q["exclusiveWith"]
                if not (isinstance(ex, list) and ex and all(type(i) is int and i != q["id"] and i in chain_ids
                                                            for i in ex)):
                    raise SpecError(f"quest {q['id']}: exclusiveWith must list other quest IDs of the same chain")
        by_id = {q["id"]: q for q in chain["quests"]}
        for q in chain["quests"]:
            for other in q.get("exclusiveWith", []):
                if q["id"] not in by_id[other].get("exclusiveWith", []):
                    raise SpecError(f"quest {q['id']}: exclusiveWith {other}, but quest {other} does not list {q['id']}")
            if q.get("kind") and q["kind"] not in KINDS:
                raise SpecError(f"quest {q['id']}: unknown kind {q['kind']!r}")
            if "giverFrom" in q and q["giverFrom"] not in GIVER_SOURCES:
                raise SpecError(f"quest {q['id']}: giverFrom must be one of {sorted(GIVER_SOURCES)}")
    route_tasks(spec)
    return spec


def route_tasks(spec: dict) -> dict[int, str]:
    """routeTasks: {"<questID>": "task"} for routeExternal quests only.

    The text goes to ns.RouteInfoBySaga[saga] and replaces the task of the
    owner's RouteInfo for this saga only (the Night Elf road from Menethil
    Harbor to Westfall, issue #43). A saga's own quests take "task" in the chain.
    """
    raw = spec.get("routeTasks", {})
    if not isinstance(raw, dict):
        raise SpecError("routeTasks must be an object of quest ID -> task")
    external = set(spec.get("routeExternal", [])) & set(spec.get("route", []))
    out: dict[int, str] = {}
    for key, task in raw.items():
        if not (isinstance(key, str) and key.isdigit() and int(key) in external):
            raise SpecError(f"routeTasks key {key!r} is not a routeExternal quest on the route")
        if not (isinstance(task, str) and task.strip()):
            raise SpecError(f"routeTasks[{key}] must be a non-empty string")
        out[int(key)] = task
    return out


def spec_ids(spec: dict) -> list[int]:
    ids = [q["id"] for c in spec["chains"] for q in c["quests"]]
    if len(ids) != len(set(ids)):
        dup = sorted({i for i in ids if ids.count(i) > 1})
        raise SpecError(f"quest IDs in more than one chain: {dup}")
    return ids


# ------------------------------------------------------------------- points
def _zone(zone_id) -> tuple[str, int] | None:
    try:
        return eq.ZONES.get(int(zone_id))
    except (TypeError, ValueError):
        return None


def _check_map(zone_name: str, ui_map: int, pb: dict | None) -> None:
    """Fail when PandaBase draws this zone on another UiMapID."""
    if pb and pb.get("mapId") and pb.get("mapZone") == zone_name and pb["mapId"] != ui_map:
        raise SpecError(f"quest {pb.get('id')}: ZONES gives {zone_name} UiMapID {ui_map}, "
                        f"PandaBase gives {pb['mapId']}; fix extract_questie.ZONES")


def creature_point(endpoint: dict, pb_ep: dict | None, pb: dict | None) -> dict | None:
    """Pick one recorded spawn of the endpoint's creature(s).

    Prefer the creature's home zone; within a zone prefer the spawn nearest
    the point PandaBase records for this quest. None when nothing is
    recorded in a zone the guide knows.
    """
    for creature in endpoint.get("creatures") or []:
        spawns = creature.get("spawns") or {}
        keys = [k for k in spawns if _zone(k)]
        if not keys:
            continue
        home = str(creature.get("zoneID"))
        key = home if home in keys else sorted(keys, key=int)[0]
        zone_name, ui_map = _zone(key)
        _check_map(zone_name, ui_map, pb)
        points = spawns[key]
        if pb_ep and pb_ep.get("located") and pb_ep.get("zone") == zone_name:
            px, py = pb_ep["x"], pb_ep["y"]
            points = sorted(points, key=lambda p: (math.hypot(p[0] - px, p[1] - py), p))
        return _place(creature.get("name"), zone_name, ui_map, points[0][0], points[0][1])
    return None


def pandabase_point(pb_ep: dict | None, pb: dict | None) -> dict | None:
    """A point PandaBase records for an object/item endpoint."""
    if not (pb_ep and pb_ep.get("located")):
        return None
    zone_id = eq.ZONE_IDS.get(pb_ep.get("zone"))
    if not zone_id:
        return None
    zone_name, ui_map = eq.ZONES[zone_id]
    _check_map(zone_name, ui_map, pb)
    return _place(pb_ep.get("name"), zone_name, ui_map, pb_ep["x"], pb_ep["y"])


def _place(name, zone_name: str, ui_map: int, x: float, y: float) -> dict:
    return {"name": name, "zone": zone_name, "map": ui_map, "x": round(x, 1), "y": round(y, 1)}


def endpoint_point(endpoint: dict, pb_ep: dict | None, pb: dict | None) -> dict | None:
    """A recorded point: a Questie spawn first, else the PandaBase record."""
    return creature_point(endpoint, pb_ep, pb) or pandabase_point(pb_ep, pb)


def _creatures(endpoint: dict) -> list[dict]:
    return endpoint.get("creatures") or []


def endpoint_name(endpoint: dict, pb_ep: dict | None) -> str | None:
    names = [c["name"] for c in _creatures(endpoint) if c.get("name")]
    return names[0] if names else (pb_ep or {}).get("name")


# PandaBase names a dungeon area or a synthetic map in the zone field of an endpoint (issue #20);
# neither is a place name, so the chain zone stands in.
PLACEHOLDER_ZONES = ("Referenced ", "Synthetic ")


def endpoint_zone(endpoint: dict, pb_ep: dict | None) -> str | None:
    zones = [z[0] for z in (_zone(c.get("zoneID")) for c in _creatures(endpoint)) if z]
    if zones:
        return zones[0]
    zone = (pb_ep or {}).get("zone")
    return None if isinstance(zone, str) and zone.startswith(PLACEHOLDER_ZONES) else zone


def same_npc(a: dict, b: dict) -> bool:
    ida = [c.get("id") for c in _creatures(a)]
    if ida and ida == [c.get("id") for c in _creatures(b)] and None not in ida:
        return True
    na = [c.get("name") for c in _creatures(a)]
    return bool(na) and na == [c.get("name") for c in _creatures(b)]


# ------------------------------------------------------------------- facts
def facts_index(facts: dict) -> tuple[dict[int, dict], dict[int, dict]]:
    quests = {q["id"]: q for q in facts["quests"]}
    pages = {int(k): v for k, v in (facts.get("pandabase_pages") or {}).items()}
    return quests, pages


FETCH_WORKERS = 8
MAX_FETCH_WORKERS = 16  # a larger pool only hits the PandaBase rate limit


def prefetch(ids, fetch, pages: dict, workers: int = FETCH_WORKERS) -> None:
    """Fill ``pages`` with the parsed PandaBase page (or None) of each ID not
    in it yet, ``workers`` requests at a time. The result does not depend on
    the order the requests finish in."""
    todo = [i for i in dict.fromkeys(ids) if i not in pages]
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for qid, page in zip(todo, pool.map(fetch, todo)):
            pages[qid] = page


def make_facts(spec: dict, download: bool = False, fetch=None, pages: dict | None = None) -> dict:
    """Questie facts (+ PandaBase fallback) and the PandaBase page of each ID.

    ``pages`` is a page cache shared by the specs of one run: the Dwarf and
    Gnome specs share most of their quest IDs.
    """
    ids = sorted(set(spec_ids(spec)) | set(spec.get("routeExternal", [])))
    if download:
        paths = eq.download()
        quest_db, npc_db = paths[eq.QUEST_FILE], paths[eq.NPC_FILE]
    else:
        quest_db = eq.CACHE_DIR / eq.PINNED_REF / eq.QUEST_FILE
        npc_db = eq.CACHE_DIR / eq.PINNED_REF / eq.NPC_FILE
    if not quest_db.exists():
        raise SystemExit(f"{quest_db} not found; run with --download")
    pages = {} if pages is None else pages
    prefetch(ids, fetch or eq.fetch_pandabase, pages)
    source = {"ref": eq.PINNED_REF, "questDbSha256": eq.sha256_file(quest_db),
              "npcDbSha256": eq.sha256_file(npc_db)}
    out = eq.build_output(eq.EntityDB.from_path(quest_db), eq.EntityDB.from_path(npc_db),
                          ids, source, pages.get)
    # pandabaseFacts: Forever gates these quests by class, and Questie gives no gate.
    # Their facts come from the PandaBase page, as for a quest that Questie lacks.
    no_page = [q for q in spec.get("pandabaseFacts", []) if not pages.get(q)]
    if no_page:
        raise SpecError(f"no PandaBase page for pandabaseFacts {no_page}")
    swap = {q: eq.pandabase_fact(q, pages[q]) for q in spec.get("pandabaseFacts", [])}
    if swap:
        rest = [f for f in out["quests"] if f["id"] not in swap]
        out["quests"] = sorted(rest + list(swap.values()), key=lambda f: f["id"])
        out["missing"] = [i for i in out["missing"] if i not in swap]
        out["pandabase"] = sorted(set(out["pandabase"]) | set(swap))
    out["pandabase_pages"] = {str(k): pages[k] for k in ids if pages[k] is not None}
    out["pandabase_missing"] = [k for k in ids if pages[k] is None]
    return out


# ------------------------------------------------------------------- build
def _check_walkers(qid: int, fact: dict, walkers: list[str]) -> None:
    races = fact.get("races") or []
    for walker in walkers:
        label = RACE_LABELS.get(walker, walker)
        if races and label not in races:
            raise SpecError(f"quest {qid} ({fact['name']}): not open to {walker}; races {races}")


def _giver(sq: dict, fact: dict, pb: dict) -> tuple[str | None, dict | None]:
    """(name, point) of the giver the Data file names: Questie first, or
    PandaBase alone when the spec sets giverFrom."""
    start, pb_start = fact["startedBy"], pb.get("startedBy")
    if sq.get("giverFrom") != "pandabase":
        return endpoint_name(start, pb_start), endpoint_point(start, pb_start, pb)
    point = pandabase_point(pb_start, pb)
    if not point:
        raise SpecError(f"quest {sq['id']}: giverFrom pandabase needs a located PandaBase giver")
    return point["name"], point


def _ends_at_giver(sq: dict, fact: dict, pb: dict) -> bool:
    """True when the hand-in is the giver the Data file names."""
    if sq.get("giverFrom") != "pandabase":
        return same_npc(fact["startedBy"], fact["finishedBy"])
    return endpoint_name(fact["finishedBy"], pb.get("finishedBy")) == _giver(sq, fact, pb)[0]


def _quest_lua(sq: dict, fact: dict, pb: dict, chain_zone: str, manual: list, extra: tuple = ()) -> str:
    """One `{ id = .. }` row of a chain's quest list. ``extra`` holds the ready
    Lua fields that a side-zone row adds (faction, requires, task, turn)."""
    qid, start, pb_start = sq["id"], fact["startedBy"], pb.get("startedBy")
    giver, point = _giver(sq, fact, pb)
    if not giver:
        raise SpecError(f"quest {qid}: no giver name in Questie or PandaBase")
    zone = point["zone"] if point else endpoint_zone(start, pb_start) or chain_zone
    fields = [f"id = {qid}", f"name = {lua_str(fact['name'])}", f"giver = {lua_str(giver)}",
              f"zone = {lua_str(zone)}"]
    if point:
        fields.append(lua_point(point))
    else:
        manual.append({"id": qid, "name": fact["name"], "what": "giver point", "giver": giver})
    items = start.get("items") or []
    kind = "item" if items and sq.get("kind") not in ("item", "drop") else sq.get("kind")
    if kind:
        fields.append(f"kind = {lua_str(kind)}")
    if items:
        if (pb_start or {}).get("kind") == "item" and pb_start.get("name"):
            fields.append(f"startItem = {lua_str(pb_start['name'])}")
        fields.append(f"startItemID = {items[0]}")
    if sq.get("startSource"):
        fields.append(f"startSource = {lua_str(sq['startSource'])}")
    if sq.get("deferUntilAvailable"):
        fields.append("deferUntilAvailable = true")
    if fact.get("classes"):
        # Core.IsClassSpecificQuest drops it from the story guide.
        fields.append(f"class = {lua_str(', '.join(sorted(fact['classes'])))}")
    if sq.get("requires"):
        fields.append("requires = {" + ", ".join(str(r) for r in sq["requires"]) + "}")
    if sq.get("exclusiveWith"):
        fields.append("exclusiveWith = {" + ", ".join(str(r) for r in sq["exclusiveWith"]) + "}")
    if sq.get("note"):
        fields.append(f"note = {lua_str(sq['note'])}")
    if fact.get("requiredLevel") is not None:
        fields.append(f"reqlevel = {fact['requiredLevel']}")
    if fact.get("source") == "pandabase":
        fields.append('src = "forever-pandabase"')
    fields.extend(extra)
    return "    { " + ", ".join(fields) + " },"


def _route_info(sq: dict, fact: dict, pb: dict, manual: list, no_point: bool = False) -> dict:
    """RouteInfo for a quest: its task, and the hand-in when not the giver."""
    info = {"task": sq["task"]} if sq.get("task") else {}
    finish, pb_finish = fact["finishedBy"], pb.get("finishedBy")
    turn_name = None if _ends_at_giver(sq, fact, pb) else endpoint_name(finish, pb_finish)
    if turn_name:
        point = None if no_point else endpoint_point(finish, pb_finish, pb)
        if point:
            info["turn"] = dict(point, name=turn_name)
        else:
            info["turn"] = {"name": turn_name, "zone": endpoint_zone(finish, pb_finish)}
            manual.append({"id": sq["id"], "name": fact["name"], "what": "turn-in point", "giver": turn_name})
    return info


def _chain_lua(chain: dict, saga: str, rows: list[str], facts: list[dict]) -> str:
    req_levels = [f["requiredLevel"] for f in facts if f.get("requiredLevel") is not None]
    quest_levels = [f["questLevel"] for f in facts if f.get("questLevel") is not None]
    faction = f' faction = {lua_str(chain["faction"])},' if chain.get("faction") else ""
    after = "  after = { " + ", ".join(lua_str(a) for a in chain["after"]) + " },\n" if chain.get("after") else ""
    klass = "  classSpecific = true,\n" if chain.get("classSpecific") else ""
    head = (f'{{ id = {lua_str(chain["id"])}, name = {lua_str(chain["name"])}, race = {lua_str(saga)},{faction}\n'
            f'  zone = {lua_str(chain["zone"])}, minLevel = {req_levels[0]}, '
            f'maxLevel = {max(quest_levels)}, verified = "forever",\n{after}{klass}'
            f'  summary = {lua_str(chain["summary"])},\n  quests = {{')
    return head + "\n" + "\n".join(rows) + "\n  } },"


def _turn_lua(turn: dict) -> str:
    fields = [f"name = {lua_str(turn['name'])}"]
    if turn.get("zone"):
        fields.append(f"zone = {lua_str(turn['zone'])}")
    if "map" in turn:
        fields.append(lua_point(turn))
    return "turn = { " + ", ".join(fields) + " }"


def _route_info_lua(qid: int, info: dict) -> str:
    parts = []
    if "task" in info:
        parts.append(f"task = {lua_str(info['task'])}")
    if "turn" in info:
        parts.append(_turn_lua(info["turn"]))
    return f"[{qid}] = {{ " + ",\n  ".join(parts) + " },"


def build(spec: dict, facts: dict) -> tuple[str, str | None, dict]:
    """Return (Data Lua, Route Lua, manual-check report).

    The Route Lua is None for a chainsOnly spec: its route is hand-written.
    """
    saga = spec["saga"]
    chains_only = bool(spec.get("chainsOnly"))
    quests, pages = facts_index(facts)
    ids = spec_ids(spec)
    missing = [i for i in ids if i not in quests]
    if missing:
        raise SpecError(f"no facts for {missing}; run the facts command")

    manual: list[dict] = []
    route_info: dict[int, dict] = {}
    class_gated = {i for i in ids if quests[i].get("classes")}
    for chain in spec["chains"]:
        if chain.get("classSpecific"):
            plain = [q["id"] for q in chain["quests"] if q["id"] not in class_gated]
            if plain:
                raise SpecError(f"class chain {chain['id']}: quests with no class gate in the facts: {plain}")
    chain_lua: list[str] = []
    for chain in spec["chains"]:
        rows = []
        for sq in chain["quests"]:
            qid = sq["id"]
            fact, pb = quests[qid], pages.get(qid) or {}
            _check_walkers(qid, fact, chain.get("walkers") or [saga])
            rows.append(_quest_lua(sq, fact, pb, chain["zone"], manual))
            if chains_only:
                continue
            info = _route_info(sq, fact, pb, manual)
            if info and qid not in class_gated:
                route_info[qid] = info
        chain_lua.append(_chain_lua(chain, saga, rows, [quests[q["id"]] for q in chain["quests"]]))

    marker = f"-- GENERATED by tools/gen_saga.py from tools/sagas/{spec['_name']}.json. Do not edit.\n"
    data = (marker
            + f"-- {saga} saga chains. Regenerate: python tools/gen_saga.py build --all\n"
            + "-- Points are Questie spawns or PandaBase records; a quest without x/y\n"
            + f"-- is on tools/sagas/{spec['_name']}.manual.json for an in-game check.\n\n"
            + "local _, ns = ...\nns.Chains = ns.Chains or {}\n\nlocal chains = {\n\n"
            + "\n\n".join(chain_lua)
            + "\n\n}\n\nif ns.RegisterChains then ns.RegisterChains(chains)\n"
            + "else for _, c in ipairs(chains) do ns.Chains[#ns.Chains + 1] = c end end\n")
    report = {"saga": saga, "data": f"MainStoryGuide/Data_{spec.get('file', saga)}.lua",
              "manual": sorted(manual, key=lambda m: (m["id"], m["what"])),
              "classGated": sorted(class_gated),
              "pandabaseMissing": [i for i in facts.get("pandabase_missing", []) if i in ids]}
    if chains_only:
        return data, None, report
    route = check_route(spec, class_gated)
    r_lines = [_route_info_lua(qid, route_info[qid]) for qid in sorted(route_info, key=route.index)]
    route_lua = (marker
                 + f"-- {saga} saga route: one linear order through its own and shared chains.\n"
                 + "-- RouteInfo[questID] = { task = ..., turn = { name, zone, map, x, y } }; turn is\n"
                 + "-- present only when the hand-in is not the quest giver.\n\n"
                 + "local _, ns = ...\n\nlocal ROUTE = {\n"
                 + _wrap_ids(route)
                 + "}\nif ns.RegisterRoute then ns.RegisterRoute(" + lua_str(saga)
                 + ", ROUTE) else ns.StoryRoute = ROUTE end\n\nlocal R = {\n"
                 + "\n".join(r_lines)
                 + "\n}\nns.RouteInfo = ns.RouteInfo or {}\nfor id, r in pairs(R) do ns.RouteInfo[id] = r end\n")
    tasks = route_tasks(spec)
    if tasks:
        o_lines = [_route_info_lua(qid, {"task": tasks[qid]}) for qid in sorted(tasks, key=route.index)]
        route_lua += (f"\n-- {saga} text for shared quests: it replaces the owner's task for this saga only.\n"
                      + "local O = {\n" + "\n".join(o_lines) + "\n}\n"
                      + "ns.RouteInfoBySaga = ns.RouteInfoBySaga or {}\n"
                      + "ns.RouteInfoBySaga[" + lua_str(saga) + "] = O\n")
    return data, route_lua, report


def _wrap_ids(ids: list[int], per_line: int = 12) -> str:
    rows = [ids[i:i + per_line] for i in range(0, len(ids), per_line)]
    return "".join("  " + ", ".join(str(x) for x in row) + ",\n" for row in rows)


def check_route(spec: dict, class_gated: set[int]) -> list[int]:
    """The route holds every non-class-gated spec quest once, keeps each
    chain's order, and lists other sagas' quests only via routeExternal."""
    route = list(spec["route"])
    # The IDs go into the Lua route as bare numbers, so accept only integers.
    bad = [i for i in route + list(spec.get("routeExternal", []))
           if type(i) is not int]
    if bad:
        raise SpecError(f"route and routeExternal take quest IDs only: {bad!r}")
    if len(route) != len(set(route)):
        raise SpecError(f"route repeats {sorted({i for i in route if route.count(i) > 1})}")
    external = set(spec.get("routeExternal", []))
    own = [q["id"] for c in spec["chains"] for q in c["quests"]]
    unknown = [i for i in route if i not in own and i not in external]
    if unknown:
        raise SpecError(f"route IDs in no chain and not in routeExternal: {unknown}")
    gated = [i for i in route if i in class_gated]
    if gated:
        raise SpecError(f"class-gated quests cannot be on the route: {gated}")
    absent = [i for i in own if i not in route and i not in class_gated]
    if absent:
        raise SpecError(f"chain quests missing from the route: {absent}")
    pos = {qid: n for n, qid in enumerate(route)}
    for chain in spec["chains"]:
        order = [pos[q["id"]] for q in chain["quests"] if q["id"] in pos]
        if order != sorted(order):
            raise SpecError(f"route breaks the quest order of chain {chain['id']}")
    return route


# ------------------------------------------------------------- side zones
def is_side_spec(spec: dict) -> bool:
    return "sideZones" in spec


def load_side_spec(spec_path: pathlib.Path) -> dict:
    """Read and check a side-zone spec (issue #21)."""
    spec = json.loads(pathlib.Path(spec_path).read_text(encoding="utf-8"))
    if spec.get("sideZones") is not True:
        raise SpecError(f"{spec_path}: sideZones must be true")
    extra = {k for k in set(spec) - SIDE_SPEC_KEYS if not str(k).startswith("_")}
    if extra:
        raise SpecError(f"{spec_path}: unknown keys {sorted(extra)}")
    # 'file' names the output (MainStoryGuide/<file>.lua): letters only.
    if not SAGA_NAME.fullmatch(str(spec.get("file", ""))):
        raise SpecError(f"{spec_path}: 'file' must be letters only, got {spec.get('file')!r}")
    zones = spec.get("zones")
    if not isinstance(zones, list) or not zones:
        raise SpecError(f"{spec_path}: 'zones' must be a list of zones")
    seen_names = set()
    for zone in zones:
        extra = set(zone) - SIDE_ZONE_KEYS
        if extra:
            raise SpecError(f"zone {zone.get('name')!r}: unknown keys {sorted(extra)}")
        if not isinstance(zone.get("quests"), list):
            raise SpecError(f"zone {zone.get('name')!r}: 'quests' must be a list")
        if zone.get("name") not in eq.ZONE_IDS:
            raise SpecError(f"zone {zone.get('name')!r} is not in extract_questie.ZONES")
        if zone["name"] in seen_names:
            raise SpecError(f"zone {zone['name']!r} appears twice")
        seen_names.add(zone["name"])
        for q in zone["quests"]:
            if type(q.get("id")) is not int:
                raise SpecError(f"zone {zone['name']}: quest IDs must be integers, got {q.get('id')!r}")
            extra = set(q) - SIDE_QUEST_KEYS
            if extra:
                raise SpecError(f"quest {q['id']}: unknown keys {sorted(extra)}")
            if q.get("kind") and q["kind"] not in KINDS:
                raise SpecError(f"quest {q['id']}: unknown kind {q['kind']!r}")
            if "giverFrom" in q and q["giverFrom"] not in GIVER_SOURCES:
                raise SpecError(f"quest {q['id']}: giverFrom must be one of {sorted(GIVER_SOURCES)}")
    side_ids(spec)
    return spec


def side_ids(spec: dict) -> list[int]:
    ids = [q["id"] for z in spec["zones"] for q in z["quests"]]
    if len(ids) != len(set(ids)):
        dup = sorted({i for i in ids if ids.count(i) > 1})
        raise SpecError(f"quest IDs in more than one zone list: {dup}")
    return ids


def main_ids(addon: pathlib.Path = ADDON) -> set[int]:
    """Quest IDs of every MAIN chain: the quest rows of each Data_*.lua."""
    ids: set[int] = set()
    for path in sorted(addon.glob("Data_*.lua")):
        ids |= {int(m) for m in MAIN_ROW.findall(path.read_text(encoding="utf-8"))}
    return ids


def side_faction(fact: dict, pb: dict | None = None) -> str | None:
    """"Alliance" or "Horde" when every race of the quest is on one side.

    Questie gives the races; when it gives none, the PandaBase page (Forever)
    may restrict the quest to one faction, and the guide follows that.
    """
    races = set(fact.get("races") or []) or set((pb or {}).get("races") or [])
    if races and races <= ALLIANCE_RACES:
        return "Alliance"
    if races and races <= HORDE_RACES:
        return "Horde"
    return None


def side_requires(fact: dict, known: set[int], report: dict) -> list[int]:
    """Prerequisites the guide can link: all of a group, or the one single.

    A prerequisite that no list and no MAIN chain holds, and an "any one of
    these" set, are not linked; both go to the report so nothing is hidden.
    """
    group = list(fact.get("preQuestGroup") or [])
    single = list(fact.get("preQuestSingle") or [])
    wanted = group[:]
    if len(single) == 1:
        wanted += single
    elif single:
        report["anyOfPrereqs"].append({"id": fact["id"], "anyOf": sorted(single)})
    wanted = list(dict.fromkeys(wanted))
    for r in wanted:
        if r not in known:
            report["outsidePrereqs"].append({"id": fact["id"], "prereq": r})
    return [r for r in wanted if r in known]


def make_side_facts(spec: dict, download: bool = False, fetch=None, pages: dict | None = None) -> dict:
    """Facts for every quest of a side-zone spec (same shape as make_facts)."""
    flat = {"chains": [{"quests": [{"id": i} for i in side_ids(spec)]}]}
    return make_facts(flat, download=download, fetch=fetch, pages=pages)


def _side_row(sq: dict, zone_name: str, place: dict, quests: dict, pages: dict, known: set[int], report: dict) -> str:
    """One row of a zone's side list: the chain-row fields plus faction, requires, task and turn."""
    qid = sq["id"]
    fact, pb = quests[qid], pages.get(qid) or {}
    requires = side_requires(fact, known, report)
    late = [r for r in requires if r in place and place[r] > place[qid]]
    if late:
        raise SpecError(f"quest {qid}: the list of {zone_name} puts {late} after it; a prerequisite comes first")
    extra = []
    faction = side_faction(fact, pb)
    if faction:
        extra.append(f"faction = {lua_str(faction)}")
    if requires:
        extra.append("requires = {" + ", ".join(str(r) for r in requires) + "}")
    if sq.get("task"):
        extra.append(f"task = {lua_str(sq['task'])}")
    info = _route_info(sq, fact, pb, report["manual"], no_point=bool(sq.get("noTurnPoint")))
    if "turn" in info:
        turn = info["turn"]
        if turn.get("zone") not in eq.ZONE_IDS or sq.get("noTurnPoint"):
            # PandaBase text such as "Referenced dungeon area" is not a zone, and with
            # noTurnPoint the sources disagree on the zone, so no zone is named.
            turn = {k: v for k, v in turn.items() if k != "zone"}
        extra.append(_turn_lua(turn))
    return _quest_lua(sq, fact, pb, zone_name, report["manual"], tuple(extra))


def build_side(spec: dict, facts: dict, main: set[int]) -> tuple[str, dict]:
    """Return (ZoneSideQuests Lua, report).

    A quest in a MAIN chain, a class-gated quest and a quest in two lists fail
    the build: a side list never repeats MAIN and never holds a class quest.
    A list holds each prerequisite before the quest that needs it, so the guide
    can show the order of a linked group (it never blocks MAIN).
    """
    quests, pages = facts_index(facts)
    ids = side_ids(spec)
    missing = [i for i in ids if i not in quests]
    if missing:
        raise SpecError(f"no facts for {missing}; run the facts command")
    in_main = [i for i in ids if i in main]
    if in_main:
        raise SpecError(f"side quests that a MAIN chain holds: {in_main}")
    # A class gate in Questie or in the PandaBase page (Forever) keeps a quest out.
    gated = [i for i in ids if quests[i].get("classes") or (pages.get(i) or {}).get("classes")]
    if gated:
        raise SpecError(f"class-gated quests cannot be side quests: {gated}")
    known = set(ids) | set(main)
    report: dict = {"file": f"MainStoryGuide/{spec['file']}.lua", "manual": [],
                    "outsidePrereqs": [], "anyOfPrereqs": [],
                    "counts": {z["name"]: len(z["quests"]) for z in spec["zones"]}}
    blocks = []
    for zone in spec["zones"]:
        place = {q["id"]: n for n, q in enumerate(zone["quests"])}
        rows = [_side_row(sq, zone["name"], place, quests, pages, known, report) for sq in zone["quests"]]
        blocks.append(f"ns.ZoneSideQuests[{lua_str(zone['name'])}] = {{\n" + "\n".join(rows) + "\n}\n")
    report["manual"].sort(key=lambda m: (m["id"], m["what"]))
    report["outsidePrereqs"].sort(key=lambda m: (m["id"], m["prereq"]))
    report["anyOfPrereqs"].sort(key=lambda m: m["id"])
    marker = f"-- GENERATED by tools/gen_saga.py from tools/sagas/{spec['_name']}.json. Do not edit.\n"
    lua = (marker
           + "-- Zone side catalogues. Regenerate: python tools/gen_saga.py build --all\n"
           + "-- A list never holds a MAIN quest or a class quest. requires = quests of the same\n"
           + "-- catalogue or a MAIN chain; faction is set when every race of the quest is on one side.\n"
           + "-- Points are Questie spawns or PandaBase records; a quest without x/y is on\n"
           + f"-- tools/sagas/{spec['_name']}.manual.json for an in-game check.\n\n"
           + "local _, ns = ...\nns.ZoneSideQuests = ns.ZoneSideQuests or {}\n\n"
           + "\n".join(blocks))
    return lua, report


def run_side_build(spec_path: pathlib.Path, addon: pathlib.Path = ADDON, write_report: bool = True) -> dict:
    spec = load_side_spec(spec_path)
    spec["_name"] = spec_path.name[: -len(".json")]
    paths = spec_paths(spec_path)
    facts = json.loads(paths["facts"].read_text(encoding="utf-8"))
    lua, report = build_side(spec, facts, main_ids(addon))
    out = addon / f"{spec['file']}.lua"
    if out.exists() and not genmanifest.is_generated(out):
        raise SpecError(f"{out.name} is hand-written (no generated marker); refusing to overwrite it")
    write(out, lua)
    if write_report:
        write(paths["manual"], json.dumps(report, indent=1, sort_keys=True) + "\n")
    return report


# --------------------------------------------------------------------- cli
def _spec_files(folder: pathlib.Path, key: str) -> list[pathlib.Path]:
    out = []
    for p in sorted(folder.glob("*.json")):
        if p.name.endswith((".facts.json", ".manual.json")):
            continue
        if key in json.loads(p.read_text(encoding="utf-8")):
            out.append(p)
    return out


def all_specs(folder: pathlib.Path = SAGA_DIR) -> list[pathlib.Path]:
    """Saga spec files: the JSON files in tools/sagas that name a saga."""
    return _spec_files(folder, "saga")


def side_specs(folder: pathlib.Path = SAGA_DIR) -> list[pathlib.Path]:
    """Side-zone spec files (issue #21): the JSON files with "sideZones"."""
    return _spec_files(folder, "sideZones")


def _specs(args) -> list[pathlib.Path]:
    if args.all:
        return all_specs() + side_specs()
    if not args.spec:
        raise SystemExit("pass --spec or --all")
    return [pathlib.Path(args.spec)]


def write(path: pathlib.Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def run_build(spec_path: pathlib.Path, addon: pathlib.Path = ADDON, write_report: bool = True) -> dict:
    spec = load_spec(spec_path)
    spec["_name"] = spec_path.name[: -len(".json")]
    paths = spec_paths(spec_path)
    facts = json.loads(paths["facts"].read_text(encoding="utf-8"))
    data, route, report = build(spec, facts)
    stem = spec.get("file", spec["saga"])
    outputs = {addon / f"Data_{stem}.lua": data}
    if route is not None:
        outputs[addon / f"Route_{stem}.lua"] = route
    for path in outputs:
        # A generator never overwrites a hand-written file (issue #38).
        if path.exists() and not genmanifest.is_generated(path):
            raise SpecError(f"{path.name} is hand-written (no generated marker); refusing to overwrite it")
    for path, text in outputs.items():
        write(path, text)
    if write_report:
        write(paths["manual"], json.dumps(report, indent=1, sort_keys=True) + "\n")
    return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("command", choices=["facts", "build"])
    ap.add_argument("--spec")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--download", action="store_true", help="facts: fetch the pinned Questie DB first")
    ap.add_argument("--workers", type=int, default=FETCH_WORKERS,
                    help="facts: parallel PandaBase requests (PandaBase answers 503 to 8 at once; use 2)")
    args = ap.parse_args(argv)
    if not 1 <= args.workers <= MAX_FETCH_WORKERS:
        ap.error(f"--workers must be from 1 to {MAX_FETCH_WORKERS}")
    prefetch.__defaults__ = (args.workers,)
    pages: dict = {}  # one PandaBase page cache for every spec in this run
    try:
        for spec_path in _specs(args):
            side = is_side_spec(json.loads(spec_path.read_text(encoding="utf-8")))
            if side and args.command == "facts":
                spec = load_side_spec(spec_path)
                out = make_side_facts(spec, download=args.download, pages=pages)
                write(spec_paths(spec_path)["facts"], eq.dumps(out))
                print(f"{spec_path.name}: {len(out['quests'])} facts, "
                      f"{len(out.get('pandabase', []))} from PandaBase, missing {out['missing']}")
            elif side:
                report = run_side_build(spec_path)
                print(f"{spec_path.name}: built {report['file']}; {len(report['manual'])} manual check(s), "
                      f"{len(report['outsidePrereqs'])} prerequisite(s) outside the lists")
            elif args.command == "facts":
                spec = load_spec(spec_path)
                out = make_facts(spec, download=args.download, pages=pages)
                write(spec_paths(spec_path)["facts"], eq.dumps(out))
                print(f"{spec_path.name}: {len(out['quests'])} facts, "
                      f"{len(out.get('pandabase', []))} from PandaBase, missing {out['missing']}")
            else:
                report = run_build(spec_path)
                print(f"{spec_path.name}: built {report['data']}; "
                      f"{len(report['manual'])} manual check(s), class-gated {report['classGated']}")
    except SpecError as exc:
        print(f"gen_saga: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
