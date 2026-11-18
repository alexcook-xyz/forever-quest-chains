"""Per-saga isolation + neutral chains guard (E1 / 1.2).

These tests run the real MainStoryGuide/Sagas.lua and Journal.lua in a
Lua 5.1 runtime (lupa.lua51, the same Lua version as the WoW client).
WoW API calls and the few Core.lua helpers that Journal.lua calls are
stubbed. The chains are a small test fixture, not addon data: the Gnome
and Orc chains only prove that sagas stay apart. Real Gnome and Horde
content comes in E2 / E3.

What is checked:
- route isolation: a saga's route and chain view hold only its own race
  chains plus shared, neutral and Forever chains;
- journal isolation: pages are counted, seeded and announced only for
  chains in the active view, and locked pages stay blind;
- shared chains: the sharing saga gets a trimmed copy, the owner keeps
  the original, and the copy is never registered as a chain;
- neutral chains: claimable by both factions unless authored with a
  faction;
- a pinned chain (cdb.forcedChain) survives a rebuild while UnitRace is
  still empty (issue #11 comment);
- the journal first-run seed waits until the saga is known, so a seed
  on the Human fallback view does not leave the real saga unseeded
  (issue #37).
"""
from __future__ import annotations

import pathlib

import pytest

lua51 = pytest.importorskip("lupa.lua51")

ADDON = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide"
SAGAS_SRC = (ADDON / "Sagas.lua").read_text(encoding="utf-8")
JOURNAL_SRC = (ADDON / "Journal.lua").read_text(encoding="utf-8")

# Quest IDs per fixture chain. Kept in Python too, so tests can compare
# a view against the IDs of every other saga.
CHAIN_QUESTS = {
    "human_a": [1, 2],
    "gnome_a": [10, 11],
    "orc_a": [50],
    "neutral_a": [20],
    "neutral_norace": [23],
    "neutral_alliance": [21],
    "neutral_horde": [22],
    "forever_a": [30],
}
RACE_CHAINS = {"Human": "human_a", "Gnome": "gnome_a", "Orc": "orc_a"}
ROUTES = {"Human": [1, 2], "Gnome": [10, 11], "Orc": [50]}

HARNESS = r"""
return function(sagasSrc, journalSrc, race, faction, opts)
  opts = opts or {}
  if race == "" then
    UnitRace = function() return "", "" end
  elseif race then
    UnitRace = function() return "L10N " .. race, race end
  else
    UnitRace = nil
  end
  if faction then
    UnitFactionGroup = function() return faction, faction end
  else
    UnitFactionGroup = nil
  end

  local ns = {}
  assert(loadstring(sagasSrc, "@Sagas.lua"))("MainStoryGuide", ns)

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
  ns.cdb = { forcedSaga = opts.forced, forcedChain = opts.pin,
             journalSeen = {}, journalAnnounced = {} }

  -- Core.lua helpers Journal.lua calls: completion is a plain set.
  ns.done = {}
  ns.IsCompleted = function(id) return id and ns.done[id] and true or false end
  ns.EffectiveQuests = function(chain) return chain.quests or {} end
  ns.ResolveChain = function(chain)
    for _, q in ipairs(chain.quests or {}) do
      if not ns.done[q.id] then return { chain = chain, state = "AVAILABLE" } end
    end
    return { chain = chain, state = "DONE" }
  end
  ns.printed = {}
  ns.Print = function(msg) ns.printed[#ns.printed + 1] = msg end
  assert(loadstring(journalSrc, "@Journal.lua"))("MainStoryGuide", ns)

  if opts.share then
    ns.SharedChains.human_a = { sagas = { Gnome = true }, skip = { [1] = true } }
  end

  local function Q(...)
    local t = {}
    for i, id in ipairs({ ... }) do t[i] = { id = id, name = "Quest " .. id } end
    return t
  end
  ns.RegisterChains({
    { id = "human_a", name = "Human A", race = "Human", quests = Q(1, 2) },
    { id = "gnome_a", name = "Gnome A", race = "Gnome", quests = Q(10, 11) },
    { id = "orc_a", name = "Orc A", race = "Orc", quests = Q(50) },
    { id = "neutral_a", name = "Neutral A", race = "Neutral", quests = Q(20) },
    { id = "neutral_norace", name = "Neutral B", quests = Q(23) },
    { id = "neutral_alliance", name = "Neutral C", race = "Neutral",
      faction = "Alliance", quests = Q(21) },
    { id = "neutral_horde", name = "Neutral D", race = "Neutral",
      faction = "Horde", quests = Q(22) },
    { id = "forever_a", name = "Forever A", race = "Human", optional = true,
      quests = Q(30) },
  })
  ns.RegisterRoute("Human", { 1, 2 })
  ns.RegisterRoute("Gnome", { 10, 11 })
  ns.RegisterRoute("Orc", { 50 })

  ns.viewIds = function()
    local out = {}
    for i, c in ipairs(ns.Chains) do out[i] = c.id end
    return table.concat(out, ",")
  end
  ns.chainById = function(id)
    for _, c in ipairs(ns.Chains) do if c.id == id then return c end end
    return nil
  end
  ns.questIds = function(chain)
    local out = {}
    for i, q in ipairs(chain.quests or {}) do out[i] = tostring(q.id) end
    return table.concat(out, ",")
  end
  ns.complete = function(...)
    for _, id in ipairs({ ... }) do ns.done[id] = true end
  end
  ns.setRace = function(r)
    UnitRace = function() return "L10N " .. r, r end
  end
  return ns
end
"""


