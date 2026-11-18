import json

import pytest

import extract_questie as eq

QUEST_TEXT = """\
-- AUTO GENERATED FILE! DO NOT EDIT!
QuestieDB.questData = [[return {
[7] = {"Kobold Camp Cleanup",{{197}},{{197}},1,2,4294967373,nil,{"Kill 10 Kobold Vermin, then return to Marshal McBride."},nil,{{{6}}},nil,nil,{783},nil,nil,nil,9,nil,nil,nil,nil,nil,8,nil,nil,{{72,250}}},
[783] = {"A Threat Within",{{823}},{{197}},1,1,4294967373,nil,{"Speak with Marshal McBride."},nil,nil,nil,nil,nil,nil,nil,nil,9,nil,nil,nil,nil,7,8,nil,nil,{{72,75}}},
[2] = {"Sharptalon's \\"Claw\\"",{nil,nil,{16305}},{{12696}},20,30,8589934770,nil,nil,nil,nil,16305,nil,{6383},nil,{23,24},nil,331},
[11] = {"Any Race Quest",{{1}},{{1}},5,5,0,0,nil,nil,nil,nil,nil,nil,nil,nil,nil,12},
}]]
"""
NPC_TEXT = """\
QuestieDB.npcData = [[return {
[197] = {'Marshal McBride',100,100,10,10,0,{[12]={{48.92,41.61}}},nil,12,{7,783},{7,783},12,"A",nil,3},
[1] = {'Nowhere Man',1,1,1,1,0,nil,nil,0,nil,nil,35,"AH",nil,0},
[12696] = {'Senani Thunderheart',1,1,1,1,0,{[331]={{73.78,61.46}}},nil,331,nil,nil,35,"H",nil,0},
}]]
"""


@pytest.fixture()
def dbs():
    return eq.EntityDB(QUEST_TEXT), eq.EntityDB(NPC_TEXT)


def test_parse_lua_scalars_and_tables():
    assert eq.parse_lua('{1,nil,{2},"a\\"b",-3.5,true}') == [1, None, [2], 'a"b', -3.5, True]
    assert eq.parse_lua("{[12]={{1.5,2},{3,4}},[9]=nil}") == {12: [[1.5, 2], [3, 4]], 9: None}
    with pytest.raises(eq.LuaParseError):
        eq.parse_lua("{1} junk")


def test_entity_db_indexes_rows(dbs):
    quests, npcs = dbs
    assert quests.ids() == [2, 7, 11, 783]
    assert len(npcs) == 3 and 197 in npcs and 5 not in npcs
    assert quests.get(5) is None


def test_quest_fact_decodes_fields(dbs):
    quests, npcs = dbs
    fact = eq.quest_fact(7, quests, npcs)
    assert fact["name"] == "Kobold Camp Cleanup"
    assert (fact["requiredLevel"], fact["questLevel"]) == (1, 2)
    assert fact["races"] == ["Human", "Dwarf", "Night Elf", "Gnome", "Skyborne (Alliance)"]
    assert fact["preQuestSingle"] == [783]
    giver = fact["startedBy"]["creatures"][0]
    assert giver == {"id": 197, "name": "Marshal McBride", "zoneID": 12,
                     "spawns": {"12": [[48.92, 41.61]]}}


def test_item_start_and_escaped_name(dbs):
    fact = eq.quest_fact(2, *dbs)
    assert fact["name"] == 'Sharptalon\'s "Claw"'
    assert fact["startedBy"] == {"creatures": [], "objects": [], "items": [16305]}
    assert fact["races"][-1] == "Skyborne (Horde)"


def test_no_race_restriction_is_empty(dbs):
    assert eq.quest_fact(11, *dbs)["races"] == []


def test_missing_npc_gives_empty_spawns_not_guesses():
    fact = eq.quest_fact(7, eq.EntityDB(QUEST_TEXT), None)
    assert fact["startedBy"]["creatures"][0]["spawns"] == {}


def test_unmapped_bits_are_reported():
    names, unknown = eq.decode_mask(1 << 40 | 1, eq.RACE_BITS)
    assert names == ["Human"] and unknown == [40]


def test_select_by_race_excludes_unrestricted(dbs):
    quests, _ = dbs
    assert eq.select_ids(quests, None, "Human") == [7, 783]
    assert eq.select_ids(quests, None, "orc") == [2]
    assert eq.select_ids(quests, [783, 7, 7], None) == [7, 783]
    with pytest.raises(SystemExit):
        eq.select_ids(quests, None, "Murloc")


