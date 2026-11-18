#!/usr/bin/env python3
"""Pick the Naxxramas and endgame Plaguelands quests and write their gen_saga spec.

Issue #24 (E5 / 5.3). Reads the pinned QuestieDB cache (run
`python tools/extract_questie.py --download --ids 1 --out -` once) and writes
`tools/sagas/naxx.json`, a `chainsOnly` spec with the saga key `Neutral`. The result is
deterministic; the rules below are the whole selection. The spec has no route, as for the
dungeon codas (issue #20): both factions see the chains and no race route holds them.

A quest is kept when it has no class gate, is not repeatable (specialFlags bit 1), has no
level-1 placeholder, is open to a whole faction or to everyone, is in no other spec, and is not
in NO_GIVER, FOREVER_CONFLICT or CONFLICT. A quest that needs a dropped quest goes too (`cascade`).

Chains:
- `naxxramas`: Questie `zoneOrSort` 3456 (Naxxramas), plus the quests they need.
- `plaguelands_endgame`: `zoneOrSort` 28 or 139 (Western or Eastern Plaguelands) with a required
  level of PLAGUELANDS_MIN_LEVEL or more, plus the quests they need. The level applies to the
  starting quests only: a lower quest stays when a quest of that level needs it (for example the
  Alliance line 5066 to 5097 before the Scholomance key), and every other low quest is leveling
  content that stays out (leveling content). The zone of the chain is
  "Plaguelands" because the quests start in the Western and Eastern Plaguelands and in Winterspring.
A quest that two chains claim stays in the first one, in this order. Each chain splits into one
chain for both factions, one for the Alliance and one for the Horde, as for the dungeons.

The Molten Core, Blackwing Lair, Zul'Gurub and Ahn'Qiraj quests are issues #22 and #23; a quest in
those specs is never taken here.
"""
from __future__ import annotations

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import extract_questie as eq  # noqa: E402
import select_codas as sc  # noqa: E402

NAXXRAMAS_ZONES = {3456}
PLAGUELANDS_ZONES = {28, 139}
PLAGUELANDS_MIN_LEVEL = 55
NO_GIVER: set[int] = set()
# Questie gives no class gate, but PandaBase (Forever) gates the armor-token quests: Paladin and Warrior
# (9234 to 9236), Mage, Priest and Warlock (9238 to 9240), Druid and Rogue (9241 to 9243), Hunter and
# Shaman (9244 to 9246). Each has a full PandaBase page, so its facts come from that page (issue #69).
FULL_PAGE_IDS = {9234, 9235, 9236, 9238, 9239, 9240, 9241, 9242, 9243, 9244, 9245, 9246}
# Quests that PandaBase gates in a way the guide cannot hold; the quests that need one go too.
CONFLICT: set[int] = set()
CHAINS = (
    ("naxxramas", "Naxxramas", "Naxxramas"),
    ("plaguelands_endgame", "Plaguelands Endgame", "Plaguelands"),
)

def pandabase_facts() -> dict[int, dict]:
    """PandaBase facts for the full-page Forever-only Naxxramas quests."""
    facts_path = sc.SAGAS / "naxx.facts.json"
    if not facts_path.exists():
        raise SystemExit(f"{facts_path} not found; run: python tools/gen_saga.py facts --all")
    pages = json.loads(facts_path.read_text(encoding="utf-8")).get("pandabase_pages", {})
    missing = sorted(i for i in FULL_PAGE_IDS if not pages.get(str(i)))
    if missing:
        raise SystemExit(f"no PandaBase page in naxx.facts.json for {missing}; run gen_saga.py facts")
    return {i: eq.pandabase_fact(i, pages[str(i)]) for i in sorted(FULL_PAGE_IDS)}


def taken_elsewhere() -> set[int]:
    """Quests of every other spec, the dungeon codas and the reputations included."""
    return sc.taken_elsewhere("naxx", NO_GIVER)


def eligible(f: dict) -> bool:
    return sc.eligible(f, FULL_PAGE_IDS)


def seeds(quests) -> dict[str, list[int]]:
    """The quests that start each chain, before the prerequisite closure."""
    out: dict[str, list[int]] = {cid: [] for cid, _, _ in CHAINS}
    for qid in quests.ids():
        row = quests.get(qid)
        zone = eq._field(row, eq.QK["zoneOrSort"])
        if zone in NAXXRAMAS_ZONES:
            out["naxxramas"].append(qid)
        elif zone in PLAGUELANDS_ZONES and eq._field(row, eq.QK["requiredLevel"]) >= PLAGUELANDS_MIN_LEVEL:
            out["plaguelands_endgame"].append(qid)
    return out


def keep_set(facts: dict[int, dict], taken: set[int]) -> set[int]:
    """The quests the guide can hold: no conflict, and each prerequisite is held or in another spec."""
    return sc.keep_set(facts, taken, CONFLICT, NO_GIVER)


def naxx(quests, npcs) -> dict:
    taken = taken_elsewhere()
    claimed, facts = sc.claim(CHAINS, seeds(quests), quests, npcs, taken, FULL_PAGE_IDS, pandabase_facts())
    chains = sc.chain_docs(CHAINS, claimed, keep_set(facts, taken), facts, quests, npcs)
    doc = sc.spec_doc("Naxxramas and the endgame Plaguelands (issue #24): the quests of Naxxramas and the "
                      "quests of the two Plaguelands at the required level of 55 or more, with the quests "
                      "they need. Chains only: no saga route holds them. Selection rules: tools/select_naxx.py.",
                      "Naxx", chains)
    doc["pandabaseFacts"] = sorted(FULL_PAGE_IDS)
    return doc


def main() -> int:
    quests, npcs = sc.load()
    doc = naxx(quests, npcs)
    path = sc.SAGAS / "naxx.json"
    path.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    n = sum(len(c["quests"]) for c in doc["chains"])
    print(f"{path.name}: {len(doc['chains'])} chains, {n} quests")
    for c in doc["chains"]:
        print(" ", c["id"], [q["id"] for q in c["quests"]])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