class Env:
    """One fresh Lua state with Sagas.lua and Journal.lua loaded."""

    def __init__(self, race="Human", faction="Alliance", forced=None, pin=None,
                 share=False):
        self.lua = lua51.LuaRuntime(unpack_returned_tuples=True)
        setup = self.lua.execute(HARNESS)
        opts = self.lua.table_from({"forced": forced, "pin": pin, "share": share})
        self.ns = setup(SAGAS_SRC, JOURNAL_SRC, race, faction, opts)

    def view(self):
        ids = self.ns.viewIds()
        return ids.split(",") if ids else []

    def route(self):
        t = self.ns.StoryRoute
        return [t[i] for i in range(1, len(t) + 1)]

    def chain(self, chain_id):
        return self.ns.chainById(chain_id)

    def quests(self, chain_id):
        ids = self.ns.questIds(self.chain(chain_id))
        return [int(x) for x in ids.split(",")] if ids else []

    def complete(self, *ids):
        self.ns.complete(*ids)

    def keys(self, table_name):
        t = self.ns.cdb[table_name]
        return {k for k in t.keys()}

    def printed(self):
        t = self.ns.printed
        return [t[i] for i in range(1, len(t) + 1)]

    def same_table(self, a, b):
        return self.lua.eval("function(a, b) return rawequal(a, b) end")(a, b)


def other_saga_quests(saga):
    out = set()
    for key, chain_id in RACE_CHAINS.items():
        if key != saga:
            out.update(CHAIN_QUESTS[chain_id])
    return out


# Each playable fixture saga with a character of that race.
SAGA_CHARS = [("Human", "Alliance"), ("Gnome", "Alliance"), ("Orc", "Horde")]


# ------------------------------------------------------------------
# Route isolation
# ------------------------------------------------------------------

@pytest.mark.parametrize("race,faction", SAGA_CHARS)
def test_route_holds_only_own_saga_quests(race, faction):
    env = Env(race=race, faction=faction)
    assert env.ns.ActiveSaga == race
    assert env.route() == ROUTES[race]
    assert not set(env.route()) & other_saga_quests(race)


@pytest.mark.parametrize("race,faction", SAGA_CHARS)
def test_chain_view_holds_no_other_race_chain(race, faction):
    env = Env(race=race, faction=faction)
    view = env.view()
    assert view[0] == RACE_CHAINS[race]
    for key, chain_id in RACE_CHAINS.items():
        if key != race:
            assert chain_id not in view
    # No chain in the view carries another saga's quest IDs.
    seen = set()
    for chain_id in view:
        seen.update(env.quests(chain_id))
    assert not seen & other_saga_quests(race)


def test_switching_sagas_swaps_route_without_changing_it():
    env = Env(race="Human")
    human_route = env.ns.SagaRoutes["Human"]
    assert env.ns.SetActiveSaga("Gnome") is True
    assert env.route() == [10, 11]
    assert env.ns.SetActiveSaga(None) is True
    assert env.route() == [1, 2]
    # The registered route is the same table, with the same IDs.
    assert env.same_table(env.ns.SagaRoutes["Human"], human_route)
    assert env.same_table(env.ns.StoryRoute, human_route)


def test_rebuilding_never_registers_a_chain_twice():
    env = Env(race="Gnome", share=True)
    before = len(env.ns.AllChains)
    for key in ("Human", "Orc", "Gnome", None):
        env.ns.SetActiveSaga(key)
    env.ns.RebuildView()
    assert len(env.ns.AllChains) == before


# ------------------------------------------------------------------
# Journal isolation
# ------------------------------------------------------------------

def test_journal_first_run_seeds_only_the_active_view():
    env = Env(race="Gnome")
    env.complete(1, 2, 10, 11, 20)
    env.ns.JournalCheckUnlocks()
    seen = env.keys("journalSeen")
    assert {10, 11, "epilogue:gnome_a", 20, "epilogue:neutral_a"} <= seen
    assert not {1, 2, "epilogue:human_a"} & seen
    # The first run is silent.
    assert env.printed() == []