def test_output_is_deterministic_and_lists_missing(dbs):
    quests, npcs = dbs
    a = eq.dumps(eq.build_output(quests, npcs, [783, 7, 999], {"ref": "t"}))
    b = eq.dumps(eq.build_output(quests, npcs, [783, 7, 999], {"ref": "t"}))
    assert a == b and a.endswith("\n")
    data = json.loads(a)
    assert data["missing"] == [999]
    assert [q["id"] for q in data["quests"]] == [783, 7]


def test_cli_roundtrip(tmp_path, capsys):
    q, n = tmp_path / "q.lua", tmp_path / "n.lua"
    q.write_text(QUEST_TEXT, encoding="utf-8")
    n.write_text(NPC_TEXT, encoding="utf-8")
    out = tmp_path / "out.json"
    assert eq.main(["--quest-db", str(q), "--npc-db", str(n), "--ids", "7", "--out", str(out)]) == 0
    data = json.loads(out.read_text(encoding="utf-8"))
    assert data["quests"][0]["name"] == "Kobold Camp Cleanup"
    assert data["source"]["questDbSha256"] == eq.sha256_file(q)
    with pytest.raises(SystemExit):
        eq.main(["--quest-db", str(q), "--npc-db", str(n)])


# ------------------------------------------------- PandaBase fallback (#13)
PB_SECURE = {
    "id": 98323, "name": "Secure the Mountain", "questLevel": 8, "requiredLevel": 4,
    "races": ["Human", "Dwarf", "Night Elf", "Gnome", "Skyborne (Alliance)"], "classes": [],
    "before": [98319], "beforeAll": [], "beforeAny": [98319], "after": [291],
    "startedBy": {"name": "Mountaineer Gretchen", "kind": "npc", "zone": "Dun Morogh",
                  "x": 44.1, "y": 57.07, "located": True},
    "finishedBy": {"name": "Senir Whitebeard", "kind": "npc", "zone": "Dun Morogh",
                   "x": 46.73, "y": 53.83, "located": True},
    "mapId": 1426, "mapZone": "Dun Morogh",
    "objective": "Speak with Senir Whitebeard in Kharanos.",
}


def test_fallback_fills_only_ids_questie_lacks(dbs):
    quests, npcs = dbs
    asked = []

    def fallback(qid):
        asked.append(qid)
        return PB_SECURE if qid == 98323 else None

    data = eq.build_output(quests, npcs, [7, 98323, 99999], {"ref": "t"}, fallback)
    assert asked == [98323, 99999]          # Questie IDs never go to PandaBase
    assert data["pandabase"] == [98323] and data["missing"] == [99999]
    q7, pb = data["quests"]
    assert q7["source"] == "questie" and pb["source"] == "pandabase"


def test_pandabase_fact_has_questie_shape_and_recorded_points(dbs):
    quests, npcs = dbs
    fact = eq.pandabase_fact(98323, PB_SECURE)
    assert set(fact) == set(eq.quest_fact(7, quests, npcs))
    assert fact["zoneOrSort"] == 1 and fact["preQuestSingle"] == [98319]
    assert fact["nextQuestInChain"] == 291
    assert fact["objectivesText"] == ["Speak with Senir Whitebeard in Kharanos."]
    giver = fact["startedBy"]["creatures"][0]
    assert giver == {"id": None, "name": "Mountaineer Gretchen", "zoneID": 1,
                     "spawns": {"1": [[44.1, 57.07]]}}


def test_pandabase_fact_never_guesses_points():
    pb = dict(PB_SECURE)
    pb["startedBy"] = dict(pb["startedBy"], located=False, x=None, y=None)
    pb["finishedBy"] = dict(pb["finishedBy"], zone="Some Unlisted Zone")
    fact = eq.pandabase_fact(98323, pb)
    assert fact["startedBy"]["creatures"][0]["spawns"] == {}
    assert fact["finishedBy"]["creatures"][0]["spawns"] == {}


def test_fallback_flag_needs_ids(tmp_path):
    q = tmp_path / "q.lua"
    q.write_text(QUEST_TEXT, encoding="utf-8")
    with pytest.raises(SystemExit):
        eq.main(["--quest-db", str(q), "--race", "Human", "--pandabase-fallback"])
