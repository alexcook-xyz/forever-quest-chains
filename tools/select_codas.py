#!/usr/bin/env python3
"""Pick the dungeon coda and reputation quests and write their gen_saga specs.

Issue #20 (E4 / 4.2). Reads the pinned QuestieDB cache (run
`python tools/extract_questie.py --download --ids 1 --out -` once) and writes
`tools/sagas/dungeons.json` and `tools/sagas/reputations.json`. The result is
deterministic; the rules below are the whole selection.

Dungeons: a quest whose Questie `zoneOrSort` is a leveling dungeon (raids are E5),
with no class gate, not repeatable (specialFlags bit 1), no level-1 placeholder, and
not already in another saga spec, and not in NO_GIVER. Each dungeon gives up to three chains:
open to both factions (races empty), Alliance only, Horde only. A quest that needs
a faction-limited quest goes to that faction's chain. A quest open to only some
Horde or Alliance races (for example Orc, Tauren and Troll) is left out, because a
chain is open to a whole faction or to nobody.

Reputations: a quest that is not repeatable and not a raid or profession quest and
that rewards the faction's reputation (Questie field 26), in the faction's home
zones; plus the quests that these need (prerequisite closure). Zandalar quests all
need Zul'Gurub (E5) and are left out; the Hydraxian chain is the Duke Hydraxis chain up to 6821; the
quests after it need Molten Core (E5).
"""
from __future__ import annotations

import functools
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import extract_questie as eq  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SAGAS = ROOT / "tools" / "sagas"
CACHE = ROOT / "tools" / ".cache" / eq.PINNED_REF

# Questie zoneOrSort -> (dungeon name, order by level). Raids (E5) are not here.
DUNGEONS = {
    2437: "Ragefire Chasm", 718: "Wailing Caverns", 1581: "The Deadmines", 209: "Shadowfang Keep",
    719: "Blackfathom Deeps", 717: "The Stockade", 133: "Gnomeregan", 1717: "Razorfen Kraul",
    796: "Scarlet Monastery", 722: "Razorfen Downs", 1517: "Uldaman", 978: "Zul'Farrak",
    2100: "Maraudon", 1417: "The Temple of Atal'Hakkar", 1584: "Blackrock Depths",
    1583: "Blackrock Spire", 2557: "Dire Maul", 2057: "Scholomance", 2017: "Stratholme",
}
ALLIANCE = {"Human", "Dwarf", "Night Elf", "Gnome", "Skyborne (Alliance)"}
HORDE = {"Orc", "Undead", "Tauren", "Troll", "Skyborne (Horde)"}
WALKERS = {"Alliance": ["Human", "Dwarf", "NightElf", "Gnome"], "Horde": ["Orc", "Troll", "Tauren", "Scourge"]}

# Reputation: faction id -> (chain id, name, home zones, zone label). Questie field 26.
REPUTATIONS = {
    529: ("argent_dawn", "Argent Dawn", {139, 28}, "Plaguelands"),
    609: ("cenarion_circle", "Cenarion Circle", {1377, 493}, "Silithus"),
    576: ("timbermaw_hold", "Timbermaw Hold", {361, 1769, 618}, "Felwood and Winterspring"),
    59: ("thorium_brotherhood", "Thorium Brotherhood", {51}, "Searing Gorge"),
}
# The Duke Hydraxis chain stops at Eye of the Emberseer (6821, Blackrock Spire): The Molten Core
# (6822), Agent of Hydraxis (6823), Hands of the Enemy (6824) and A Hero's Reward (7486) need
# Molten Core, which is E5.
HYDRAXIS = {"id": "hydraxian_waterlords", "name": "Hydraxian Waterlords", "zone": "Azshara", "last": 6821}
# No giver name in Questie or PandaBase (gen_saga refuses them) or a flag quest, found by the
# first build. 4603 and 4604 need 4605 and 4606, so the whole Sparklematic 5200 group of
# object starts (4601 to 4606) stays off. They are open manual checks for a later pass.
# 7462 has no PandaBase page, so it cannot be verified.
NO_GIVER = {7462, 1318, 4601, 4602, 4603, 4604, 4605, 4606, 7704, 8856, 9378}
# PandaBase (Forever) gates these quests differently from Questie, so the guide leaves them
# out (investigated by `verify_pandabase.py`; a quest that needs one of them goes too, see
# `cascade`). Race: 1198, 7877, 5234 (Forever limits them to Horde or Alliance). Class: 7507,
# 7508 (Paladin, Warrior). Giver or name: 4742, 4743 (Scarshield Infiltrator, not Vaelan),
# 5047, 5214, 7492. Point: 721, 722, 6602, 7481 (Questie and PandaBase place the NPC in
# different spots). Also 5126 (class Paladin, Shaman, Warrior), 6567 and 6568 (point), and 2952
# and 6163 (Forever adds prerequisites that the guide does not hold: 4601, 4602, 6135, 6136).
# 8733 left this set (issue #64): PandaBase adds only 8555, which the guide holds.
# Each is a gap for a later pass, never a guessed value.
FOREVER_CONFLICT = {1198, 7877, 5234, 7507, 7508, 4742, 4743, 5047, 5214, 7492, 721, 722, 6602, 7481,
                    5126, 6567, 6568, 2952, 6163}
