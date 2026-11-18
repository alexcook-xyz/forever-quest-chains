"""Selection rules for the Naxxramas and endgame Plaguelands chains (issue #24)."""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import select_codas as sc  # noqa: E402
import select_naxx as sn  # noqa: E402

SPEC = json.loads((ROOT / "tools" / "sagas" / "naxx.json").read_text(encoding="utf-8"))
FACTS = {q["id"]: q for q in json.loads((ROOT / "tools" / "sagas" / "naxx.facts.json").read_text(encoding="utf-8"))["quests"]}
IDS = [q["id"] for c in SPEC["chains"] for q in c["quests"]]


ADDED_ARMOR_TOKEN_QUESTS = {
    9234: ["Paladin", "Warrior"],
    9235: ["Paladin", "Warrior"],
    9236: ["Paladin", "Warrior"],
    9238: ["Mage", "Priest", "Warlock"],
    9239: ["Mage", "Priest", "Warlock"],
    9240: ["Mage", "Priest", "Warlock"],
    9241: ["Druid", "Rogue"],
    9242: ["Druid", "Rogue"],
    9243: ["Druid", "Rogue"],
    9244: ["Hunter", "Shaman"],
    9245: ["Hunter", "Shaman"],
    9246: ["Hunter", "Shaman"],
}


def fact(**kw):
    base = {"classes": [], "specialFlags": 0, "requiredLevel": 60, "questLevel": 60, "races": []}
    return {**base, **kw}


def _f(qid, pre=()):
    return {"id": qid, "preQuestSingle": list(pre), "preQuestGroup": []}


def test_eligible_drops_class_repeatable_and_partial_race_quests():
    assert sn.eligible(fact())
    assert not sn.eligible(fact(classes=["Mage"]))
    assert sn.eligible(fact(classes=["Mage"], id=9240, source="pandabase"))
    assert not sn.eligible(fact(classes=["Mage"], id=9999, source="pandabase"))
    assert not sn.eligible(fact(specialFlags=1))
    assert not sn.eligible(fact(requiredLevel=1))
    assert not sn.eligible(fact(races=["Orc", "Tauren", "Troll"]))


def test_the_spec_is_a_neutral_chains_only_spec_with_both_chains():
    assert SPEC["saga"] == "Neutral" and SPEC["chainsOnly"] is True and SPEC["route"] == []
    assert {c["id"].split("_alliance")[0].split("_horde")[0] for c in SPEC["chains"]} == {"naxxramas", "plaguelands_endgame"}


def test_the_spec_quests_follow_the_selection_rules():
    assert len(IDS) == len(set(IDS)) == len(FACTS)
    assert not set(IDS) & (sn.NO_GIVER | sn.CONFLICT | sc.FOREVER_CONFLICT)
    for qid in IDS:
        assert sn.eligible(FACTS[qid]), qid


def test_a_quest_comes_after_its_prerequisites_in_the_chain():
    for chain in SPEC["chains"]:
        pos = {q["id"]: n for n, q in enumerate(chain["quests"])}
        for qid, n in pos.items():
            for p in sc.prerequisites(FACTS[qid]):
                assert pos.get(p, -1) < n, (chain["id"], qid, p)


def test_the_added_armor_token_quests_are_in_spec_and_in_naxxramas_chain_after_9233():
    # Issue #69: PandaBase (Forever) class-gated armor-token quests are included
    chain = next(c for c in SPEC["chains"] if c["id"] == "naxxramas")
    chain_ids = [q["id"] for q in chain["quests"]]
    idx_9233 = chain_ids.index(9233)
    added_ids = sorted(ADDED_ARMOR_TOKEN_QUESTS)
    for qid in added_ids:
        assert qid in IDS
        assert qid in chain_ids
        assert chain_ids.index(qid) > idx_9233
        assert FACTS[qid]["source"] == "pandabase"
        assert sorted(FACTS[qid]["classes"]) == sorted(ADDED_ARMOR_TOKEN_QUESTS[qid])
    chain_indices = [chain_ids.index(qid) for qid in added_ids]
    assert chain_indices == sorted(chain_indices)


def test_a_conflict_quest_and_the_quests_that_need_it_drop(monkeypatch):
    monkeypatch.setattr(sn, "CONFLICT", {9234})  # CONFLICT is empty since issue #69
    facts = {9234: _f(9234), 9250: _f(9250, [9234]), 9251: _f(9251)}
    assert sn.keep_set(facts, set()) == {9251}


def test_the_spec_takes_the_facts_of_the_armor_token_quests_from_pandabase():
    assert SPEC["pandabaseFacts"] == sorted(sn.FULL_PAGE_IDS) == sorted(ADDED_ARMOR_TOKEN_QUESTS)
    assert not sn.CONFLICT  # no gap: every armor-token quest has a full PandaBase page


def test_a_plaguelands_quest_below_the_minimum_level_is_a_needed_prerequisite():
    for chain in (c for c in SPEC["chains"] if c["id"].startswith("plaguelands_endgame")):
        ids = [q["id"] for q in chain["quests"]]
        needed: set[int] = set()
        stack = [i for i in ids if FACTS[i]["requiredLevel"] >= sn.PLAGUELANDS_MIN_LEVEL]
        while stack:  # walk the prerequisites of every quest at the level or above
            for p in sc.prerequisites(FACTS[stack.pop()]):
                if p in ids and p not in needed:
                    needed.add(p)
                    stack.append(p)
        low = {i for i in ids if FACTS[i]["requiredLevel"] < sn.PLAGUELANDS_MIN_LEVEL}
        assert low <= needed, (chain["id"], sorted(low - needed))


def test_the_closing_epilogue_names_the_end_of_the_spine():
    text = (ROOT / "MainStoryGuide" / "Journal_Naxx.lua").read_text(encoding="utf-8")
    assert "closes the endgame spine" in text