def test_journal_never_announces_another_sagas_pages():
    env = Env(race="Gnome")
    env.ns.JournalCheckUnlocks()  # first run: nothing done yet
    env.complete(1, 2)            # Human quests only
    env.ns.JournalCheckUnlocks()
    assert env.printed() == []
    assert not {1, 2, "epilogue:human_a"} & env.keys("journalAnnounced")
    env.complete(10)              # a Gnome quest is announced
    env.ns.JournalCheckUnlocks()
    assert len(env.printed()) == 1
    assert 10 in env.keys("journalAnnounced")


def test_journal_first_run_waits_for_the_race():
    # Issue #37. ADDON_LOADED: UnitRace is not ready, so the view is the
    # Human fallback. The Gnome character already did quests 10 and 11.
    env = Env(race=None)
    env.complete(1, 10, 11)
    assert env.ns.SagaKnown() is False
    env.ns.JournalCheckUnlocks()
    # No seed on the fallback view, and the first run is still to come.
    assert env.ns.cdb.journalInit is None
    assert env.keys("journalSeen") == set()
    assert env.keys("journalAnnounced") == set()
    # PLAYER_LOGIN: the race is known now.
    env.ns.setRace("Gnome")
    assert env.ns.RebuildView() == "Gnome"
    env.ns.JournalCheckUnlocks()
    assert env.ns.cdb.journalInit is True
    assert env.printed() == []
    assert env.ns.JournalUnreadCount() == 0
    seen = env.keys("journalSeen")
    assert {10, 11, "epilogue:gnome_a"} <= seen
    assert not {1, 2, "epilogue:human_a"} & seen
    # Later progress is still announced.
    env.complete(20)
    env.ns.JournalCheckUnlocks()
    assert len(env.printed()) == 1


def test_journal_first_run_keeps_waiting_while_the_race_is_empty():
    # An empty race token stays unknown on every call, so the seed
    # is still to come when the race arrives.
    env = Env(race="")
    env.complete(10, 11)
    for _ in range(3):
        env.ns.JournalCheckUnlocks()
    assert env.ns.cdb.journalInit is None
    assert env.keys("journalSeen") == set()
    assert env.printed() == []
    env.ns.setRace("Gnome")
    env.ns.RebuildView()
    env.ns.JournalCheckUnlocks()
    assert env.ns.cdb.journalInit is True
    assert {10, 11} <= env.keys("journalSeen")
    assert env.printed() == []


def test_journal_first_run_seeds_a_forced_saga_without_unitrace():
    env = Env(race=None, forced="Gnome")
    env.complete(10, 11)
    assert env.ns.SagaKnown() is True
    env.ns.JournalCheckUnlocks()
    assert env.ns.cdb.journalInit is True
    assert {10, 11, "epilogue:gnome_a"} <= env.keys("journalSeen")
    assert env.printed() == []


def test_journal_unread_count_ignores_other_sagas():
    env = Env(race="Gnome")
    assert env.ns.JournalUnreadCount() == 0
    env.complete(1, 2)  # whole Human chain: 2 pages + epilogue
    assert env.ns.JournalUnreadCount() == 0
    env.complete(10)
    assert env.ns.JournalUnreadCount() == 1


def test_previewing_another_saga_keeps_its_pages_blind():
    # A Human character previews the Gnome saga. Progress is the
    # character's own, so no Gnome page is written and none leaks text.
    env = Env(race="Human")
    env.complete(1, 2)
    assert env.ns.SetActiveSaga("Gnome") is True
    chain = env.chain("gnome_a")
    for page in range(1, env.ns.JournalPageCount(chain) + 1):
        view = env.ns.JournalPageView(chain, page)
        assert view.locked is True
        assert view.title == "???"
        assert view.questName is None and view.giver is None
    written, total = env.ns.JournalChapterProgress(chain)
    assert (written, total) == (0, 3)
    assert env.ns.JournalUnreadCount() == 0


# ------------------------------------------------------------------
# Shared chains
# ------------------------------------------------------------------

def test_shared_chain_is_trimmed_for_the_sharing_saga_only():
    gnome = Env(race="Gnome", share=True)
    assert gnome.view()[:2] == ["gnome_a", "human_a"]
    assert gnome.ns.ChainGroup(gnome.chain("human_a"), "Gnome") == "shared"
    assert gnome.quests("human_a") == [2]  # quest 1 is skipped for Gnomes
    assert gnome.chain("human_a").sourceChain is not None

    human = Env(race="Human", share=True)
    assert human.quests("human_a") == [1, 2]
    assert human.chain("human_a").sourceChain is None


def test_shared_chain_does_not_reach_sagas_not_listed():
    orc = Env(race="Orc", faction="Horde", share=True)
    assert "human_a" not in orc.view()