# The specs that select_codas.py, select_raids.py, select_zg_aq.py and select_naxx.py write (a quest is in one of them only).
CODA_STEMS = ("dungeons", "reputations", "raids", "zg_aq", "naxx")
RAID_ZONES = {2717, 1977, 2159, 2677, 3456, 3428, 3429, 19}


def load():
    quests = eq.EntityDB.from_path(CACHE / "foreverQuestDB.lua")
    npcs = eq.EntityDB.from_path(CACHE / "foreverNpcDB.lua")
    return quests, npcs


def used_elsewhere() -> set[int]:
    ids: set[int] = set(NO_GIVER) | FOREVER_CONFLICT
    for path in SAGAS.glob("*.json"):
        if path.name.endswith((".facts.json", ".manual.json")) or path.name == "accepted_mismatches.json":
            continue
        if path.stem in CODA_STEMS:
            continue
        spec = json.loads(path.read_text(encoding="utf-8"))
        ids |= {q["id"] for c in spec.get("chains", []) for q in c["quests"]}
        ids |= set(spec.get("routeExternal") or [])
    return ids


def rep_rewards(row) -> list:
    value = eq._field(row, 26)
    return [e for e in value if isinstance(e, list) and e] if isinstance(value, list) else []


def faction_of(fact: dict) -> str | None:
    """'Alliance', 'Horde', 'Neutral' (no race limit) or None (some races only)."""
    races = set(fact["races"])
    if not races:
        return "Neutral"
    if races == ALLIANCE or races == ALLIANCE - {"Skyborne (Alliance)"}:
        return "Alliance"
    if races == HORDE or races == HORDE - {"Skyborne (Horde)"}:
        return "Horde"
    return None


@functools.cache
def pandabase_before() -> dict[int, set[int]]:
    """Prerequisites that PandaBase records, from the committed facts snapshots (empty on a first run)."""
    out: dict[int, set[int]] = {}
    for name in CODA_STEMS:
        path = SAGAS / f"{name}.facts.json"
        if path.exists():
            for qid, page in json.loads(path.read_text(encoding="utf-8")).get("pandabase_pages", {}).items():
                out[int(qid)] = set(page.get("before") or [])
    return out


def chain_faction(fact: dict, facts: dict[int, dict], quests, npcs) -> str:
    """The chain group of a quest: its own faction, or the faction of a limited prerequisite."""
    group = faction_of(fact)
    if group == "Neutral":  # a faction-limited prerequisite limits the quest too
        for p in prerequisites(fact):
            pf = facts.get(p) or eq.quest_fact(p, quests, npcs)
            if pf and faction_of(pf) in ("Alliance", "Horde"):
                group = faction_of(pf)
    return group


def prerequisites(fact: dict) -> set[int]:
    return set(fact["preQuestSingle"] or []) | set(fact["preQuestGroup"] or [])


def cascade(ids: set[int], facts: dict[int, dict], gone: set[int], have: set[int] = frozenset()) -> set[int]:
    """Keep a quest only when each Questie prerequisite is kept or in `have`.

    Membership uses Questie only, so a run gives the same set each time; `order` also reads
    the PandaBase prerequisites from the facts snapshot.

    `gone` quests are never kept. A quest whose prerequisite is not part of the guide would be
    a chain member nobody can start, so it goes too (and so on, until nothing changes).
    """
    ids = set(ids) - gone
    while True:
        lost = {i for i in ids if prerequisites(facts[i]) - ids - have}
        if not lost:
            return ids
        ids -= lost


