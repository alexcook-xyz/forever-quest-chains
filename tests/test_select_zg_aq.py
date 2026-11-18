"""Selection rules for the Zul'Gurub and Ahn'Qiraj chains (issue #23)."""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import select_codas as sc  # noqa: E402
import select_zg_aq as sr  # noqa: E402

SPEC = json.loads((ROOT / "tools" / "sagas" / "zg_aq.json").read_text(encoding="utf-8"))
FACTS = {q["id"]: q for q in json.loads((ROOT / "tools" / "sagas" / "zg_aq.facts.json").read_text(encoding="utf-8"))["quests"]}


def fact(**kw):
    base = {"classes": [], "specialFlags": 0, "requiredLevel": 60, "questLevel": 60, "races": []}
    return {**base, **kw}


def test_eligible_drops_class_repeatable_and_partial_race_quests():
    assert sr.eligible(fact())
    assert not sr.eligible(fact(classes=["Mage"]))
    assert not sr.eligible(fact(specialFlags=1))
    assert not sr.eligible(fact(requiredLevel=1))
    assert not sr.eligible(fact(races=["Orc", "Tauren", "Troll"]))


def test_the_spec_holds_the_three_raid_chains():
    assert [c["id"] for c in SPEC["chains"]] == ["zul_gurub", "zandalar_tribe", "ahn_qiraj"]
    assert SPEC["saga"] == "Neutral" and SPEC["chainsOnly"] is True and SPEC["route"] == []


def test_the_spec_quests_follow_the_selection_rules():
    ids = [q["id"] for c in SPEC["chains"] for q in c["quests"]]
    assert len(ids) == len(set(ids)) == len(FACTS)
    assert not set(ids) & (sr.NO_GIVER | sr.CONFLICT | sc.FOREVER_CONFLICT)
    for qid in ids:
        assert sr.eligible(FACTS[qid]), qid


def test_a_quest_comes_after_its_prerequisites_in_the_chain():
    for chain in SPEC["chains"]:
        pos = {q["id"]: n for n, q in enumerate(chain["quests"])}
        for qid, n in pos.items():
            for p in sc.prerequisites(FACTS[qid]):
                assert pos.get(p, -1) < n, (chain["id"], qid, p)


def _f(qid, pre=()):
    return {"id": qid, "preQuestSingle": list(pre), "preQuestGroup": []}


def test_a_conflict_quest_and_the_quests_that_need_it_drop(monkeypatch):
    monkeypatch.setattr(sr, "CONFLICT", {8728})  # CONFLICT is empty since issue #66
    facts = {8728: _f(8728), 8729: _f(8729, [8728]), 8730: _f(8730)}
    assert sr.keep_set(facts, set()) == {8730}


def test_a_prerequisite_without_a_giver_does_not_count_as_held():
    # 8183 is in `taken` (no chain holds it), so a quest that needs it cannot start.
    facts = {9000: _f(9000, [8183]), 9001: _f(9001, [7000])}
    assert sr.keep_set(facts, {8183, 7000}) == {9001}


def test_the_eranikus_line_is_in_the_ahn_qiraj_chain_in_order():
    # Issue #64: 8733 left FOREVER_CONFLICT, so the line it opens is back.
    chain = next(c for c in SPEC["chains"] if c["id"] == "ahn_qiraj")
    ids = [q["id"] for q in chain["quests"]]
    assert 8733 not in sc.FOREVER_CONFLICT
    assert [i for i in ids if i in (8733, 8734, 8735, 8736, 8741)] == [8733, 8734, 8735, 8736, 8741]


def test_the_narain_line_and_the_quests_that_need_8728_are_in_the_ahn_qiraj_chain():
    # Issue #66: 8587 is a seed and 8728 left CONFLICT (PandaBase adds 8578 and 8587, and the guide
    # holds both), so 8742, 8743 and 8745 are back.
    chain = next(c for c in SPEC["chains"] if c["id"] == "ahn_qiraj")
    ids = [q["id"] for q in chain["quests"]]
    assert 8587 in sr.AQ_SEEDS and not sr.CONFLICT
    wanted = (8585, 8586, 8587, 8728, 8729, 8742, 8743, 8745)
    assert all(i in ids for i in wanted)
    assert ids.index(8586) < ids.index(8587) < ids.index(8728) < ids.index(8729) < ids.index(8742)
    assert ids.index(8742) < ids.index(8743) and ids.index(8742) < ids.index(8745)


def test_the_forever_prerequisites_of_8728_are_recorded_and_held():
    accepted = json.loads((ROOT / "tools" / "sagas" / "accepted_mismatches.json").read_text(encoding="utf-8"))["accepted"]
    row = next(a for a in accepted if a["id"] == 8728)
    assert (row["field"], row["questie"], row["pandabase"]) == ("before", [8620], [8578, 8587, 8620])
    held = {}
    for name in ("raids", "zg_aq"):
        spec = json.loads((ROOT / "tools" / "sagas" / f"{name}.json").read_text(encoding="utf-8"))
        held.update({q["id"]: name for c in spec["chains"] for q in c["quests"]})
    assert held[8578] == "raids" and held[8587] == "zg_aq"


def test_the_forever_prerequisite_of_8733_is_recorded_and_held():
    accepted = json.loads((ROOT / "tools" / "sagas" / "accepted_mismatches.json").read_text(encoding="utf-8"))["accepted"]
    row = next(a for a in accepted if a["id"] == 8733)
    assert (row["field"], row["questie"], row["pandabase"]) == ("before", [], [8555])
    raids = json.loads((ROOT / "tools" / "sagas" / "raids.json").read_text(encoding="utf-8"))
    assert 8555 in {q["id"] for c in raids["chains"] for q in c["quests"]}
