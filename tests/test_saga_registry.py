"""Saga registry + race auto-detect guard (E1 / 1.1).

These tests run the real MainStoryGuide/Sagas.lua in a Lua 5.1 runtime
(lupa.lua51, the same Lua version as the WoW client). WoW API calls are
stubbed. The chain data is a small test fixture, not addon data: the
"Gnome" chain here only proves that two sagas co-exist in the registry.
Real Gnome content comes in E2.
"""
from __future__ import annotations

import itertools
import json
import pathlib
import re

import pytest

lua51 = pytest.importorskip("lupa.lua51")

ADDON = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide"
SAGAS_SRC = (ADDON / "Sagas.lua").read_text(encoding="utf-8")
CORE_SRC = (ADDON / "Core.lua").read_text(encoding="utf-8")

# UnitRace("player") second return value (the English race file token) for
# every Classic-era playable race. The registry keys must be these tokens,
# or auto-detect can never match them.
CLASSIC_RACE_TOKENS = {
    "Human", "Dwarf", "Gnome", "NightElf",
    "Orc", "Troll", "Tauren", "Scourge",
}

# Lua harness. It loads Sagas.lua the way the client does (addon name and
# a private namespace table as the chunk varargs) and adds the small part
# of Core.lua that Sagas.lua calls (ns.PlayerFaction).
HARNESS = r"""
return function(src, race, faction, withGnome, forced, localized)
  if race then
    -- Real client order: localized name first, English file token second.
    -- The two differ on purpose so a test fails if Sagas.lua reads the
    -- localized name instead of the token.
    UnitRace = function(unit) return localized or ("L10N " .. race), race end
  else
    UnitRace = nil
  end
  if faction then
    UnitFactionGroup = function(unit) return faction, faction end
  else
    UnitFactionGroup = nil
  end

  local ns = {}
  local chunk = assert(loadstring(src, "@Sagas.lua"))
  chunk("MainStoryGuide", ns)

  ns.PlayerFaction = function()
    if UnitFactionGroup then
      local ok, f = pcall(UnitFactionGroup, "player")
      if ok then return f end
    end
    return nil
  end
  ns.calls = { BuildIndex = 0, Refresh = 0 }
  ns.BuildIndex = function() ns.calls.BuildIndex = ns.calls.BuildIndex + 1 end
  ns.Refresh = function() ns.calls.Refresh = ns.calls.Refresh + 1 end

  ns.cdb = { forcedSaga = forced }

  local list = {
    { id = "human_a", race = "Human", quests = { { id = 1 }, { id = 2 } } },
    { id = "neutral_a", race = "Neutral", quests = { { id = 20 } } },
    { id = "forever_a", race = "Human", optional = true,
      quests = { { id = 30 } } },
  }
  if withGnome then
    list[#list + 1] = { id = "gnome_a", race = "Gnome",
                        quests = { { id = 10 } } }
  end
  ns.RegisterChains(list)
  ns.RegisterRoute("Human", { 1, 2 })
  if withGnome then ns.RegisterRoute("Gnome", { 10 }) end

  ns.viewIds = function()
    local out = {}
    for i, c in ipairs(ns.Chains) do out[i] = c.id end
    return table.concat(out, ",")
  end
  return ns
end
"""


class Env:
    """One fresh Lua state with Sagas.lua loaded."""

    def __init__(self, race="Human", faction="Alliance", gnome=False, forced=None,
                 localized=None):
        self.lua = lua51.LuaRuntime(unpack_returned_tuples=True)
        setup = self.lua.execute(HARNESS)
        self.ns = setup(SAGAS_SRC, race, faction, gnome, forced, localized)

    def active(self):
        return self.ns.GetActiveSaga()

    def view(self):
        return self.ns.viewIds().split(",") if self.ns.viewIds() else []

    def route(self):
        t = self.ns.StoryRoute
        return [t[i] for i in range(1, len(t) + 1)]

    def same_table(self, a, b):
        return self.lua.eval("function(a, b) return rawequal(a, b) end")(a, b)

    def set_saga(self, key):
        return self.ns.SetActiveSaga(key)

    @property
    def forced(self):
        return self.ns.cdb.forcedSaga


# ------------------------------------------------------------------
# Registry
# ------------------------------------------------------------------