def reachable(facts: dict[int, dict], taken: set[int]) -> set[int]:
    """The quests of `facts` that the guide can hold: no conflict, and every prerequisite is held or in `taken`."""
    return cascade(set(facts), facts, FOREVER_CONFLICT, taken - FOREVER_CONFLICT - NO_GIVER)


def order(ids: list[int], facts: dict[int, dict]) -> list[int]:
    """Prerequisites first (Questie and PandaBase both), then required level, then id."""
    before = pandabase_before()
    left = sorted(ids, key=lambda i: (facts[i]["requiredLevel"], i))
    out: list[int] = []
    while left:
        for i in left:
            pre = prerequisites(facts[i]) | before.get(i, set())
            if not (pre & set(left)):
                out.append(i)
                left.remove(i)
                break
        else:  # a cycle: keep the level order
            out.extend(left)
            break
    return out


def summary(label: str, ids: list[int], facts: dict[int, dict]) -> str:
    levels = [facts[i]["requiredLevel"] for i in ids]
    givers = []
    for i in ids:
        for c in facts[i]["startedBy"]["creatures"][:1]:
            if c["name"] and c["name"] not in givers:
                givers.append(c["name"])
    lead = ", ".join(givers[:3]) if givers else "no recorded giver"
    more = f" and {len(givers) - 3} more" if len(givers) > 3 else ""
    span = f"required level {min(levels)}" if min(levels) == max(levels) else f"required levels {min(levels)} to {max(levels)}"
    return (f"{len(ids)} quests for {label} at {span}. "
            f"The quests start with {lead}{more}.")


def dungeons(quests, npcs) -> dict:
    skip = used_elsewhere()
    facts: dict[int, dict] = {}
    pool: dict[int, list[int]] = {z: [] for z in DUNGEONS}

    def eligible(f: dict) -> bool:
        return not (f["classes"] or f["specialFlags"] & 1 or f["requiredLevel"] <= 1 or f["questLevel"] <= 1
                    or faction_of(f) is None)

    def add(qid: int, zone: int) -> None:
        """Take a quest and the quests it needs, so a chain member always has a way in."""
        if qid in facts or qid in skip:
            return
        f = eq.quest_fact(qid, quests, npcs)
        if f is None or not eligible(f) or f["zoneOrSort"] in RAID_ZONES or f["zoneOrSort"] < 0:
            return  # a raid or profession quest is not part of the guide (E5 or a skill quest)
        facts[qid] = f
        pool[zone].append(qid)
        for p in prerequisites(f):
            add(p, zone)

    for qid in quests.ids():
        zone = eq._field(quests.get(qid), eq.QK["zoneOrSort"])
        if zone in DUNGEONS:
            add(qid, zone)
    pool = move_quests(pool)
    keep = reachable(facts, skip)
    pool = {z: [i for i in ids if i in keep] for z, ids in pool.items()}
    chains = []
    for zone, name in sorted(DUNGEONS.items(), key=lambda kv: min(
            [facts[i]["requiredLevel"] for i in pool[kv[0]]] or [99])):
        groups: dict[str, list[int]] = {"Neutral": [], "Alliance": [], "Horde": []}
        for qid in pool[zone]:
            groups[chain_faction(facts[qid], facts, quests, npcs)].append(qid)
        for group, ids in groups.items():
            if not ids:
                continue
            ids = order(ids, facts)
            chain = {"id": f"dungeon_{_slug(name)}" + ("" if group == "Neutral" else f"_{group.lower()}"),
                     "name": name if group == "Neutral" else f"{name} ({group})",
                     "zone": name, "summary": summary(name, ids, facts),
                     "quests": [{"id": i} for i in ids]}
            if group != "Neutral":
                chain["faction"] = group
                chain["walkers"] = WALKERS[group]
            chains.append(chain)
    return spec_doc("Dungeon codas (issue #20): the leveling dungeon quests, one chain per dungeon for "
                    "both factions and one per faction for the quests only that faction takes. Chains "
                    "only: no saga route holds them. Selection rules: tools/select_codas.py.",
                    "Dungeons", chains)


def _slug(name: str) -> str:
    return "".join(c if c.isalnum() else "_" for c in name.lower()).strip("_").replace("__", "_")


