"""Race sagas: 2.1 Gnome + Dwarf wave (issue #13), 2.2 Night Elf (issue #14),
2.3 Alliance spine (issue #15), 3.3 Forsaken and the Horde spine (issue #18).

Loads the real addon data files in the .toc order (Sagas, Shared_Alliance,
Data/Journal/Route for Human, Dwarf, Gnome and Night Elf) in Lua 5.1 and
checks:

- each saga has data and a route, and the Human view is unchanged;
- each saga's route walks only chains that saga can see (own + shared);
- route order meets every prerequisite from Questie and from PandaBase
  (Forever), so there is no gap the guide cannot explain;
- class audit: no route quest is class-gated in either source;
- each route quest is open to the saga's race;
- every new chain quest has a journal page and every new chain an epilogue.
"""
from __future__ import annotations

import json
import pathlib

import pytest

import gen_saga as gs

lua51 = pytest.importorskip("lupa.lua51")

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Forever gates these Naxxramas armor-token quests by class; their facts come from PandaBase (issue #69).
ARMOR_TOKEN_IDS = {9234, 9235, 9236, 9238, 9239, 9240, 9241, 9242, 9243, 9244, 9245, 9246}
ADDON = ROOT / "MainStoryGuide"
SAGAS = ROOT / "tools" / "sagas"
FILES = ["Sagas.lua", "Shared_Alliance.lua", "Shared_Durotar.lua", "Shared_Horde.lua",
         "Data_Human.lua", "Data_HumanDiplomat.lua", "Journal_Human.lua", "Route_Human.lua",
         "Data_Dwarf.lua", "Journal_Dwarf.lua", "Route_Dwarf.lua",
         "Data_Gnome.lua", "Journal_Gnome.lua", "Route_Gnome.lua",
         "Data_NightElf.lua", "Journal_NightElf.lua", "Route_NightElf.lua",
         "Data_Orc.lua", "Data_HordeSpine.lua", "Journal_Orc.lua", "Journal_HordeSpine.lua", "Route_Orc.lua",
         "Data_Troll.lua", "Journal_Troll.lua", "Route_Troll.lua",
         "Data_Tauren.lua", "Journal_Tauren.lua", "Route_Tauren.lua",
         "Data_Scourge.lua", "Journal_Scourge.lua", "Route_Scourge.lua",
         "Data_Neutral.lua", "Journal_Neutral.lua",
         "Data_Dungeons.lua", "Journal_Dungeons.lua", "Data_Reputations.lua", "Journal_Reputations.lua",
         "Data_Raids.lua", "Journal_Raids.lua", "Data_ZGAQ.lua", "Journal_ZGAQ.lua",
         "Data_Naxx.lua", "Journal_Naxx.lua"]
# Barrens and Stranglethorn Vale chains the Orc saga owns and the other Horde sagas walk
# (Data_HordeSpine.lua, Shared_Horde.lua; issue #18).
HORDE_SPINE = [c["id"] for c in json.loads((SAGAS / "horde_spine.json").read_text(encoding="utf-8"))["chains"]]
# Chains the Forsaken saga owns (Data_Scourge.lua).
SCOURGE_CHAINS = [c["id"] for c in json.loads((SAGAS / "scourge.json").read_text(encoding="utf-8"))["chains"]]
NEW_CHAINS = {"Dwarf": ["coldridge", "frostmane", "kings_lands", "excavation", "dark_threat"],
              "Gnome": ["exiles", "gnomeregan"],
              "NightElf": ["shadowglen", "crown_of_the_earth", "gnarlpine", "timberlings",
                           "temple_of_the_moon", "enchanted_glade", "nessa", "bashal_aran",
                           "expanding_horizons", "cliffspring", "onu", "prospector", "ashenvale"],
              "Orc": ["trials", "kolkar", "betrayers", "peons", "skull_rock"] + HORDE_SPINE,
              "Troll": ["echo_isles"],
              "Tauren": ["narache", "rites", "wells", "bloodhoof", "venture", "longwalkers",
                         "crossroads_road"],
              "Scourge": SCOURGE_CHAINS}
# Neutral MAIN chains (issue #19): no saga owns them, both factions see them.
NEUTRAL_SPEC = json.loads((SAGAS / "neutral.json").read_text(encoding="utf-8"))
NEUTRAL_CHAINS = [c["id"] for c in NEUTRAL_SPEC["chains"]]
# Dungeon codas and reputation chains (issue #20): Neutral chains; a chain with a faction is
# visible to that faction only.
CODA_SPECS = {n: json.loads((SAGAS / f"{n}.json").read_text(encoding="utf-8")) for n in ("dungeons", "reputations", "raids", "zg_aq", "naxx")}
CODA_CHAINS = [c for spec in CODA_SPECS.values() for c in spec["chains"]]
SAGA_FACTION = {"Human": "Alliance", "Dwarf": "Alliance", "Gnome": "Alliance", "NightElf": "Alliance",
                "Orc": "Horde", "Troll": "Horde", "Tauren": "Horde", "Scourge": "Horde"}


def coda_ids(key):
    """Coda chain IDs that the saga `key` sees."""
    return [c["id"] for c in CODA_CHAINS if c.get("faction", SAGA_FACTION[key]) == SAGA_FACTION[key]]


ALL_NEW_CHAINS = {c for cs in NEW_CHAINS.values() for c in cs}
# Human chains every other Alliance saga walks after its own (issue #15).
SPINE = ["defias_brotherhood", "redridge", "stockade", "stalvan", "duskwood_darkness",
         "missing_diplomat", "onyxia"]
# Human chains no other saga walks: starters, and the Militia (quest 65 needs no
# Militia quest).
HUMAN_ONLY = ["northshire", "elwynn", "peoples_militia"]
# Chains a saga walks that another saga owns (Shared_Alliance.lua and Shared_Durotar.lua).
SHARED = {"Dwarf": ["gnomeregan"] + SPINE,
          "Gnome": ["coldridge", "frostmane", "kings_lands", "excavation", "dark_threat"] + SPINE,
          "NightElf": list(SPINE),
          "Orc": [],
          "Troll": NEW_CHAINS["Orc"],
          "Tauren": HORDE_SPINE,
          "Scourge": HORDE_SPINE}
STARTER = {"Dwarf": "coldridge", "Gnome": "coldridge", "NightElf": "shadowglen", "Orc": "trials", "Troll": "trials",
           "Tauren": "narache", "Scourge": "deathknell"}
RACE_LABEL = {key: gs.RACE_LABELS.get(key, key) for key in NEW_CHAINS}
# UiMapIDs each saga's own chains may point at (Dun Morogh, Loch Modan,
# Wetlands, Stormwind, Ironforge; Teldrassil, Darkshore, Ashenvale, Darnassus; Durotar, The Barrens, Orgrimmar;
# Mulgore, The Barrens, Thunder Bluff; Tirisfal Glades, Silverpine Forest, Undercity; Stranglethorn Vale).
# The Orc map list also holds the spine: Stranglethorn Vale (1434) and Thunder Bluff (1456).
SAGA_MAPS = {"Dwarf": (1426, 1432, 1437, 1453, 1455),
             "Gnome": (1426, 1432, 1437, 1453, 1455),
             "NightElf": (1437, 1438, 1439, 1440, 1453, 1457),
             "Orc": (1411, 1413, 1454, 1434, 1456, 1417, 1420, 1422, 1423, 1424, 1425, 1435, 1440, 1441, 1442, 1443,
             1444, 1445, 1447, 1448, 1449, 1452, 1458),
             "Troll": (1411, 1413, 1454),
             "Tauren": (1412, 1413, 1456),
             "Scourge": (1420, 1421, 1458, 1413)}

# Every Horde saga walks its own chains, then the Horde spine (issue #18).
HORDE = ("Orc", "Troll", "Tauren", "Scourge")
MIN_ROUTE = {"Orc": 30, "Troll": 35}
# Quest 794 needs Vile Familiars, which has one variant per class (792 for eight
# classes, 1499 for Warlock). The guide leaves class quests off the route, so
# these are the only any-of groups that may have no member on it.
CLASS_VARIANT_PREREQS = {794: {792, 1499}}

HARNESS = r"""
return function(files, race, faction)
  UnitRace = function() return race, race end
  UnitFactionGroup = function() return faction, faction end
  local ns = {}
  for _, f in ipairs(files) do
    assert(loadstring(f[2], "@" .. f[1]))("MainStoryGuide", ns)
  end
  return ns
end
"""


def load(race: str):
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    files = rt.table(*[rt.table(name, (ADDON / name).read_text(encoding="utf-8")) for name in FILES])
    ns = rt.execute(HARNESS)(files, race, "Horde" if race in HORDE else "Alliance")
    ns.RebuildView()
    return ns


def lua_list(t) -> list:
    return [t[i] for i in range(1, len(t) + 1)] if t else []


def view(ns) -> dict[str, list[int]]:
    return {c.id: [q.id for q in lua_list(c.quests)] for c in lua_list(ns.Chains)}


def facts() -> tuple[dict[int, dict], dict[int, dict]]:
    quests, pages = {}, {}
    for saga_key in NEW_CHAINS:
        doc = json.loads((SAGAS / f"{saga_key.lower()}.facts.json").read_text(encoding="utf-8"))
        quests.update({q["id"]: q for q in doc["quests"]})
        pages.update({int(k): v for k, v in doc["pandabase_pages"].items()})
    return quests, pages


FACTS, PAGES = facts()


@pytest.fixture(scope="module", params=list(NEW_CHAINS))
def saga(request):
    ns = load(request.param)
    return request.param, ns, lua_list(ns.StoryRoute)


def test_each_saga_has_data_and_is_active(saga):
    key, ns, route = saga
    assert ns.SagaHasData(key) and ns.ActiveSaga == key
    assert len(route) > MIN_ROUTE.get(key, 40)


def test_route_walks_only_visible_chains(saga):
    key, ns, route = saga
    visible = {qid for ids in view(ns).values() for qid in ids}
    assert [q for q in route if q not in visible] == []
    groups = {c.id: ns.ChainGroup(c, key) for c in lua_list(ns.Chains)}
    for chain in NEW_CHAINS[key]:
        assert groups[chain] == "race"
    for chain in SHARED[key]:
        assert groups[chain] == "shared"
    foreign = ALL_NEW_CHAINS - set(NEW_CHAINS[key]) - set(SHARED[key])
    assert sorted(foreign & set(groups)) == []  # no other saga's own chains
    assert sorted(set(HUMAN_ONLY) & set(groups)) == []


@pytest.fixture(scope="module")
def human_route():
    return lua_list(load("Human").StoryRoute)


def test_route_joins_the_human_spine(saga, human_route):
    """The saga's own chains come before the spine (Gnomeregan, level 20+,
    is the one race chain inside it), then the spine runs to the Onyxia
    finale. Each spine quest on the route keeps the Human route order."""
    if saga[0] in HORDE:
        pytest.skip("Horde sagas walk the Horde spine, not the Human spine")
    key, ns, route = saga
    pos = {q: i for i, q in enumerate(route)}
    spine = {q.id for c in lua_list(ns.Chains) if c.id in SPINE for q in lua_list(c.quests)}
    on_route = spine & set(route)
    assert [q for q in route if q in on_route] == [q for q in human_route if q in on_route]
    assert route[-1] == 6502
    early = {q.id for c in lua_list(ns.Chains) if c.id in NEW_CHAINS[key] and c.id != "gnomeregan"
             for q in lua_list(c.quests)}
    assert max(pos[q] for q in early if q in pos) < pos[65]
    # The whole spine is on the route: 125 opens 89, and the Morbent Fel
    # road (323 to 325) opens 55.
    assert spine - set(route) == set()


# Where each race route is just before quest 65: the hand-in of the quest before it.
ROAD_TO_WESTFALL = {"Dwarf": "Leave Loch Modan", "Gnome": "Leave Stormwind City",
                    "NightElf": "Leave Menethil Harbor"}


def test_route_info_by_saga_changes_only_that_saga(saga):
    """Each race route reaches quest 65 from another zone, so its task names
    that road. The Human text and the shared table stay as they are."""
    if saga[0] in HORDE:
        pytest.skip("Horde sagas do not walk quest 65")
    key, ns, _ = saga
    base = load("Human").RouteInfoOf(65)
    assert base.task.startswith("Begin Stoutmantle's investigation")
    assert ns.RouteInfoOf(65).task.startswith(ROAD_TO_WESTFALL[key])
    assert ns.RouteInfoOf(65, "Human").task == base.task
    assert ns.RouteInfo[65].task == base.task  # the shared table is not changed
    assert ns.RouteInfoOf(20).task == ns.RouteInfo[20].task  # no override: shared text


def test_human_view_is_unchanged():
    ns = load("Human")
    chains = view(ns)
    assert not set(chains) & ALL_NEW_CHAINS
    route_chains = [
        "northshire", "elwynn", "peoples_militia", "defias_brotherhood",
        "redridge", "stockade", "stalvan", "duskwood_darkness",
        "missing_diplomat", "onyxia",
    ]
    # The route chains keep their order. Issue #57: the three main neutral chains (issue #19)
    # sit among them by required level. The dungeon codas and the reputations (issue #20) follow.
    assert [c for c in chains if c in route_chains] == route_chains
    assert sorted(c for c in chains if c not in route_chains) == sorted(
        [*NEUTRAL_CHAINS, *coda_ids("Human")])
    # 111 story quests, plus quest 1324 of The Missing Diplomat (issue #38).
    assert len(lua_list(ns.StoryRoute)) == 112


# Issue #57: the main neutral chains (issue #19) sit among the route chains by required level.
# The other neutral chains (dungeons, reputations, raids, Naxxramas) follow the route.
ALL_SAGAS = ["Human", *NEW_CHAINS]
NEUTRAL_FACT_FILES = ("neutral", *CODA_SPECS)


def chain_level(chain) -> int:
    return chain.minLevel if chain.minLevel is not None else 1


@pytest.mark.parametrize("key", ALL_SAGAS)
def test_main_neutral_chains_sort_by_level_among_route_chains(key):
    ns = load(key)
    chains = lua_list(ns.Chains)
    group = {c.id: ns.ChainGroup(c, key) for c in chains}
    route = [c for c in chains if group[c.id] in ("race", "shared")]
    main = [c for c in chains if c.id in NEUTRAL_CHAINS]
    other = [c for c in chains if group[c.id] == "neutral" and c.id not in NEUTRAL_CHAINS]
    pos = {c.id: i for i, c in enumerate(chains)}
    registered = {c.id: i for i, c in enumerate(lua_list(ns.AllChains))}
    assert [c.id for c in main] and set(c.id for c in main) == set(NEUTRAL_CHAINS), key
    assert other, key
    # A new character still starts on the first route chain.
    assert chains[0].id == route[0].id
    # Forever chains stay last.
    tail = [group[c.id] for c in chains[max(pos[c.id] for c in main + other + route) + 1:]]
    assert set(tail) <= {"forever"}
    # Main chains are in level order. Equal levels keep registration order.
    keys = [(chain_level(c), registered[c.id]) for c in main]
    assert keys == sorted(keys), key
    for n in main:
        # No route chain before n (after the first one) has a higher level.
        before = [r for r in route[1:] if pos[r.id] < pos[n.id]]
        assert all(chain_level(r) <= chain_level(n) for r in before), (key, n.id)
        # The route chain right after n has a higher level.
        after = [r for r in route if pos[r.id] > pos[n.id]]
        if after:
            assert chain_level(after[0]) > chain_level(n), (key, n.id)
    # The other neutral chains follow the route and the main chains, in registration order.
    first_other = min(pos[c.id] for c in other)
    assert all(pos[c.id] < first_other for c in route + main), key
    # ... in registration order, except that a chain waits for the chains of its `after` list (issue #74).
    wait = {c.id: c for c in other}
    for c in other:
        for a in (lua_list(c.after) if c.after else []):
            if a in wait:
                assert pos[a] < pos[c.id], (key, c.id, a)
    free = [c for c in other if not c.after]
    assert [registered[c.id] for c in free] == sorted(registered[c.id] for c in free), key


@pytest.mark.parametrize("key", ALL_SAGAS)
def test_blackwing_lair_precedes_ahn_qiraj(key):
    """Quest 8733 (Ahn'Qiraj chain) needs 8555 (Blackwing Lair chain) in PandaBase.
    The `ahn_qiraj` chain names `raid_blackwing_lair` in its `after` list (issue #74), so the order
    of the two chains no longer depends on the order of the .toc files."""
    ids = [c.id for c in lua_list(load(key).Chains)]
    assert "raid_blackwing_lair" in ids and "ahn_qiraj" in ids, key
    assert ids.index("raid_blackwing_lair") < ids.index("ahn_qiraj"), key


def neutral_prereqs() -> tuple[dict[int, set[int]], dict[int, set[int]]]:
    every, anyone = {}, {}
    for name in NEUTRAL_FACT_FILES:
        doc = json.loads((SAGAS / f"{name}.facts.json").read_text(encoding="utf-8"))
        pages = doc["pandabase_pages"]
        for q in doc["quests"]:
            pb = pages.get(str(q["id"])) or {}
            every[q["id"]] = set(q["preQuestGroup"]) | set(pb.get("beforeAll") or [])
            anyone[q["id"]] = set(q["preQuestSingle"]) | set(pb.get("beforeAny") or [])
    return every, anyone


EVERY_PREREQ, ANY_PREREQ = neutral_prereqs()


# A neutral chain sometimes holds a quest whose prerequisite sits in a LATER chain of the view.
# The chain key `after` (issue #74, set in tools/select_codas.py AFTER) puts such a chain behind the
# chain that holds the prerequisite. No conflict is known now. Each key would be (chain, quest,
# "all-of" or "any-of", prerequisite quests) and each value the set of sagas whose view has the
# conflict. A conflict that appears fails the test; so does a listed one that goes away.
KNOWN_ORDER_CONFLICTS: dict[tuple, set[str]] = {}


def order_conflicts(key: str) -> set[tuple]:
    """Quests of a neutral chain whose prerequisite is in a later chain of the view.
    A prerequisite that is not in the view is not checked."""
    ns = load(key)
    chains = lua_list(ns.Chains)
    where = {}
    for i, c in enumerate(chains):
        for q in lua_list(c.quests):
            where.setdefault(q.id, i)
    found = set()
    for i, c in enumerate(chains):
        if ns.ChainGroup(c, key) != "neutral":
            continue
        for q in lua_list(c.quests):
            late = tuple(sorted(p for p in EVERY_PREREQ.get(q.id, ()) if p in where and where[p] > i))
            if late:
                found.add((c.id, q.id, "all-of", late))
            seen = [where[p] for p in ANY_PREREQ.get(q.id, ()) if p in where]
            if seen and min(seen) > i:
                found.add((c.id, q.id, "any-of", tuple(sorted(ANY_PREREQ[q.id]))))
    return found


@pytest.mark.parametrize("key", ALL_SAGAS)
def test_neutral_order_conflicts_are_exactly_the_known_ones(key):
    """A new conflict fails here. A known conflict that a later change fixes fails
    here too, so the list above stays true."""
    want = {c for c, sagas in KNOWN_ORDER_CONFLICTS.items() if key in sagas}
    assert order_conflicts(key) == want, key


def chain_prereq_pairs() -> set[tuple[str, str]]:
    """(chain, other chain) for each quest of a chain that has a prerequisite in another chain
    of the guide, from Questie and PandaBase."""
    chains = {}
    for key in ALL_SAGAS:
        for c in lua_list(load(key).Chains):
            chains[c.id] = c
    where = {}
    for cid, c in chains.items():
        for q in lua_list(c.quests):
            where.setdefault(q.id, cid)
    pairs = set()
    for cid, c in chains.items():
        for q in lua_list(c.quests):
            for p in EVERY_PREREQ.get(q.id, set()) | ANY_PREREQ.get(q.id, set()):
                if p in where and where[p] != cid:
                    pairs.add((cid, where[p]))
    return pairs


def after_pairs() -> set[tuple[str, str]]:
    out = set()
    for key in ALL_SAGAS:
        for c in lua_list(load(key).Chains):
            after = c.after
            out |= {(c.id, a) for a in (lua_list(after) if after else [])}
    return out


def test_after_names_chains_of_the_guide_and_each_has_a_prerequisite_quest():
    """Each `after` entry names a real chain, and a quest of the chain needs a quest of that chain
    (Questie or PandaBase), so the entry is a prerequisite and not a guess."""
    ids = {c.id for key in ALL_SAGAS for c in lua_list(load(key).Chains)}
    pairs = after_pairs()
    assert pairs, "no chain has an after list"
    assert all(a in ids and a != c for c, a in pairs)
    assert pairs <= chain_prereq_pairs()


def test_after_covers_the_known_prerequisite_chains():
    assert after_pairs() >= {
        ("dungeon_the_temple_of_atal_hakkar", "dungeon_the_temple_of_atal_hakkar_alliance"),
        ("dungeon_the_temple_of_atal_hakkar", "dungeon_zul_farrak"),
        ("raid_molten_core", "raid_blackwing_lair"),
        ("ahn_qiraj", "raid_blackwing_lair"),
    }


@pytest.mark.parametrize("key", ALL_SAGAS)
def test_blackwing_lair_precedes_molten_core(key):
    """Quest 8575 (Molten Core chain) needs 8555 (Blackwing Lair chain)."""
    ids = [c.id for c in lua_list(load(key).Chains)]
    assert ids.index("raid_blackwing_lair") < ids.index("raid_molten_core"), key


def test_toc_loads_raids_before_zg_aq():
    """Blackwing Lair (8555) and Ahn'Qiraj (8733) are neutral chains that stay behind the
    route in registration order, whatever their level. So the .toc load order of
    Data_Raids.lua and Data_ZGAQ.lua keeps 8555 first in the real addon."""
    toc = (ADDON / "MainStoryGuide.toc").read_text(encoding="utf-8").split()
    assert toc.index("Data_Raids.lua") < toc.index("Data_ZGAQ.lua")
    assert FILES.index("Data_Raids.lua") < FILES.index("Data_ZGAQ.lua")


def test_missing_diplomat_1248_task_is_shared():
    tasks = [load(race).RouteInfoOf(1248).task for race in ("Human", "Dwarf", "Gnome", "NightElf")]
    for task in tasks:
        assert "master route" not in task
    assert len(set(tasks)) == 1


def test_human_route_turns_match_the_generated_chain():
    ns = load("Human")
    spec = gs.load_spec(SAGAS / "human_diplomat.json")
    facts_doc = json.loads((SAGAS / "human_diplomat.facts.json").read_text(encoding="utf-8"))
    quests, pages = gs.facts_index(facts_doc)
    for chain in spec["chains"]:
        for sq in chain["quests"]:
            qid = sq["id"]
            info = gs._route_info(sq, quests[qid], pages.get(qid) or {}, [])
            entry = ns.RouteInfo[qid]
            turn = entry.turn if entry else None
            if "turn" in info:
                exp = info["turn"]
                assert turn is not None, f"quest {qid} expected turn {exp}"
                assert turn.name == exp["name"]
                assert turn.zone == exp["zone"]
                assert turn.map == exp["map"]
                assert abs(turn.x - exp["x"]) <= 0.05
                assert abs(turn.y - exp["y"]) <= 0.05
            else:
                assert turn is None, f"quest {qid} expected no turn, got {turn}"


def test_route_meets_every_prerequisite(saga):
    """Every all-of prerequisite (Questie or PandaBase) is earlier on the
    route, and every any-of group has one member earlier on the route. A
    prerequisite that is not on the route at all is a gap and fails."""
    key, _, route = saga
    pos = {q: i for i, q in enumerate(route)}
    problems = []
    for qid in route:
        f, pb = FACTS.get(qid), PAGES.get(qid) or {}
        assert f, f"no facts for route quest {qid}"
        every = set(f["preQuestGroup"]) | set(pb.get("beforeAll") or [])
        anyone = set(f["preQuestSingle"]) | set(pb.get("beforeAny") or [])
        for pre in sorted(every):
            if pos.get(pre, len(route)) > pos[qid]:
                problems.append(f"{qid} needs {pre} earlier on the route")
        if anyone == CLASS_VARIANT_PREREQS.get(qid):
            continue
        if anyone and not any(pos.get(p, len(route)) < pos[qid] for p in anyone):
            problems.append(f"{qid} needs one of {sorted(anyone)} earlier on the route")
    assert problems == []


# The last own quest of each Horde route and the first quest of the Horde spine.
SPINE_START = 871  # Disrupt the Attacks, Thork at the Crossroads
ANCHORS = {"Orc": 840, "Troll": 840, "Tauren": 854, "Scourge": 1358}


def own_route(key: str) -> list[int]:
    route = lua_list(load(key).StoryRoute)
    return route[:route.index(SPINE_START)]


def test_orc_and_troll_share_the_durotar_start():
    orc, troll = load("Orc"), load("Troll")
    orc_route, troll_route = lua_list(orc.StoryRoute), lua_list(troll.StoryRoute)
    assert orc_route[0] == troll_route[0] == 4641  # one starter for both races
    assert set(orc_route) < set(troll_route)  # Troll walks every Orc quest and more
    assert [q for q in troll_route if q in set(orc_route)] == orc_route
    echo = {q.id for c in lua_list(troll.Chains) if c.id == "echo_isles" for q in lua_list(c.quests)}
    assert echo and echo <= set(troll_route) and not echo & set(orc_route)
    assert "echo_isles" not in view(orc)  # the Echo Isles chain is Troll only
    trials = {q.id for c in lua_list(orc.Chains) if c.id == "trials" for q in lua_list(c.quests)}
    assert max(troll_route.index(q) for q in trials) < min(troll_route.index(q) for q in echo)
    assert not {65, 6502} & (set(orc_route) | set(troll_route))  # no Alliance spine


def test_horde_spine_joins_each_saga_at_its_anchor():
    """Issue #18: every Horde route ends its own quests with its anchor (Conscript
    of the Horde, Journey to the Crossroads, Sample for Helbrim), then walks the same
    spine from Disrupt the Attacks to Stranglethorn Vale."""
    tails = {}
    for key, anchor in ANCHORS.items():
        ns = load(key)
        route = lua_list(ns.StoryRoute)
        start = route.index(SPINE_START)
        assert route[start - 1] == anchor, key
        tails[key] = route[start:]
        assert not {65, 6502} & set(route)  # no Alliance spine
        groups = {c.id: ns.ChainGroup(c, key) for c in lua_list(ns.Chains)}
        want = "race" if key == "Orc" else "shared"
        assert {groups[c] for c in HORDE_SPINE} == {want}, key
        if key == "Orc":
            spine_quests = {x.id for c in lua_list(ns.AllChains) if c.id in HORDE_SPINE
                            for x in lua_list(c.quests)}
    assert len({tuple(t) for t in tails.values()}) == 1  # one spine, one order
    assert set(tails["Orc"]) == spine_quests


def test_horde_spine_runs_from_the_barrens_to_level_60():
    """The spine now holds the chains of level 18 to 60. Every route ends on the
    last Eastern Plaguelands quest, and the shared tail has no Barrens-to-Stranglethorn
    link quest because no source gives one (see the CHANGELOG)."""
    ends, levels = set(), []
    for key in HORDE:
        route = lua_list(load(key).StoryRoute)
        ends.add(route[-1])
        tail = route[route.index(SPINE_START):]
        levels += [FACTS[q]["requiredLevel"] for q in tail if q in FACTS]
        for anchor in (6382, 1145, 655, 3121, 5228, 6148):
            assert anchor in tail, (key, anchor)
    assert ends == {6148}
    assert max(levels) >= 56 and 17 in levels


def test_shared_horde_lists_every_spine_chain():
    """Shared_Horde.lua shares exactly the chains of tools/sagas/horde_spine.json."""
    ns = load("Troll")
    shared = {c.id for c in lua_list(ns.AllChains) if ns.SharedChains[c.id]}
    assert set(HORDE_SPINE) <= shared
    for chain in HORDE_SPINE:
        sagas = ns.SharedChains[chain].sagas
        assert {k for k in ("Troll", "Tauren", "Scourge", "Orc") if sagas[k]} == {"Troll", "Tauren", "Scourge"}


def test_own_horde_routes_stay_in_their_zones():
    tauren, orc = load("Tauren"), load("Orc")
    route = own_route("Tauren")
    assert route[0] == 747 and route[-1] == 854
    assert not set(route) & set(lua_list(orc.StoryRoute))  # no Durotar quest
    pos = {q: i for i, q in enumerate(route)}
    assert pos[773] == pos[772] + 1  # Seer Wiserunner ends 772 and gives 773
    # 854 is the only own quest that starts outside Mulgore and Thunder Bluff.
    maps = {q.id: q.map for c in lua_list(tauren.Chains) for q in lua_list(c.quests)}
    assert [q for q in route if maps[q] == 1413] == [854]
    forsaken = own_route("Scourge")
    assert forsaken[0] == 363 and forsaken[-1] == 1358
    assert not set(forsaken) & (set(own_route("Tauren")) | set(own_route("Orc")))


def test_view_follows_the_route():
    # Own and shared chains are in route order for a saga that shares, so
    # a level-1 character's first eligible chain is the starter, and the
    # Human spine (Defias, level 14) never comes before a race chain the
    # route takes first (Dwarf A Dark Threat Looms, level 16).
    for key, starter in STARTER.items():
        ns = load(key)
        pos = {q: i for i, q in enumerate(lua_list(ns.StoryRoute))}
        ids = [c.id for c in lua_list(ns.Chains)]
        assert ids[0] == starter, (key, ids)
        first = [min(pos[q.id] for q in lua_list(c.quests) if q.id in pos)
                 for c in lua_list(ns.Chains) if c.id in NEW_CHAINS[key] + SHARED[key]]
        assert first == sorted(first), (key, ids)


def test_objective_counts_agree_between_questie_and_pandabase():
    """Issue #53: the guide shows one count for each quest. Questie and
    PandaBase must give the same numbers in every saga snapshot, or the
    difference is in accepted_mismatches.json with a written reason."""
    import verify_pandabase as vp
    accepted = vp.load_accepted(SAGAS / "accepted_mismatches.json")
    problems = []
    for path in sorted(SAGAS.glob("*.facts.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        pages = doc["pandabase_pages"]
        for q in doc["quests"]:
            page = pages.get(str(q["id"]))
            if not page or q.get("source") == "pandabase":
                continue
            a = vp.objective_counts(" ".join(q.get("objectivesText") or []))
            b = vp.objective_counts(page.get("objective"))
            if a and b and a != b and not vp.is_accepted(accepted, q["id"], "counts", sorted(a), sorted(b)):
                problems.append(f"{path.name} {q['id']} {q['name']}: Questie {sorted(a)}, PandaBase {sorted(b)}")
    assert problems == []


def test_class_audit_no_route_quest_is_class_gated(saga):
    _, _, route = saga
    gated = [q for q in route if q in FACTS and (FACTS[q]["classes"] or (PAGES.get(q) or {}).get("classes"))]
    assert gated == []


def test_route_quests_are_open_to_the_race(saga):
    key, _, route = saga
    closed = [q for q in route if q in FACTS and FACTS[q]["races"] and RACE_LABEL[key] not in FACTS[q]["races"]]
    assert closed == []


def test_neutral_chains_are_visible_to_every_saga():
    # Issue #19: Tirion Fordring, Pamela Redpath and Linken are MAIN chains for
    # both factions, in the neutral chooser group and on no race route.
    assert NEUTRAL_CHAINS == ["tirion_fordring", "pamela_redpath", "linken"]
    expected = {c["id"]: [q["id"] for q in c["quests"]] for c in NEUTRAL_SPEC["chains"]}
    for key in NEW_CHAINS:
        ns = load(key)
        ids = view(ns)
        route = set(lua_list(ns.StoryRoute))
        for chain in lua_list(ns.AllChains):
            if chain.id in NEUTRAL_CHAINS:
                assert chain.race == "Neutral"
                assert ns.ChainGroup(chain, key) == "neutral", (key, chain.id)
                assert ids[chain.id] == expected[chain.id]
                assert not route & set(ids[chain.id]), (key, chain.id)
        assert set(NEUTRAL_CHAINS) <= set(ids), key


def test_neutral_quests_are_open_to_both_factions():
    doc = json.loads((SAGAS / "neutral.facts.json").read_text(encoding="utf-8"))
    ids = {q["id"] for c in NEUTRAL_SPEC["chains"] for q in c["quests"]}
    assert ids == {q["id"] for q in doc["quests"]}
    for q in doc["quests"]:
        assert q["races"] == [] and q["classes"] == [], q["id"]
    for page in doc["pandabase_pages"].values():
        assert page["faction"] == "Alliance and Horde", page["id"]


def test_coda_chains_are_visible_to_the_right_faction_only():
    # Issue #20: dungeon codas and reputations are Neutral MAIN chains, on no race route. A chain
    # with a faction shows for that faction's sagas only.
    assert len(CODA_CHAINS) == 56  # issue #22 adds Molten Core and Blackwing Lair; issue #23 adds Zul'Gurub, Zandalar Tribe and Ahn'Qiraj; issue #24 adds 4 Naxxramas and Plaguelands chains
    expected = {c["id"]: [q["id"] for q in c["quests"]] for c in CODA_CHAINS}
    for key in NEW_CHAINS:
        ns = load(key)
        ids = view(ns)
        route = set(lua_list(ns.StoryRoute))
        assert [c for c in expected if c in ids] == coda_ids(key), key
        for chain in lua_list(ns.AllChains):
            if chain.id in expected:
                assert chain.race == "Neutral"
                assert (ns.ChainGroup(chain, key) == "neutral") == (chain.id in coda_ids(key)), (key, chain.id)
        for cid in coda_ids(key):
            assert ids[cid] == expected[cid]
            assert not route & set(ids[cid]), (key, cid)


def test_coda_quests_fit_the_faction_of_their_chain():
    for name, spec in CODA_SPECS.items():
        doc = json.loads((SAGAS / f"{name}.facts.json").read_text(encoding="utf-8"))
        facts = {q["id"]: q for q in doc["quests"]}
        assert set(facts) == {q["id"] for c in spec["chains"] for q in c["quests"]}
        for chain in spec["chains"]:
            for q in chain["quests"]:
                f = facts[q["id"]]
                assert f["classes"] == [] or q["id"] in ARMOR_TOKEN_IDS, q["id"]  # issue #69
                assert not f["specialFlags"] & 1, q["id"]  # no repeatable quest
                races = set(f["races"])
                if "faction" not in chain:
                    assert races == set(), (chain["id"], q["id"])
                else:  # open to the faction's races, or to all races when it needs a faction quest
                    assert races <= ({"Human", "Dwarf", "Night Elf", "Gnome", "Skyborne (Alliance)"}
                                               if chain["faction"] == "Alliance" else
                                               {"Orc", "Undead", "Tauren", "Troll", "Skyborne (Horde)"}), q["id"]


def test_coda_quests_belong_to_one_chain_in_the_whole_guide():
    seen = {}
    for path in sorted(SAGAS.glob("*.json")):
        if path.name.endswith((".facts.json", ".manual.json")) or path.name == "accepted_mismatches.json":
            continue
        spec = json.loads(path.read_text(encoding="utf-8"))
        for chain in spec.get("chains", []):  # side-zone specs and the audit hold no chains
            for q in chain["quests"]:
                if path.stem in CODA_SPECS or q["id"] not in seen:
                    seen.setdefault(q["id"], []).append((path.stem, chain["id"]))
    assert {qid: where for qid, where in seen.items() if len(where) > 1} == {}


def test_coda_zones_are_places_not_pandabase_placeholders():
    for name in ("Data_Dungeons.lua", "Data_Reputations.lua", "Data_Raids.lua", "Data_ZGAQ.lua", "Data_Naxx.lua"):
        text = (ADDON / name).read_text(encoding="utf-8")
        assert "Referenced" not in text and "Synthetic" not in text, name


def test_journal_covers_new_chains():
    ns = load("Dwarf")
    entries, epilogues = ns.JournalEntries, ns.JournalEpilogues
    missing = []
    for chain in lua_list(ns.AllChains):
        if chain.id in ALL_NEW_CHAINS | set(NEUTRAL_CHAINS) | {c["id"] for c in CODA_CHAINS}:
            if not epilogues[chain.id]:
                missing.append(f"epilogue {chain.id}")
            for q in lua_list(chain.quests):
                e = entries[q.id]
                if not (e and e.title and e.body):
                    missing.append(f"entry {q.id}")
    assert missing == []


def test_points_are_on_known_maps():
    ns = load("Dwarf")
    for chain in lua_list(ns.AllChains):
        if chain.race in NEW_CHAINS:
            for q in lua_list(chain.quests):
                if q.x is not None:
                    assert q.map in SAGA_MAPS[chain.race], (chain.race, q.id, q.map)
                    assert 0 < q.x < 100 and 0 < q.y < 100