def test_registry_keys_are_unitrace_tokens():
    env = Env()
    order = env.ns.SagaOrder
    keys = [order[i] for i in range(1, len(order) + 1)]
    assert set(keys) == CLASSIC_RACE_TOKENS
    for key in keys:
        entry = env.ns.Sagas[key]
        assert entry.key == key
        assert entry.faction in ("Alliance", "Horde")
        assert entry.icon.startswith("Interface\\Icons\\")


def test_registry_factions_match_races():
    env = Env()
    alliance = {"Human", "Dwarf", "Gnome", "NightElf"}
    for key in CLASSIC_RACE_TOKENS:
        want = "Alliance" if key in alliance else "Horde"
        assert env.ns.Sagas[key].faction == want, key


def test_saga_has_data_needs_a_non_optional_race_chain():
    env = Env(gnome=True)
    assert env.ns.SagaHasData("Human")
    assert env.ns.SagaHasData("Gnome")
    assert not env.ns.SagaHasData("Dwarf")
    assert not env.ns.SagaHasData("Neutral")  # not a registry key
    assert not env.ns.SagaHasData(None)


def test_registering_a_chain_twice_keeps_one_copy():
    env = Env()
    before = len(env.ns.AllChains)
    # Pass a copy: if dedup broke, looping over AllChains itself while
    # appending to it would never end.
    copy = env.lua.eval("function(t) local c = {} for i, v in ipairs(t) do c[i] = v end return c end")
    env.ns.RegisterChains(copy(env.ns.AllChains))
    assert len(env.ns.AllChains) == before


# ------------------------------------------------------------------
# Race auto-detect
# ------------------------------------------------------------------

def test_human_character_gets_human_saga():
    env = Env(race="Human")
    assert env.active() == "Human"
    assert env.ns.ActiveSaga == "Human"
    assert env.view() == ["human_a", "neutral_a", "forever_a"]
    assert env.route() == [1, 2]


def test_gnome_character_gets_gnome_saga_when_data_exists():
    env = Env(race="Gnome", gnome=True)
    assert env.active() == "Gnome"
    # Own race first, then neutral, then optional Forever. No Human chain.
    assert env.view() == ["gnome_a", "neutral_a", "forever_a"]
    assert env.route() == [10]


def test_human_and_gnome_sagas_coexist():
    human = Env(race="Human", gnome=True)
    gnome = Env(race="Gnome", gnome=True)
    assert "gnome_a" not in human.view()
    assert "human_a" not in gnome.view()
    assert "neutral_a" in human.view() and "neutral_a" in gnome.view()


@pytest.mark.parametrize("race", ["Gnome", "Dwarf", "BloodElf", "Draenei", "Pandaren"])
def test_race_without_saga_data_falls_back_to_human(race):
    env = Env(race=race)
    assert env.active() == "Human"
    assert env.view()[0] == "human_a"


def test_auto_detect_reads_the_race_token_not_the_localized_name():
    # The Undead token is "Scourge" while the English name is "Undead".
    env = Env(race="Scourge", localized="Undead", faction="Horde")
    env.ns.RegisterChains(env.lua.eval(
        '{ { id = "scourge_a", race = "Scourge", quests = { { id = 40 } } } }'))
    assert env.active() == "Scourge"
    assert env.view()[0] == "scourge_a"
    assert env.ns.IsSagaReadOnly() is False


def test_missing_unitrace_api_falls_back_to_human():
    env = Env(race=None, faction=None)
    assert env.active() == "Human"


def test_horde_race_without_data_sees_human_saga_read_only():
    # No Horde saga has data yet, so a Horde character falls back to Human.
    # The faction differs, so the view is browse-only (no waypoints).
    env = Env(race="Orc", faction="Horde")
    assert env.active() == "Human"
    assert env.ns.IsSagaReadOnly() is True


def test_read_only_only_across_factions():
    env = Env(race="Human", faction="Alliance", gnome=True)
    assert env.ns.IsSagaReadOnly("Human") is False
    assert env.ns.IsSagaReadOnly("Gnome") is False
    assert env.ns.IsSagaReadOnly("Orc") is True
    # Unknown player faction (API absent) never makes a saga read-only.
    env = Env(race="Human", faction=None)
    assert env.ns.IsSagaReadOnly("Orc") is False


