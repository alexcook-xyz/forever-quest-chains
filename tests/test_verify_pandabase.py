import copy
import json

import pytest

import extract_questie as eq
import verify_pandabase as vp
from test_extract_questie import NPC_TEXT, QUEST_TEXT

PAGE = """<html><body>
<script type="application/json" id="map-givers-data">{"mapId": 1429, "pickup": {"x": 0.4892, "y": 0.4161}, "turnIn": {"x": 0.4892, "y": 0.4161}}</script>
<h1>Kobold Camp Cleanup</h1>
<span class="badge">Quest #7</span>
<h2>Who it is for</h2>
<dl><dt>Faction</dt><dd>Alliance only</dd><dt>Race</dt><dd>Human, Dwarf, Night Elf, Gnome, Skyborne (Alliance)</dd>
<dt>Class</dt><dd>any class</dd><dt>Level</dt><dd>quest level 2, requires level 1</dd></dl>
<h2>What to do</h2><p>Kill 10 Kobold Vermin, then return to Marshal McBride.</p>
<h2>The chain</h2><p>Before this</p><a>A Threat Within</a><span>#783 &middot; any one of these</span>
<p>After this</p><a>Investigate Echo Ridge</a><span>#15</span><a>Simple Letter</a><span>#3100</span>
<h2>Where it starts and ends</h2>
<dt>Starts at</dt><dd>Marshal McBride</dd><dd>npc &middot; Elwynn Forest at 0.489, 0.416</dd>
<dt>Hand in to</dt><dd>Marshal McBride</dd><dd>npc &middot; Elwynn Forest at 0.489, 0.416</dd>
<p>Where Kobold Camp Cleanup starts and ends in Elwynn Forest</p>
</body></html>"""


@pytest.fixture()
def fact():
    return eq.quest_fact(7, eq.EntityDB(QUEST_TEXT), eq.EntityDB(NPC_TEXT))


def test_parse_quest_page():
    pb = vp.parse_quest_page(PAGE)
    assert pb["id"] == 7 and pb["name"] == "Kobold Camp Cleanup"
    assert (pb["questLevel"], pb["requiredLevel"]) == (2, 1)
    assert pb["races"] == ["Human", "Dwarf", "Night Elf", "Gnome", "Skyborne (Alliance)"]
    assert pb["before"] == [783] and pb["after"] == [15, 3100]
    assert (pb["beforeAll"], pb["beforeAny"]) == ([], [783])
    assert pb["classes"] == [] and pb["mapId"] == 1429
    assert pb["objective"] == "Kill 10 Kobold Vermin, then return to Marshal McBride."
    assert pb["startedBy"] == {"name": "Marshal McBride", "kind": "npc", "zone": "Elwynn Forest",
                               "x": 48.92, "y": 41.61, "located": True}


def test_off_map_point_is_not_a_location():
    # PandaBase writes -0.010 for an object with no known place.
    page = PAGE.replace('"pickup": {"x": 0.4892, "y": 0.4161}', '"pickup": {"x": -0.01, "y": -0.01}') \
               .replace("npc &middot; Elwynn Forest at 0.489, 0.416</dd>\n<dt>Hand",
                        "object &middot; Referenced dungeon area at -0.010, -0.010</dd>\n<dt>Hand")
    start = vp.parse_quest_page(page)["startedBy"]
    assert start["kind"] == "object" and start["located"] is False and start["x"] is None


def test_blob_point_on_another_map_keeps_text_value():
    page = PAGE.replace('{"mapId": 1429,', '{"art": {"zone": "Elwynn Forest"}, "mapId": 1429,') \
               .replace('"turnIn": {"x": 0.4892, "y": 0.4161}', '"turnIn": {"x": 0.9, "y": 0.9}') \
               .replace("</dd>\n<p>Where", "</dd>\n<p>Where") \
               .replace("Hand in to</dt><dd>Marshal McBride</dd><dd>npc &middot; Elwynn Forest at 0.489, 0.416",
                        "Hand in to</dt><dd>Senator Barin Redstone</dd><dd>npc &middot; Ironforge at 0.396, 0.575")
    end = vp.parse_quest_page(page)["finishedBy"]
    assert (end["zone"], end["x"], end["y"]) == ("Ironforge", 39.6, 57.5)


def test_all_and_any_prerequisites_and_class():
    page = PAGE.replace("#783 &middot; any one of these",
                        "#287 &middot; all of these</span><a>Secure</a><span>#98323 &middot; all of these") \
               .replace("<dd>any class</dd>", "<dd>Priest</dd>")
    pb = vp.parse_quest_page(page)
    assert (pb["beforeAll"], pb["beforeAny"], pb["classes"]) == ([287, 98323], [], ["Priest"])


def test_class_gate_mismatch_is_reported(fact):
    page = PAGE.replace("<dd>any class</dd>", "<dd>Priest</dd>")
    fields = {f for _, f, *_ in vp.compare(fact, vp.parse_quest_page(page))}
    assert fields == {"classes"}


