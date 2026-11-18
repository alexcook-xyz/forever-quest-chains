-- MainStoryGuide: multi-saga registry.
--
-- Each playable race owns a saga (Data_<Race>.lua chains tagged with
-- race = "<Key>", plus Route_<Race>.lua registering that saga's route).
-- This file must load BEFORE every Data_/Route_ file and before Core.lua.
--
-- Model
--   ns.Sagas[key]      registry entry: { key, name, faction, icon }
--   ns.SagaOrder       display order (Alliance races, then Horde races)
--   ns.AllChains       every chain ever registered (all sagas)
--   ns.SagaRoutes[key] the master route (quest ID list) of a saga
--   ns.Chains          the VIEW: only the chains the active saga may see
--                      (its own race chains + neutral + optional Forever).
--                      The neutral MAIN chains (Tirion Fordring, Pamela Redpath,
--                      Linken) sit among the route chains by required level
--                      (see ns.RebuildView). The other neutral chains follow
--                      the route, each after the chains of its `after` list
--                      (issue #74); Forever chains come last.
--                      Rebuilt in place, so every existing consumer that
--                      iterates ns.Chains is automatically scoped and a
--                      Dwarf can never receive the Human route/chains.
--   ns.StoryRoute      the VIEW of the active saga's route.
--
-- Active saga = cdb.forcedSaga (alts / previews) else the player's race
-- (UnitRace) else Human. A saga with no loaded data is never active.
-- Viewing a saga of the opposite faction is READ-ONLY (no waypoints,
-- tracker, auto-pinning); progress is always the character's own, so
-- previewing never reveals journal text the character has not earned.

local _, ns = ...

ns.Sagas = {}
ns.SagaOrder = {}
ns.AllChains = {}
ns.SagaRoutes = {}
ns.Chains = ns.Chains or {}

local function Def(key, name, faction, icon)
  ns.Sagas[key] = { key = key, name = name, faction = faction,
                    icon = "Interface\\Icons\\" .. icon }
  ns.SagaOrder[#ns.SagaOrder + 1] = key
end

Def("Human",    "Human Saga",     "Alliance", "Achievement_Character_Human_Male")
Def("Dwarf",    "Dwarf Saga",     "Alliance", "Achievement_Character_Dwarf_Male")
Def("Gnome",    "Gnome Saga",     "Alliance", "Achievement_Character_Gnome_Male")
Def("NightElf", "Night Elf Saga", "Alliance", "Achievement_Character_Nightelf_Female")
Def("Orc",      "Orc Saga",       "Horde",    "Achievement_Character_Orc_Male")
Def("Troll",    "Troll Saga",     "Horde",    "Achievement_Character_Troll_Male")
Def("Tauren",   "Tauren Saga",    "Horde",    "Achievement_Character_Tauren_Male")
Def("Scourge",  "Undead Saga",    "Horde",    "Achievement_Character_Undead_Male")

ns.DEFAULT_SAGA = "Human"
ns.NEUTRAL = "Neutral"   -- chain.race value for shared mid/end-game chains

-- Shared chains: a chain owned by one race's data file (e.g. the Human
-- Westfall/Duskwood chains) that other sagas also walk. Declared in
-- Shared_Alliance.lua as
--   ns.SharedChains[chainId] = { sagas = { Gnome = true, ... },
--                                skip  = { [questId] = true, ... } }
-- `skip` lists quests the sharing saga's characters can never get (e.g.
-- Northshire starter quests), which are left out of THAT saga's view so the
-- missing-link finder never reports them as a gap. The chain table itself
-- is untouched: the owner's view keeps every quest.
ns.SharedChains = ns.SharedChains or {}

------------------------------------------------------------------
-- Registration
------------------------------------------------------------------
local registered = {}

local function Absorb(chain)
  -- A per-saga view copy (see ViewChain) is never a registration of its own.
  if type(chain) == "table" and not chain.sourceChain and not registered[chain] then
    registered[chain] = true
    ns.AllChains[#ns.AllChains + 1] = chain
  end
end

function ns.RegisterChains(list)
  for _, c in ipairs(list or {}) do Absorb(c) end
  ns.RebuildView()
end

function ns.RegisterRoute(key, ids)
  ns.SagaRoutes[key] = ids
  ns.RebuildView()
end

-- ns.RouteInfo is keyed by quest ID only, so one saga cannot change the
-- text of a quest that it shares with another saga. A Route_ file writes
-- such text to ns.RouteInfoBySaga[key][questID]. Its fields replace the
-- same fields of the shared entry for that saga only.
ns.RouteInfoBySaga = ns.RouteInfoBySaga or {}
local mergedInfo = {}

-- The RouteInfo of a quest as a saga sees it (default: the active saga).
-- Returns nil when there is no entry. Do not change the returned table.
function ns.RouteInfoOf(questID, sagaKey)
  local base = (ns.RouteInfo or {})[questID]
  sagaKey = sagaKey or ns.ActiveSaga or ns.GetActiveSaga()
  local over = (ns.RouteInfoBySaga[sagaKey] or {})[questID]
  if not over then return base end
  mergedInfo[sagaKey] = mergedInfo[sagaKey] or {}
  local hit = mergedInfo[sagaKey][questID]
  if hit and hit.base == base and hit.over == over then return hit.info end
  local info = {}
  for k, v in pairs(base or {}) do info[k] = v end
  for k, v in pairs(over) do info[k] = v end
  mergedInfo[sagaKey][questID] = { base = base, over = over, info = info }
  return info
end

------------------------------------------------------------------
-- Race / saga resolution
------------------------------------------------------------------
-- A side chain is never part of the main route: an optional (Forever) chain
-- or a class chain (issue #41). It is never picked by ns.GetActive and it
-- sits after the main chains in every saga view.
function ns.IsSideChain(chain)
  return chain ~= nil and (chain.optional == true or chain.classSpecific == true)
end

function ns.SagaHasData(key)
  if not key or not ns.Sagas[key] then return false end
  for _, c in ipairs(ns.AllChains) do
    if c.race == key and not ns.IsSideChain(c) then return true end
  end
  return false
end

-- The English race token from UnitRace ("Human", "Scourge", ...), or nil
-- when the API is absent or has no answer yet (it can be empty at
-- ADDON_LOADED).
local function RaceToken()
  if not UnitRace then return nil end
  local ok, _, e = pcall(UnitRace, "player")
  if ok and type(e) == "string" and e ~= "" then return e end
  return nil
end

-- The saga for the logged-in character's race. When that race has no
-- registered/loaded saga (BloodElf, Draenei, unknown, no API), this
-- returns ns.DEFAULT_SAGA (Human), never nil.
function ns.GetPlayerRace()
  local eng = RaceToken()
  if eng and ns.SagaHasData(eng) then return eng end
  return ns.DEFAULT_SAGA
end

-- The saga chosen on purpose (cdb.forcedSaga), or nil when none is set
-- or the chosen saga has no loaded data.
local function ForcedSaga()
  local forced = ns.cdb and ns.cdb.forcedSaga
  if forced and ns.SagaHasData(forced) then return forced end
  return nil
end

-- True when the active saga is a real answer, not the Human fallback
-- used while UnitRace is still empty: a forced saga with data, or a
-- race token from UnitRace.
function ns.SagaKnown()
  return ForcedSaga() ~= nil or RaceToken() ~= nil
end

function ns.GetActiveSaga()
  return ForcedSaga() or ns.GetPlayerRace()
end

function ns.SagaFaction(key)
  local s = ns.Sagas[key or ns.GetActiveSaga()]
  return s and s.faction or nil
end

-- Viewing the other faction's saga: browse only.
function ns.IsSagaReadOnly(key)
  local pf = ns.PlayerFaction and ns.PlayerFaction() or nil
  local sf = ns.SagaFaction(key)
  return (pf and sf and pf ~= sf) and true or false
end

-- The sharing record for a chain as seen from a saga that does NOT own it
-- (nil for the owner, for unshared chains, and for sagas not listed).
local function ShareFor(chain, sagaKey)
  local sh = ns.SharedChains[chain.id]
  if sh and chain.race ~= sagaKey and sh.sagas and sh.sagas[sagaKey] then
    return sh
  end
  return nil
end

-- Which chooser group a chain belongs to for a saga:
-- "race" | "shared" | "neutral" | "forever" | nil (not visible in that saga).
function ns.ChainGroup(chain, sagaKey)
  sagaKey = sagaKey or ns.GetActiveSaga()
  if chain.optional then return "forever" end
  if chain.classSpecific == true then
    -- A class chain keeps the race rules of a main chain. It is then a side
    -- group: the "forever" group, after the main chains (issue #41).
    local g = ns.ChainGroup({ race = chain.race, faction = chain.faction,
                              id = chain.id, quests = chain.quests }, sagaKey)
    return g and "forever" or nil
  end
  if chain.race == sagaKey then return "race" end
  if ShareFor(chain, sagaKey) then return "shared" end
  if chain.race == ns.NEUTRAL or chain.race == nil then
    -- Neutral chains are claimable by both factions unless authored
    -- with an explicit faction.
    if chain.faction and chain.faction ~= ns.SagaFaction(sagaKey) then
      return nil
    end
    return "neutral"
  end
  return nil
end

-- The chain as a given saga sees it: the chain itself, or (for a shared
-- chain with skipped quests) a cached shallow copy without those quests.
local viewCopies = {}
local function ViewChain(chain, sagaKey)
  local sh = ShareFor(chain, sagaKey)
  if not (sh and sh.skip and next(sh.skip)) then return chain end
  viewCopies[sagaKey] = viewCopies[sagaKey] or {}
  local copy = viewCopies[sagaKey][chain]
  if not copy then
    copy = {}
    for k, v in pairs(chain) do copy[k] = v end
    copy.quests = {}
    for _, q in ipairs(chain.quests or {}) do
      if not sh.skip[q.id] then copy.quests[#copy.quests + 1] = q end
    end
    copy.sourceChain = chain
    viewCopies[sagaKey][chain] = copy
  end
  return copy
end

-- The neutral MAIN chains of issue #19 (tools/sagas/neutral.json). Only these
-- sit among the route chains by level (issue #57). tests/test_saga_registry.py
-- checks that this list and neutral.json name the same chains.
local LEVEL_ORDERED = { tirion_fordring = true, pamela_redpath = true, linken = true }

-- Put each chain after the chains of its `after` list (chain IDs, issue #74) that are in `list`.
-- An ID that is not in `list` is ignored (an Alliance-only chain in a Horde view). Each step
-- takes the first chain, in list order, whose `after` chains are all placed, so a chain that no
-- `after` list touches keeps its place relative to the other chains. A cycle cannot be met:
-- the first chain left goes next, so the loop always ends and no chain is lost or doubled.
local function OrderAfter(list)
  local present = {}
  for _, c in ipairs(list) do present[c.id] = true end
  local placed, out, left = {}, {}, {}
  for i, c in ipairs(list) do left[i] = c end
  while #left > 0 do
    local pick = 1
    for i, c in ipairs(left) do
      local ready = true
      for _, id in ipairs(type(c.after) == "table" and c.after or {}) do
        if present[id] and not placed[id] and id ~= c.id then ready = false; break end
      end
      if ready then pick = i; break end
    end
    local c = table.remove(left, pick)
    placed[c.id] = true
    out[#out + 1] = c
  end
  return out
end

-- Rebuild ns.Chains / ns.StoryRoute for the active saga, in place.
function ns.RebuildView()
  -- Absorb chains that data files appended straight to ns.Chains
  -- (the generated Data_Forever.lua does this).
  for _, c in ipairs(ns.Chains) do Absorb(c) end
  local key = ns.GetActiveSaga()
  ns.ActiveSaga = key
  -- The saga's own chains come first (the default selection is Chains[1]),
  -- then shared, neutral and Forever chains; registration order within a group.
  -- The neutral MAIN chains are then merged in among the route chains
  -- (below); the other neutral chains follow the route.
  local view = {}
  for _, group in ipairs({ "race", "shared", "neutral", "forever" }) do
    for _, c in ipairs(ns.AllChains) do
      if ns.ChainGroup(c, key) == group then view[#view + 1] = ViewChain(c, key) end
    end
  end
  -- A saga with a route gets its own and shared chains in the order of that
  -- route (a Gnome starts in the Dwarf-owned Coldridge Valley, every Alliance
  -- race joins the Human spine, and a Human chain that a generated file adds
  -- after Data_Human.lua still sits where the story puts it), so the first
  -- chain is the one a new character starts with and GetActive does not pick
  -- a later chain over an earlier one. A chain's place is the route position
  -- of its first route quest. Chains with no route quest come after, in level
  -- order. Stable: ties keep registration order. A saga with no route keeps
  -- its authored order.
  local story = {}
  for i, c in ipairs(view) do
    local g = ns.ChainGroup(c, key)
    if g == "race" or g == "shared" then story[#story + 1] = { c = c, i = i } end
  end
  if ns.SagaRoutes[key] then
    local pos = {}
    for n, qid in ipairs(ns.SagaRoutes[key] or {}) do pos[qid] = pos[qid] or n end
    for _, s in ipairs(story) do
      s.pos = math.huge
      for _, q in ipairs(s.c.quests or {}) do s.pos = math.min(s.pos, pos[q.id] or math.huge) end
    end
    table.sort(story, function(a, b)
      if a.pos ~= b.pos then return a.pos < b.pos end
      local la, lb = a.c.minLevel or 0, b.c.minLevel or 0
      if la ~= lb then return la < lb end
      return a.i < b.i
    end)
    for n, s in ipairs(story) do view[n] = s.c end
  end
  -- The neutral MAIN chains (LEVEL_ORDERED) sit among the route chains by
  -- required level (issue #57), so a level 47 character is pointed at Linken
  -- before the level 60 end of the route. The route chains keep their order.
  -- Such a chain goes before the first route chain (after the first one) with
  -- a higher minLevel, and after every route chain of equal level. Chains of
  -- equal level keep registration order. The first route chain stays first: a
  -- new character starts on it. The other neutral chains (dungeon, reputation
  -- and raid chains) stay after the route in registration order, except that
  -- a chain goes behind the chains of its `after` list, the chains that hold a
  -- prerequisite quest of its quests (issue #74: Blackwing Lair before Molten
  -- Core and Ahn'Qiraj). Forever chains stay last. A chain with no minLevel
  -- counts as level 1.
  local route, neutral, late, forever = {}, {}, {}, {}
  for i, c in ipairs(view) do
    local g = ns.ChainGroup(c, key)
    if g == "neutral" and LEVEL_ORDERED[c.id] then
      neutral[#neutral + 1] = { c = c, i = i, level = c.minLevel or 1 }
    elseif g == "neutral" then late[#late + 1] = c
    elseif g == "forever" then forever[#forever + 1] = c
    else route[#route + 1] = c end
  end
  table.sort(neutral, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.i < b.i
  end)
  local merged, nextNeutral = {}, 1
  for n, r in ipairs(route) do
    if n > 1 then
      local rl = r.minLevel or 1
      while neutral[nextNeutral] and neutral[nextNeutral].level < rl do
        merged[#merged + 1] = neutral[nextNeutral].c
        nextNeutral = nextNeutral + 1
      end
    end
    merged[#merged + 1] = r
  end
  for n = nextNeutral, #neutral do merged[#merged + 1] = neutral[n].c end
  for _, c in ipairs(OrderAfter(late)) do merged[#merged + 1] = c end
  for _, c in ipairs(forever) do merged[#merged + 1] = c end
  for i = #ns.Chains, 1, -1 do ns.Chains[i] = nil end
  for i, c in ipairs(merged) do ns.Chains[i] = c end
  ns.StoryRoute = ns.SagaRoutes[key] or {}
  -- The pin is saved per character. Drop it only when the saga is known:
  -- a fallback view (UnitRace still empty) must not erase the pin of a
  -- chain from the character's real saga.
  if ns.cdb and ns.cdb.forcedChain and ns.SagaKnown() then
    local ok = false
    for _, c in ipairs(ns.Chains) do
      if c.id == ns.cdb.forcedChain then ok = true; break end
    end
    if not ok then ns.cdb.forcedChain = nil end
  end
  return key
end

-- Switch the viewed saga (alts / previews). Choosing the player's own
-- saga returns to auto. Returns true when the view changed.
function ns.SetActiveSaga(key)
  if not ns.cdb then return false end
  if key ~= nil and not ns.SagaHasData(key) then return false end
  if key == ns.GetPlayerRace() then key = nil end
  ns.cdb.forcedSaga = key
  -- The Hub starts again on the chooser of the new saga.
  local sel = ns.HubSel
  if sel then
    sel.view, sel.choice, sel.rowId, sel.chooserId = "chooser", nil, nil, nil
  end
  ns.RebuildView()
  if ns.BuildIndex then ns.BuildIndex() end
  if ns.Refresh then ns.Refresh() end
  return true
end