# ------------------------------------------------------------------
# Forced saga (alts / previews) and switching
# ------------------------------------------------------------------

def test_forced_saga_wins_when_it_has_data():
    env = Env(race="Human", gnome=True, forced="Gnome")
    assert env.active() == "Gnome"
    assert env.view()[0] == "gnome_a"


@pytest.mark.parametrize("forced", ["Dwarf", "Bogus", "Neutral"])
def test_stale_forced_saga_is_ignored(forced):
    env = Env(race="Human", gnome=True, forced=forced)
    assert env.active() == "Human"


def test_switch_to_other_saga_and_back():
    env = Env(race="Human", gnome=True)
    chains = env.ns.Chains
    assert env.set_saga("Gnome") is True
    assert env.forced == "Gnome"
    assert env.active() == "Gnome"
    assert env.view() == ["gnome_a", "neutral_a", "forever_a"]
    assert env.route() == [10]
    # The view is rebuilt in place, so consumers that hold ns.Chains see it.
    assert env.same_table(env.ns.Chains, chains)
    assert env.ns.calls.BuildIndex == 1 and env.ns.calls.Refresh == 1

    assert env.set_saga(None) is True  # "/story saga auto"
    assert env.forced is None
    assert env.active() == "Human"
    assert env.view()[0] == "human_a"


def test_choosing_own_saga_clears_the_override():
    env = Env(race="Gnome", gnome=True, forced="Human")
    assert env.active() == "Human"
    assert env.set_saga("Gnome") is True
    assert env.forced is None
    assert env.active() == "Gnome"


@pytest.mark.parametrize("key", ["Dwarf", "Orc", "Bogus"])
def test_switch_to_saga_without_data_is_refused(key):
    env = Env(race="Human", gnome=True)
    assert env.set_saga(key) is False
    assert env.forced is None
    assert env.active() == "Human"
    assert env.ns.calls.BuildIndex == 0


def test_switch_without_saved_variables_is_refused():
    env = Env(race="Human", gnome=True)
    env.ns.cdb = None
    assert env.set_saga("Gnome") is False


def test_forced_chain_not_in_new_view_is_cleared():
    env = Env(race="Human", gnome=True)
    env.ns.cdb.forcedChain = "human_a"
    env.set_saga("Gnome")
    assert env.ns.cdb.forcedChain is None
    env.ns.cdb.forcedChain = "neutral_a"  # visible in both sagas
    env.set_saga(None)
    assert env.ns.cdb.forcedChain == "neutral_a"


def test_late_unitrace_is_picked_up_on_rebuild():
    # UnitRace can be unset at ADDON_LOADED. A later RebuildView must
    # resolve the real race (Core.lua does this at PLAYER_LOGIN).
    env = Env(race=None, gnome=True)
    assert env.active() == "Human"
    env.lua.execute('UnitRace = function() return "Gnomo", "Gnome" end')
    assert env.ns.RebuildView() == "Gnome"
    assert env.view()[0] == "gnome_a"


# ------------------------------------------------------------------
# The neutral MAIN chains sit among the route chains by required level (issue #57).
# The other neutral chains (dungeon, reputation and raid chains) stay after the route.
# ------------------------------------------------------------------

MAIN_NEUTRAL = ["tirion_fordring", "pamela_redpath", "linken"]  # the issue #19 chains


def _register(env, *chains):
    env.ns.RegisterChains(env.lua.table_from(
        [env.lua.table_from(c, recursive=True) for c in chains]))