# Chain order (issue #74): a chain here comes after the chains listed, in every saga view that holds
# them (the chain key `after`; `Sagas.lua` `RebuildView` follows it). Each entry is a quest of the
# chain that needs a quest of the other chain (Questie or PandaBase):
#   3446 and 3447 need 3444 (Atal'Hakkar, Alliance) and 4787 needs 3527 (Zul'Farrak);
#   8575 (Molten Core) and 8733 (Ahn'Qiraj) need 8555 (Blackwing Lair).
# tests/test_race_sagas.py checks that each entry still has such a quest and that each ID is a chain.
AFTER = {
    "dungeon_the_temple_of_atal_hakkar": ["dungeon_the_temple_of_atal_hakkar_alliance", "dungeon_zul_farrak"],
    "raid_molten_core": ["raid_blackwing_lair"],
    "ahn_qiraj": ["raid_blackwing_lair"],
}
# Chain membership (issue #74): the Ras Frostwhisper line crosses two dungeons. 5384 (Scholomance) opens
# 5461 to 5463 (Stratholme), and 5463 opens 5464 to 5466 (Scholomance), so no chain order meets both.
# These three quests go to the Scholomance chain, and the whole line is one chain.
MOVED_TO_ZONE = {5461: 2057, 5462: 2057, 5463: 2057}


def move_quests(pool: dict[int, list[int]]) -> dict[int, list[int]]:
    """Move each MOVED_TO_ZONE quest to the list of its zone. A quest that no list holds stays out."""
    moved = {q: z for q, z in MOVED_TO_ZONE.items() if any(q in ids for ids in pool.values())}
    out = {z: [i for i in ids if i not in moved] for z, ids in pool.items()}
    for qid, zone in moved.items():
        out[zone].append(qid)
    return out


def with_after(chains: list) -> list:
    """Set the `after` key of each chain that AFTER names. Other chains stay as they are."""
    for chain in chains:
        if chain["id"] in AFTER:
            chain["after"] = list(AFTER[chain["id"]])
    return chains


def spec_doc(comment: str, file: str, chains: list) -> dict:
    return {"saga": "Neutral", "file": file, "chainsOnly": True, "route": [], "comment": comment,
            "chains": with_after(chains)}


def closure(seed: list[int], quests, npcs, taken: set[int]) -> dict[int, dict]:
    facts: dict[int, dict] = {}
    todo = list(seed)
    while todo:
        qid = todo.pop()
        if qid in facts or qid in taken:
            continue
        f = eq.quest_fact(qid, quests, npcs)
        if f is None:
            continue
        facts[qid] = f
        todo += list(f["preQuestSingle"] or []) + list(f["preQuestGroup"] or [])
    return facts


def taken_elsewhere(own: str, no_giver: set[int] | frozenset[int] = frozenset()) -> set[int]:
    """Quests of every other spec, the coda specs included. `own` is the stem of the calling spec."""
    ids = used_elsewhere() | no_giver
    for name in CODA_STEMS:  # used_elsewhere skips the coda specs; the caller's own spec is not "elsewhere"
        if name != own:
            spec = json.loads((SAGAS / f"{name}.json").read_text(encoding="utf-8"))
            ids |= {q["id"] for c in spec["chains"] for q in c["quests"]}
    return ids


def eligible(f: dict, class_exempt: frozenset[int] | set[int] = frozenset()) -> bool:
    """No class gate (but a quest in `class_exempt` may have one), not repeatable, no level-1 placeholder, one faction."""
    is_class_gated = bool(f["classes"]) and f.get("id") not in class_exempt
    return not (is_class_gated or f["specialFlags"] & 1 or f["requiredLevel"] <= 1 or f["questLevel"] <= 1
                or faction_of(f) is None)


def keep_set(facts: dict[int, dict], taken: set[int], conflict: set[int], no_giver: set[int]) -> set[int]:
    """The quests the guide can hold: no conflict, and each prerequisite is held or in another spec."""
    gone = FOREVER_CONFLICT | conflict
    return cascade(set(facts), facts, gone, taken - gone - NO_GIVER - no_giver)


def claim(chains, by_chain: dict[str, list[int]], quests, npcs, taken: set[int], class_exempt=frozenset(),
          override: dict[int, dict] | None = None) -> tuple[dict[int, str], dict[int, dict]]:
    """Fill each chain from its seeds, in order. A quest that two chains claim stays in the first one.

    `override` holds facts that replace the Questie facts of a quest (the PandaBase pages of issue #69).
    """
    claimed: dict[int, str] = {}
    facts: dict[int, dict] = {}
    for cid, _, _ in chains:
        found = closure(by_chain[cid], quests, npcs, taken)
        for qid, f in (override or {}).items():
            if qid in found:
                found[qid] = f
        for qid, f in found.items():
            if eligible(f, class_exempt) and qid not in claimed:
                claimed[qid] = cid
                facts[qid] = f
    return claimed, facts