def test_any_race_and_item_start_without_location():
    page = (PAGE.replace("Human, Dwarf, Night Elf, Gnome, Skyborne (Alliance)", "any race")
            .replace("npc &middot; Elwynn Forest at 0.489, 0.416</dd>\n<dt>Hand",
                     "item &middot; no recorded location</dd>\n<dt>Hand"))
    pb = vp.parse_quest_page(page)
    assert pb["races"] == []
    assert pb["startedBy"]["kind"] == "item" and pb["startedBy"]["located"] is True  # JSON blob wins
    page = page.replace('"pickup": {"x": 0.4892, "y": 0.4161}', '"pickup": null')
    assert vp.parse_quest_page(page)["startedBy"]["located"] is False


def test_matching_quest_is_verified(fact):
    assert vp.compare(fact, vp.parse_quest_page(PAGE)) == []


def test_mismatches_are_reported(fact):
    bad = copy.deepcopy(fact)
    bad["questLevel"] = 3
    bad["preQuestSingle"] = [999]
    bad["startedBy"]["creatures"][0]["spawns"] = {"12": [[10.0, 10.0]]}
    fields = {(s, f) for s, f, *_ in vp.compare(bad, vp.parse_quest_page(PAGE))}
    assert fields == {("mismatch", "questLevel"), ("mismatch", "before"), ("mismatch", "startedBy.coords")}


def test_missing_data_is_manual_never_guessed(fact):
    page = PAGE.replace('"pickup": {"x": 0.4892, "y": 0.4161}', '"pickup": null') \
               .replace("npc &middot; Elwynn Forest at 0.489, 0.416</dd>\n<dt>Hand",
                        "npc &middot; no recorded location</dd>\n<dt>Hand")
    findings = vp.compare(fact, vp.parse_quest_page(page))
    assert [(s, f) for s, f, *_ in findings] == [("manual", "startedBy.coords")]
    assert vp.status_of(findings) == "manual"


def test_questie_without_spawn_is_manual():
    npc_no_spawn = NPC_TEXT.replace("{[12]={{48.92,41.61}}}", "nil")
    fact = eq.quest_fact(7, eq.EntityDB(QUEST_TEXT), eq.EntityDB(npc_no_spawn))
    sev = {(s, f) for s, f, *_ in vp.compare(fact, vp.parse_quest_page(PAGE))}
    assert sev == {("manual", "startedBy.coords"), ("manual", "finishedBy.coords")}


def test_verify_and_exit_codes(fact):
    facts = {"quests": [fact, dict(fact, id=8, name="Ghost")]}
    pages = {7: PAGE, 8: None}
    results = vp.verify(facts, fetch=pages.__getitem__)
    assert [(r["id"], r["status"]) for r in results] == [(7, "verified"), (8, "not-found")]
    assert vp.exit_code(results) == 0
    assert vp.exit_code(results, strict=True) == 1
    results[0]["status"] = "mismatch"
    assert vp.exit_code(results) == 1
    only = vp.verify(facts, ids=[7], fetch=pages.__getitem__)
    assert [r["id"] for r in only] == [7]


def test_accepted_mismatch_needs_reason_and_values(fact, tmp_path):
    bad = copy.deepcopy(fact)
    bad["preQuestSingle"] = [999]
    facts = {"quests": [bad]}
    entry = {"id": 7, "field": "before", "reason": "Forever change", "questie": [999], "pandabase": [783]}
    results = vp.verify(facts, fetch={7: PAGE}.__getitem__, accepted={(7, "before"): entry})
    assert results[0]["status"] == "accepted" and vp.exit_code(results) == 0
    path = tmp_path / "accept.json"
    for broken in (dict(entry, reason=" "), {k: v for k, v in entry.items() if k != "questie"}):
        path.write_text(json.dumps({"accepted": [broken]}), encoding="utf-8")
        with pytest.raises(SystemExit):
            vp.load_accepted(path)
    path.write_text(json.dumps({"accepted": [entry]}), encoding="utf-8")
    assert vp.load_accepted(path) == {(7, "before"): entry}


def test_changed_values_in_an_accepted_field_fail_again(fact):
    bad = copy.deepcopy(fact)
    bad["preQuestSingle"] = [998]   # not the investigated [999]
    entry = {"id": 7, "field": "before", "reason": "Forever change", "questie": [999], "pandabase": [783]}
    results = vp.verify({"quests": [bad]}, fetch={7: PAGE}.__getitem__, accepted={(7, "before"): entry})
    assert results[0]["status"] == "mismatch" and vp.exit_code(results) == 1


def test_objective_counts_read_digits_and_words():
    assert vp.objective_counts("Kill ten Foo and 5 Bar, then 10 more.") == {5, 10}
    assert vp.objective_counts("Speak with Sarvis.") == set()
    assert vp.objective_counts(None) == set()


def test_different_objective_counts_are_a_mismatch(fact):
    """Issue #53: Questie said 5 Sigil Fragments, Forever says 11."""
    pb = vp.parse_quest_page(PAGE)
    fact = copy.deepcopy(fact)
    fact["objectivesText"] = ["Kill 10 Kobold Vermin, then return to Marshal McBride."]
    assert [f for f in vp.compare(fact, pb) if f[1] == "counts"] == []
    fact["objectivesText"] = ["Kill 5 Kobold Vermin, then return to Marshal McBride."]
    assert [f for f in vp.compare(fact, pb) if f[1] == "counts"] == [("mismatch", "counts", [5], [10])]
    pb["objective"] = None  # no Forever text: nothing to compare
    assert [f for f in vp.compare(fact, pb) if f[1] == "counts"] == []