def _level_env(linken=47):
    """Human saga with route chains human_a, a1, b20 (level 20) and c60 (level 60).

    Main neutral chains: linken (default level 47, no minLevel for None), then
    tirion_fordring and pamela_redpath (both level 60). tirion_fordring is registered
    first, so alphabetical order and registration order differ.
    Other neutral chains: neutral_a (no level, from the harness), dungeon_z (level 10) and
    dungeon_a (level 5). They have a low level on purpose, and stay after the route.
    One Forever chain.

    human_a, a1 and neutral_a have no minLevel. A missing level counts as 1."""
    env = Env(race="Human")
    linken_chain = {"id": "linken", "race": "Neutral", "quests": {1: {"id": 202}}}
    if linken is not None:
        linken_chain["minLevel"] = linken
    chains = [
        {"id": "a1", "race": "Human", "quests": {1: {"id": 101}}},
        {"id": "b20", "race": "Human", "minLevel": 20, "quests": {1: {"id": 102}}},
        {"id": "c60", "race": "Human", "minLevel": 60, "quests": {1: {"id": 103}}},
        {"id": "dungeon_z", "race": "Neutral", "minLevel": 10, "quests": {1: {"id": 201}}},
        {"id": "tirion_fordring", "race": "Neutral", "minLevel": 60, "quests": {1: {"id": 203}}},
        {"id": "dungeon_a", "race": "Neutral", "minLevel": 5, "quests": {1: {"id": 206}}},
        {"id": "pamela_redpath", "race": "Neutral", "minLevel": 60, "quests": {1: {"id": 204}}},
        linken_chain,
    ]
    _register(env, *chains)
    env.ns.RegisterRoute("Human", env.lua.table_from([1, 2, 101, 102, 103]))
    return env


def test_level_ordered_chains_are_the_neutral_main_chains():
    """Sagas.lua names the chains that sit among the route by level. The list and
    neutral.json (issue #19) must name the same chains: a new main chain in neutral.json
    fails here, so the author must decide where it sits."""
    spec = json.loads((ADDON.parent / "tools" / "sagas" / "neutral.json").read_text(encoding="utf-8"))
    block = re.search(r"local LEVEL_ORDERED = \{(.*?)\}", SAGAS_SRC, re.S)
    assert block, "Sagas.lua has no LEVEL_ORDERED list"
    in_lua = re.findall(r"(\w+)\s*=\s*true", block.group(1))
    assert sorted(in_lua) == sorted(c["id"] for c in spec["chains"]) == sorted(MAIN_NEUTRAL)


def test_main_neutral_chains_sort_by_level_among_route_chains():
    view = _level_env().view()
    route = [c for c in view if c in ("human_a", "a1", "b20", "c60")]
    assert route == ["human_a", "a1", "b20", "c60"]  # route order is kept
    # A level 47 chain comes after the level 20 route chain and before the
    # level 60 route chain (the issue #57 case).
    assert view.index("b20") < view.index("linken") < view.index("c60")


def test_main_neutral_chain_of_equal_level_follows_the_route_chain():
    view = _level_env().view()
    assert view.index("c60") < view.index("tirion_fordring")
    assert view.index("c60") < view.index("pamela_redpath")


def test_main_neutral_chains_of_equal_level_keep_registration_order():
    view = _level_env().view()
    # tirion_fordring was registered first. Alphabetical order would put pamela_redpath first.
    assert view.index("tirion_fordring") < view.index("pamela_redpath")


def test_main_neutral_chain_without_level_counts_as_level_1():
    view = _level_env(linken=None).view()
    # Level 1 is not below the level 1 of a1 (no level): linken follows a1, and
    # comes before the level 20 route chain.
    assert view.index("a1") < view.index("linken") < view.index("b20")


def test_main_neutral_chain_never_precedes_the_first_route_chain():
    view = _level_env(linken=0).view()
    assert view[0] == "human_a"  # a new character still starts on the route
    # Level 0 is below the level 1 of a1 (no level), so linken comes right after the first chain.
    assert view.index("human_a") < view.index("linken") < view.index("a1")


def test_other_neutral_chains_stay_after_the_route_in_registration_order():
    view = _level_env().view()
    others = ["neutral_a", "dungeon_z", "dungeon_a"]  # registration order, not level order
    # Level 5 and level 10 chains do not move in among the route chains.
    behind = ["human_a", "a1", "b20", "c60", *MAIN_NEUTRAL]
    assert max(view.index(c) for c in behind) < min(view.index(c) for c in others)
    assert [c for c in view if c in others] == others


def test_forever_chains_stay_last():
    view = _level_env().view()
    assert view[-1] == "forever_a"
    assert view.index("dungeon_a") < view.index("forever_a")


def test_neutral_order_is_stable_across_rebuilds():
    env = _level_env()
    first = env.view()
    for _ in range(3):
        env.ns.RebuildView()
        assert env.view() == first