def test_shared_copy_leaves_the_owner_chain_untouched():
    env = Env(race="Gnome", share=True)
    copy = env.chain("human_a")
    assert not env.same_table(copy, copy.sourceChain)
    assert len(copy.sourceChain.quests) == 2
    env.ns.SetActiveSaga("Human")
    original = env.chain("human_a")
    assert env.same_table(original, copy.sourceChain)
    assert env.quests("human_a") == [1, 2]


# ------------------------------------------------------------------
# Neutral chains
# ------------------------------------------------------------------

@pytest.mark.parametrize("race,faction", SAGA_CHARS)
def test_neutral_chain_is_visible_to_both_factions(race, faction):
    env = Env(race=race, faction=faction)
    view = env.view()
    for chain_id in ("neutral_a", "neutral_norace"):
        assert chain_id in view
        assert env.ns.ChainGroup(env.chain(chain_id), race) == "neutral"


@pytest.mark.parametrize("race,faction,visible,hidden", [
    ("Human", "Alliance", "neutral_alliance", "neutral_horde"),
    ("Gnome", "Alliance", "neutral_alliance", "neutral_horde"),
    ("Orc", "Horde", "neutral_horde", "neutral_alliance"),
])
def test_faction_tagged_neutral_chain_reaches_its_faction_only(
        race, faction, visible, hidden):
    env = Env(race=race, faction=faction)
    assert visible in env.view()
    assert hidden not in env.view()


@pytest.mark.parametrize("race,faction", SAGA_CHARS)
def test_neutral_chain_is_claimable_in_own_saga(race, faction):
    # Claimable = the saga is not read-only, so the chain can be pinned
    # and guided (waypoints, tracker).
    env = Env(race=race, faction=faction, pin="neutral_a")
    assert env.ns.IsSagaReadOnly() is False
    assert env.ns.cdb.forcedChain == "neutral_a"


def test_neutral_pin_survives_a_switch_across_factions():
    env = Env(race="Orc", faction="Horde", pin="neutral_a")
    assert env.ns.SetActiveSaga("Human") is True
    assert env.ns.IsSagaReadOnly() is True
    assert env.ns.cdb.forcedChain == "neutral_a"
    assert env.ns.SetActiveSaga(None) is True
    assert env.ns.cdb.forcedChain == "neutral_a"


def test_horde_race_without_data_still_sees_neutral_read_only():
    env = Env(race="Troll", faction="Horde")
    assert env.ns.ActiveSaga == "Human"
    assert env.ns.IsSagaReadOnly() is True
    assert "neutral_a" in env.view()


# ------------------------------------------------------------------
# Pinned chain while the race is unknown (issue #11 comment)
# ------------------------------------------------------------------

def test_pin_survives_rebuild_before_unitrace_is_ready():
    # ADDON_LOADED: UnitRace not ready, so the view is the Human fallback.
    env = Env(race=None, pin="gnome_a")
    assert env.ns.ActiveSaga == "Human"
    assert env.ns.SagaKnown() is False
    assert env.ns.cdb.forcedChain == "gnome_a"
    # PLAYER_LOGIN: the race is known now.
    env.ns.setRace("Gnome")
    assert env.ns.RebuildView() == "Gnome"
    assert env.ns.cdb.forcedChain == "gnome_a"
    assert env.chain("gnome_a") is not None


def test_empty_race_token_counts_as_unknown():
    env = Env(race="", pin="gnome_a")
    assert env.ns.SagaKnown() is False
    assert env.ns.cdb.forcedChain == "gnome_a"


def test_failing_unitrace_counts_as_unknown():
    env = Env(race=None, pin="gnome_a")
    env.lua.execute('UnitRace = function() error("not ready") end')
    env.ns.RebuildView()
    assert env.ns.SagaKnown() is False
    assert env.ns.cdb.forcedChain == "gnome_a"


def test_known_race_still_clears_a_pin_outside_its_view():
    env = Env(race="Human", pin="gnome_a")
    assert env.ns.SagaKnown() is True
    assert env.ns.cdb.forcedChain is None


def test_race_without_saga_data_is_still_known():
    # A Troll token with no Troll data falls back to Human for real, so a
    # pin outside the Human view is cleared.
    env = Env(race="Troll", faction="Horde", pin="gnome_a")
    assert env.ns.SagaKnown() is True
    assert env.ns.cdb.forcedChain is None


def test_forced_saga_counts_as_known_without_unitrace():
    env = Env(race=None, forced="Gnome", pin="human_a")
    assert env.ns.ActiveSaga == "Gnome"
    assert env.ns.SagaKnown() is True
    assert env.ns.cdb.forcedChain is None


def test_stale_forced_saga_does_not_count_as_known():
    env = Env(race=None, forced="Dwarf", pin="gnome_a")
    assert env.ns.SagaKnown() is False
    assert env.ns.cdb.forcedChain == "gnome_a"
