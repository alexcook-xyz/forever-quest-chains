"""Selection rules for the dungeon codas and reputations (issue #20) and their journal writer."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import select_codas as sc  # noqa: E402
import write_coda_journals as wj  # noqa: E402


def fact(qid, level=10, races=(), pre=(), group=()):
    return {"id": qid, "requiredLevel": level, "races": list(races), "preQuestSingle": list(pre),
            "preQuestGroup": list(group)}


def test_faction_of_names_a_whole_faction_or_nobody():
    assert sc.faction_of(fact(1)) == "Neutral"
    assert sc.faction_of(fact(1, races=sc.ALLIANCE)) == "Alliance"
    assert sc.faction_of(fact(1, races=sc.HORDE - {"Skyborne (Horde)"})) == "Horde"
    # Orc, Tauren and Troll only: no Undead, so the quest is not open to the whole Horde.
    assert sc.faction_of(fact(1, races={"Orc", "Tauren", "Troll"})) is None


def test_order_puts_prerequisites_first_then_level(monkeypatch):
    monkeypatch.setattr(sc, "pandabase_before", lambda: {})
    facts = {1: fact(1, 30, pre=[2]), 2: fact(2, 40), 3: fact(3, 20)}
    assert sc.order([1, 2, 3], facts) == [3, 2, 1]


def test_order_also_follows_the_pandabase_prerequisites(monkeypatch):
    monkeypatch.setattr(sc, "pandabase_before", lambda: {1: {2}})
    facts = {1: fact(1, 10), 2: fact(2, 50)}
    assert sc.order([1, 2], facts) == [2, 1]


def test_order_survives_a_prerequisite_cycle(monkeypatch):
    monkeypatch.setattr(sc, "pandabase_before", lambda: {})
    facts = {1: fact(1, 10, pre=[2]), 2: fact(2, 20, pre=[1])}
    assert sc.order([1, 2], facts) == [1, 2]


def test_cascade_drops_a_quest_whose_prerequisite_is_not_in_the_guide():
    facts = {1: fact(1), 2: fact(2, pre=[1]), 3: fact(3, pre=[2]), 4: fact(4, pre=[99]), 5: fact(5, pre=[98])}
    assert sc.cascade({1, 2, 3, 4, 5}, facts, gone={1}) == set()  # 2 and 3 need 1; 4 and 5 need quests outside
    assert sc.cascade({1, 2, 3, 4, 5}, facts, gone=set(), have={98, 99}) == {1, 2, 3, 4, 5}
    assert sc.cascade({1, 2, 3, 4, 5}, facts, gone=set()) == {1, 2, 3}


def test_the_committed_journals_match_the_facts():
    assert wj.main(["--check"]) == 0


def test_a_title_with_a_person_word_is_replaced():
    for name in ("Ironband Wants You!", "They Call Me \"The Rooster\"", "Our Town"):
        assert wj.PERSON.search(name)
    for name in ("Meet at the Grave", "Your", "Mission"):
        assert bool(wj.PERSON.search(name)) == (name == "Your")


def _spec_dir(tmp_path, monkeypatch, chain_id="c1", quest_id=1):
    """A one-quest spec and facts folder for the journal writer."""
    import json
    spec = {"saga": "Neutral", "file": "Dungeons", "chainsOnly": True, "route": [],
            "chains": [{"id": chain_id, "name": "Chain", "zone": "Zone", "summary": "S", "quests": [{"id": quest_id}]}]}
    (tmp_path / "dungeons.json").write_text(json.dumps(spec), encoding="utf-8")
    monkeypatch.setattr(wj, "SAGAS", tmp_path)
    return spec


def test_journal_writer_rejects_a_chain_id_that_is_not_plain(tmp_path, monkeypatch):
    # The chain id is written as a bare Lua key, so it must pass the same check as gen_saga.
    import pytest
    _spec_dir(tmp_path, monkeypatch, chain_id='x"] = os.exit() --')
    with pytest.raises(wj.gs.SpecError, match="chain id"):
        wj.render("dungeons")


def test_journal_writer_rejects_a_quest_id_that_is_not_an_integer(tmp_path, monkeypatch):
    import pytest
    _spec_dir(tmp_path, monkeypatch, quest_id="1] = nil --")
    with pytest.raises(wj.gs.SpecError, match="quest ID"):
        wj.render("dungeons")


def test_fetch_workers_must_be_a_small_positive_number(capsys):
    import pytest
    import gen_saga
    for bad in ("0", "-1", "17"):  # the check runs before any request
        with pytest.raises(SystemExit):
            gen_saga.main(["facts", "--all", "--workers", bad])


def gated(qid, **kw):
    f = {"id": qid, "classes": [], "specialFlags": 0, "requiredLevel": 10, "questLevel": 10, "races": [],
         "preQuestSingle": [], "preQuestGroup": []}
    f.update(kw)
    return f


def test_eligible_refuses_a_class_gate_unless_the_quest_is_exempt():
    assert sc.eligible(gated(1))
    assert not sc.eligible(gated(1, classes=["Mage"]))
    assert not sc.eligible(gated(1, classes=["Mage"]), {2})
    assert sc.eligible(gated(1, classes=["Mage"]), {1})
    assert not sc.eligible(gated(1, specialFlags=1))
    assert not sc.eligible(gated(1, requiredLevel=1))


def test_keep_set_drops_a_conflict_and_what_needs_it():
    facts = {1: {**gated(1)}, 2: {**gated(2), "preQuestSingle": [1]}, 3: {**gated(3), "preQuestSingle": [9]}}
    assert sc.keep_set(facts, {9}, {1}, set()) == {3}


def test_claim_gives_a_quest_to_the_first_chain_and_applies_the_override(monkeypatch):
    chains = (("a", "A", "Z"), ("b", "B", "Z"))
    monkeypatch.setattr(sc, "closure", lambda seed, q, n, t: {i: gated(i) for i in seed})
    override = {1: gated(1, classes=["Mage"])}
    claimed, facts = sc.claim(chains, {"a": [1, 2], "b": [2, 3]}, None, None, set(), {1}, override)
    assert claimed == {1: "a", 2: "a", 3: "b"}
    assert facts[1]["classes"] == ["Mage"]  # the override replaced the fact, and the exempt id stays eligible


def _spec_chains():
    import json
    out = {}
    for stem in sc.CODA_STEMS:
        doc = json.loads((sc.SAGAS / f"{stem}.json").read_text(encoding="utf-8"))
        out.update({c["id"]: c for c in doc["chains"]})
    return out


def test_after_in_the_specs_is_the_after_map_of_the_selectors():
    """Issue #74: the committed coda specs hold exactly the `after` lists of AFTER, and each ID is a chain."""
    chains = _spec_chains()
    assert {cid: c["after"] for cid, c in chains.items() if "after" in c} == sc.AFTER
    assert all(a in chains for after in sc.AFTER.values() for a in after)


def test_with_after_sets_only_the_chains_that_after_names():
    chains = [{"id": "raid_molten_core"}, {"id": "other"}]
    assert sc.with_after(chains) == [{"id": "raid_molten_core", "after": ["raid_blackwing_lair"]}, {"id": "other"}]


def test_moved_quests_are_in_the_chain_of_their_target_zone():
    """Issue #74: the Ras Frostwhisper quests 5461 to 5463 are in the Scholomance chain, not in Stratholme."""
    chains = _spec_chains()
    held = {cid: {q["id"] for q in c["quests"]} for cid, c in chains.items()}
    assert sc.MOVED_TO_ZONE == {5461: 2057, 5462: 2057, 5463: 2057}
    assert {5461, 5462, 5463} <= held["dungeon_scholomance"]
    assert not {5461, 5462, 5463} & held["dungeon_stratholme"]


def test_move_quests_moves_only_the_quests_that_a_list_holds(monkeypatch):
    monkeypatch.setattr(sc, "MOVED_TO_ZONE", {2: 20, 9: 20})
    assert sc.move_quests({10: [1, 2], 20: [3]}) == {10: [1], 20: [3, 2]}  # 9 is in no list: it stays out