# ------------------------------------------------------------------
# Chain order by prerequisite data: the chain key `after` (issue #74)
# ------------------------------------------------------------------

_LATE_QUEST_IDS = itertools.count(1000)


def _late(cid, *after, race="Neutral", **extra):
    chain = {"id": cid, "race": race, "minLevel": 60, "quests": {1: {"id": next(_LATE_QUEST_IDS)}}}
    if after:
        chain["after"] = {i + 1: a for i, a in enumerate(after)}
    chain.update(extra)
    return chain


def _late_view(*chains):
    """The view of a Human saga that has the _level_env chains and these other neutral chains."""
    env = _level_env()
    base = env.view()
    _register(env, *chains)
    env.ns.RebuildView()
    return env, base, env.view()


def test_after_puts_a_chain_behind_the_chains_it_names():
    env, _, view = _late_view(_late("raid_b", "raid_a"), _late("raid_a"), _late("raid_c"))
    late = [c for c in view if c.startswith("raid_")]
    assert late == ["raid_a", "raid_b", "raid_c"]  # raid_b waits for raid_a, raid_c keeps its place


def test_after_keeps_the_order_of_the_chains_that_it_does_not_touch():
    _, base, view = _late_view(_late("raid_b", "raid_a"), _late("raid_a"), _late("raid_c"))
    assert [c for c in view if not c.startswith("raid_")] == base  # route, main and other chains stay


def test_after_waits_for_a_chain_that_registers_later_than_its_neighbours():
    _, _, view = _late_view(_late("raid_b", "raid_d"), _late("raid_c"), _late("raid_d"))
    late = [c for c in view if c.startswith("raid_")]
    assert late == ["raid_c", "raid_d", "raid_b"]


def test_after_waits_for_all_the_chains_it_names():
    _, _, view = _late_view(_late("raid_x", "raid_y", "raid_z"), _late("raid_z"), _late("raid_y"))
    late = [c for c in view if c.startswith("raid_")]
    assert late == ["raid_z", "raid_y", "raid_x"]


def test_after_ignores_a_chain_that_the_view_does_not_hold():
    # A Horde-only chain is not in a Human view; a chain that nobody registered is not there at all.
    env = Env(race="Human")
    _register(env, _late("raid_b", "raid_a", "never_registered"),
              _late("raid_a", faction="Horde"), _late("raid_c"))
    env.ns.RebuildView()
    late = [c for c in env.view() if c.startswith("raid_")]
    assert late == ["raid_b", "raid_c"]


def test_after_cycle_keeps_every_chain_once_and_does_not_hang():
    env, _, view = _late_view(_late("cyc_x", "cyc_y"), _late("cyc_y", "cyc_x"), _late("cyc_z", "cyc_z"))
    assert sorted(c for c in view if c.startswith("cyc_")) == ["cyc_x", "cyc_y", "cyc_z"]
    assert len(view) == len(set(view))
    for _ in range(3):  # a rebuild gives the same view
        env.ns.RebuildView()
        assert env.view() == view


def test_after_of_a_main_chain_does_not_move_it_out_of_level_order():
    # `after` orders the other neutral chains only: a main chain keeps its level place.
    env = Env(race="Human")
    _register(env, {"id": "linken", "race": "Neutral", "minLevel": 47, "after": {1: "raid_a"},
                    "quests": {1: {"id": 202}}}, _late("raid_a"),
              {"id": "c60", "race": "Human", "minLevel": 60, "quests": {1: {"id": 103}}})
    env.ns.RegisterRoute("Human", env.lua.table_from([1, 2, 103]))
    env.ns.RebuildView()
    view = env.view()
    assert view.index("linken") < view.index("c60") < view.index("raid_a")


# ------------------------------------------------------------------
# Core.lua wiring (text check: Core.lua needs the full WoW UI to run)
# ------------------------------------------------------------------

def test_player_login_resolves_the_saga_again():
    m = re.search(r'elseif event == "PLAYER_LOGIN" then(.*?)\n  elseif', CORE_SRC, re.S)
    assert m, "PLAYER_LOGIN branch not found in Core.lua"
    body = m.group(1)
    assert "ns.GetActiveSaga() ~= ns.ActiveSaga" in body
    assert "BuildIndex()" in body