def chain_docs(chains, claimed: dict[int, str], keep: set[int], facts: dict[int, dict], quests, npcs) -> list:
    """One chain for both factions, one for the Alliance and one for the Horde, per entry of `chains`."""
    out = []
    for cid, name, zone in chains:
        groups: dict[str, list[int]] = {"Neutral": [], "Alliance": [], "Horde": []}
        for qid in sorted(i for i in keep if claimed[i] == cid):
            groups[chain_faction(facts[qid], facts, quests, npcs)].append(qid)
        for group, ids in groups.items():
            if not ids:
                continue
            ids = order(ids, facts)
            chain = {"id": cid if group == "Neutral" else f"{cid}_{group.lower()}",
                     "name": name if group == "Neutral" else f"{name} ({group})",
                     "zone": zone, "summary": summary(name, ids, facts),
                     "quests": [{"id": i} for i in ids]}
            if group != "Neutral":
                chain["faction"] = group
                chain["walkers"] = WALKERS[group]
            out.append(chain)
    return out


def is_raid_or_skill(quests, qid: int) -> bool:
    """A raid quest (E5), a profession or class sort (negative), or a quest with no zone."""
    zone = eq._field(quests.get(qid), eq.QK["zoneOrSort"])
    return zone is None or zone < 0 or zone in RAID_ZONES


def rep_chain(cid: str, name: str, zone: str, ids: list[int], facts: dict[int, dict]) -> dict:
    return {"id": cid, "name": name, "zone": zone, "summary": summary(name, ids, facts),
            "quests": [{"id": i} for i in ids]}


def reputations(quests, npcs, in_dungeons: set[int]) -> dict:
    taken = used_elsewhere() | in_dungeons  # a quest is in one chain only; the dungeon chain wins
    chains = []
    for fid, (cid, name, zones, zone_label) in REPUTATIONS.items():
        seed = []
        for qid in quests.ids():
            row = quests.get(qid)
            zone = eq._field(row, eq.QK["zoneOrSort"])
            if zone not in zones or zone in RAID_ZONES or qid in taken:
                continue
            if not any(e[0] == fid for e in rep_rewards(row)):
                continue
            f = eq.quest_fact(qid, quests, npcs)
            if f["classes"] or f["specialFlags"] & 1 or f["requiredLevel"] <= 1 or faction_of(f) != "Neutral":
                continue
            seed.append(qid)
        facts = closure(seed, quests, npcs, taken)
        facts = {i: f for i, f in facts.items() if not f["classes"] and not f["specialFlags"] & 1
                 and faction_of(f) == "Neutral" and not is_raid_or_skill(quests, i)}
        ids = order(list(reachable(facts, taken)), facts)
        if ids:
            chains.append(rep_chain(cid, name, zone_label, ids, facts))
    facts = closure([HYDRAXIS["last"]], quests, npcs, taken)
    facts = {i: f for i, f in facts.items() if faction_of(f) == "Neutral" and not f["classes"]}
    chains.append(rep_chain(HYDRAXIS["id"], HYDRAXIS["name"], HYDRAXIS["zone"],
                            order(list(reachable(facts, taken)), facts), facts))
    return spec_doc("Reputation chains (issue #20): the Argent Dawn, Cenarion Circle, Timbermaw Hold, "
                    "Thorium Brotherhood and Hydraxian Waterlords quests that both factions take and that "
                    "need no raid. Zandalar needs Zul'Gurub (E5). Chains only. Rules: tools/select_codas.py.",
                    "Reputations", chains)


def main() -> int:
    quests, npcs = load()
    dungeon_doc = dungeons(quests, npcs)
    in_dungeons = {q["id"] for c in dungeon_doc["chains"] for q in c["quests"]}
    for name, doc in (("dungeons", dungeon_doc), ("reputations", reputations(quests, npcs, in_dungeons))):
        path = SAGAS / f"{name}.json"
        path.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        n = sum(len(c["quests"]) for c in doc["chains"])
        print(f"{path.name}: {len(doc['chains'])} chains, {n} quests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
