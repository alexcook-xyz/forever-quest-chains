-- MainStoryGuide Core: quest index, MAIN/SIDE classification,
-- missing-link resolver, events, slash commands.
local ADDON, ns = ...
ns.name = ADDON

local function Print(msg)
  print("|cff7fd4ffForever Quest Chains:|r " .. tostring(msg))
end
ns.Print = Print

------------------------------------------------------------------
-- Saved variables
------------------------------------------------------------------
local function IsPlainTable(value)
  return type(value) == "table"
end

-- Saved variables pass through Blizzard's serializer untouched, so
-- malformed/corrupt values must be repaired at load instead of being
-- trusted into runtime code.
local function SafeDB()
  if not IsPlainTable(MainStoryGuideDB) then MainStoryGuideDB = {} end
  return MainStoryGuideDB
end

local function SafeCharDB()
  if not IsPlainTable(MainStoryGuideCharDB) then MainStoryGuideCharDB = {} end
  return MainStoryGuideCharDB
end

local function SafeTableField(cdb, key)
  if not IsPlainTable(cdb[key]) then cdb[key] = {} end
  return cdb[key]
end

local function InitDB()
  local db, cdb = SafeDB(), SafeCharDB()
  if db.gossipTags == nil then db.gossipTags = true end
  if db.tooltipTags == nil then db.tooltipTags = true end
  if db.routeAutoWaypoint == nil then db.routeAutoWaypoint = true end
  if db.useWaypointUI == nil then db.useWaypointUI = true end
  if db.showHints == nil then db.showHints = false end
  if db.questSparkles == nil then db.questSparkles = true end
  if db.questKillMarks == nil then db.questKillMarks = true end
  if db.showMinimapButton == nil then db.showMinimapButton = true end
  if type(db.minimapAngle) ~= "number" then db.minimapAngle = 210 end
  SafeTableField(cdb, "skipped")      -- chainId -> true
  if type(cdb.forcedChain) ~= "string" then
    cdb.forcedChain = nil  -- chainId pinned in guide
  end
  SafeTableField(cdb, "dump")                 -- /story logquest output
  SafeTableField(cdb, "journalSeen")          -- journal key -> viewed
  SafeTableField(cdb, "journalAnnounced")     -- journal key -> chat-noticed
  cdb.journalInit = cdb.journalInit or nil      -- first-run seed done
  SafeTableField(cdb, "routeManual")          -- "questID:KIND" -> toggled off by hand
  if type(cdb.forcedSaga) ~= "string" then
    cdb.forcedSaga = nil  -- race key of a saga viewed on purpose (alts/previews)
  end
  ns.db, ns.cdb = db, cdb
  if ns.RebuildView then ns.RebuildView() end
end
ns.InitDB = InitDB

------------------------------------------------------------------
-- Quest state helpers (Forever 16001 = modern API, guarded)
------------------------------------------------------------------
function ns.IsCompleted(questID)
  if not questID then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok, r = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    if ok then return r and true or false end
  end
  if GetQuestsCompleted then
    local t = GetQuestsCompleted()
    return t and t[questID] and true or false
  end
  return false
end

function ns.IsInLog(questID)
  if not questID then return false end
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    if ok then return idx ~= nil end
  end
  if GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
      if not isHeader and id == questID then return true end
    end
  end
  return false
end

-- Returns list of {questID, title, level} for quests in the log.
function ns.GetLogQuests()
  local out = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local ok, num = pcall(C_QuestLog.GetNumQuestLogEntries)
    if ok and num then
      for i = 1, num do
        local ok2, info = pcall(C_QuestLog.GetInfo, i)
        if ok2 and info and not info.isHeader and info.questID and info.questID > 0 then
          out[#out + 1] = { questID = info.questID, title = info.title or "?", level = info.level or 0 }
        end
      end
      return out
    end
  end
  if GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local title, level, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
      if title and not isHeader and id and id > 0 then
        out[#out + 1] = { questID = id, title = title, level = level or 0 }
      end
    end
  end
  return out
end

------------------------------------------------------------------
------------------------------------------------------------------
-- Catalogue inclusion gate
-- Class quests show only inside a chain with classSpecific = true, and
-- only to a player of that class (issue #41); anywhere else they stay
-- hidden. Quests known only from disabled/commented Forever guide data are
-- not presented as playable content. This one predicate feeds the
-- indexes, routes, journals, counts and zone catalogues.
------------------------------------------------------------------
function ns.IsClassSpecificQuest(q)
  return q and (q.classSpecific == true or q.class ~= nil) and true or false
end

-- Whether a class quest is for the class `classFile` (default: the player).
-- `q.class` is one class token or a list ("WARRIOR, PALADIN"). An unknown
-- class (UnitClass gave no value) matches nothing, and so does a quest
-- with no `class` field.
function ns.ClassMatches(q, classFile)
  if not q or type(q.class) ~= "string" then return false end
  classFile = classFile or ns.PlayerClass()
  if type(classFile) ~= "string" or classFile == "" then return false end
  classFile = classFile:upper()
  for token in q.class:gmatch("[^,%s]+") do
    if token:upper() == classFile then return true end
  end
  return false
end

-- A class quest counts only inside a class chain, and only for its class.
-- Elsewhere (the side catalogue, a normal chain) it stays hidden for all.
function ns.IsQuestIncluded(q, chain)
  if not q then return false end
  if ns.IsClassSpecificQuest(q) then
    if not (chain and chain.classSpecific == true) then return false end
    if not ns.ClassMatches(q) then return false end
  elseif chain and chain.classSpecific == true then
    return false -- a class chain shows only its class quests
  end
  if q.available == false then return false end
  if q.verified == "forever-commented" then return false end
  if chain then
    if chain.available == false then return false end
    if chain.id == "skyborne_class" then return false end
    if chain.verified == "forever-commented" then return false end
  end
  return true
end

function ns.IsChainIncluded(chain)
  if not chain or chain.available == false then return false end
  if chain.id == "skyborne_class" then return false end
  if chain.verified == "forever-commented" then return false end
  for _, q in ipairs(chain.quests or {}) do
    if ns.IsQuestIncluded(q, chain) then return true end
  end
  return false
end

------------------------------------------------------------------
-- Index + classification
-- QuestIndex is MAIN-only (storyline quests) so the resolver, route
-- and saga counts never see side quests. ZoneQuestIndex holds the
-- catalogued side quests separately; an ID present in both sources
-- is MAIN (the storyline record wins, the side row is dropped).
------------------------------------------------------------------
ns.QuestIndex = {}      -- questID -> {chain=, index=, quest=}
ns.NameIndex = {}       -- quest name -> first questID (legacy scalar)
ns.NameIDs = {}         -- quest name -> {questID, ...} (ambiguity-safe)
ns.ChainIndex = {}      -- chainId -> chain
ns.ZoneQuestIndex = {}  -- questID -> zone side-quest record

local indexBuilt = false

local function BuildIndex()
  if ns.RebuildView then ns.RebuildView() end
  wipe(ns.QuestIndex); wipe(ns.NameIndex); wipe(ns.NameIDs)
  wipe(ns.ChainIndex); wipe(ns.ZoneQuestIndex)
  for _, chain in ipairs(ns.Chains or {}) do
    if chain.id and not ns.ChainIndex[chain.id] then
      ns.ChainIndex[chain.id] = chain
    end
    for catalogueIndex, q in ipairs(chain.quests or {}) do
      if ns.IsQuestIncluded(q, chain) then
        if q.id and not ns.QuestIndex[q.id] then
          -- index = position in the full catalogue (stable backlinks);
          -- effective positions are derived from EffectiveQuests at
          -- the single call sites that need them.
          ns.QuestIndex[q.id] = { chain = chain, index = catalogueIndex,
                                  quest = q }
        end
        if q.name and q.id then
          if not ns.NameIndex[q.name] then ns.NameIndex[q.name] = q.id end
          local ids = ns.NameIDs[q.name]
          if not ids then ids = {}; ns.NameIDs[q.name] = ids end
          ids[#ids + 1] = q.id
        end
      end
    end
  end
  -- Side catalogue (ZoneSideQuests is keyed by zone name AND zone id,
  -- both pointing at the same list: dedupe by list identity).
  local seenLists = {}
  for _, list in pairs(ns.ZoneSideQuests or {}) do
    if type(list) == "table" and not seenLists[list] then
      seenLists[list] = true
      for _, rec in ipairs(list) do
        if rec.id and ns.IsQuestIncluded(rec)
           and not ns.QuestIndex[rec.id]
           and not ns.ZoneQuestIndex[rec.id] then
          ns.ZoneQuestIndex[rec.id] = rec
        end
      end
    end
  end
  indexBuilt = true
end
ns.BuildIndex = BuildIndex

local function EnsureIndex()
  if not indexBuilt then BuildIndex() end
end

local function FindChainById(chainId)
  if not chainId then return nil end
  EnsureIndex()
  if ns.ChainIndex[chainId] then return ns.ChainIndex[chainId] end
  for _, c in ipairs(ns.Chains or {}) do
    if c.id == chainId then return c end
  end
  return nil
end

-- Look up any catalogued quest. Returns record, chain, index, source
-- where source is "main" (storyline) or "side" (zone catalogue).
function ns.LookupQuest(questID)
  EnsureIndex()
  local e = questID and ns.QuestIndex[questID]
  if e then return e.quest, e.chain, e.index, "main" end
  local rec = questID and ns.ZoneQuestIndex[questID]
  if rec then return rec, nil, nil, "side" end
  return nil, nil, nil, nil
end

------------------------------------------------------------------
-- Player eligibility. A class quest is eligible for its own class only
-- (an unknown class matches none). Faction gates apply only to side
-- chains (optional or class); an unknown faction (API absent) never
-- hides one.
------------------------------------------------------------------
function ns.PlayerFaction()
  if UnitFactionGroup then
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok then return f end
  end
  return nil
end

function ns.PlayerClass()
  if UnitClass then
    local ok, localized, classFile = pcall(UnitClass, "player")
    if ok then return classFile or localized end
  end
  return nil
end

function ns.QuestEligible(q, faction, classFile)
  if not q then return false end
  if ns.IsClassSpecificQuest(q) and not ns.ClassMatches(q, classFile) then
    return false
  end
  faction = faction or ns.PlayerFaction()
  if q.faction and faction and q.faction ~= faction then return false end
  return true
end

-- The included quests of a chain this character can actually do.
-- Class-specific and commented-only rows are removed everywhere;
-- faction-exclusive rows drop only from optional Forever chains.
function ns.EffectiveQuests(chain)
  if not ns.IsChainIncluded(chain) then return {} end
  local out = {}
  for _, q in ipairs(chain.quests or {}) do
    if ns.IsQuestIncluded(q, chain)
       and (not ns.IsSideChain(chain) or ns.QuestEligible(q)) then
      out[#out + 1] = q
    end
  end
  return out
end

-- Classify(questID) -> isMain(bool), chain, index, quest
function ns.Classify(questID)
  local e = questID and ns.QuestIndex[questID]
  if e then return true, e.chain, e.index, e.quest end
  return false, nil, nil, nil
end

-- Strip colour codes and "[12]" style level prefixes from a title.
function ns.CleanQuestTitle(title)
  if not title then return nil end
  if type(title) ~= "string" then title = tostring(title) end
  return (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                :gsub("^%[%d+.-%]%s*", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lua UI captions execute WoW hyperlink and texture escapes (|H, |T,
-- |K, |a). Server/driver-controlled strings must be neutralized at
-- the display boundary, not at lookup time.
function ns.EscapeUIText(text)
  if text == nil then return nil end
  if type(text) ~= "string" then text = tostring(text) end
  return (text:gsub("|", "||"))
end

-- Like Classify, but falls back to an exact quest-name lookup when the
-- ID is unknown (e.g. a Forever variant ID for a Classic quest). This
-- keeps real story quests from being mislabelled SIDE. A name shared
-- by several storyline quests ("The Defias Brotherhood" x6) is MAIN
-- with index = nil: never guess step 1.
function ns.ClassifyByIDOrName(questID, title)
  local isMain, chain, index, q = ns.Classify(questID)
  if isMain then return isMain, chain, index, q end
  local clean = ns.CleanQuestTitle(title)
  if not clean then return false, nil, nil, nil end
  local ids = (ns.NameIDs or {})[clean]
  if type(ids) == "table" and #ids > 0 then
    if #ids == 1 then return ns.Classify(ids[1]) end
    local _, firstChain = ns.Classify(ids[1])
    for i = 2, #ids do
      local _, c = ns.Classify(ids[i])
      if c ~= firstChain then firstChain = nil; break end
    end
    return true, firstChain, nil, nil
  end
  local id2 = (ns.NameIndex or {})[clean]
  if type(id2) == "number" then return ns.Classify(id2) end
  return false, nil, nil, nil
end

function ns.TagText(questID)
  return ns.TagTextFor(questID, nil)
end

-- TagTextFor(questID, title): MAIN/SIDE tags by quest ID, or by an
-- exact story-name fallback when the ID is unknown (a Forever
-- variant ID, for example). A name shared by several storyline
-- quests is MAIN with no invented step number.
function ns.TagTextFor(questID, title)
  local isMain, chain, index, q = ns.Classify(questID)
  if not isMain then
    isMain, chain, index, q = ns.ClassifyByIDOrName(questID, title)
  end
  if not isMain then return "|cff9d9d9d[SIDE]|r" end
  if not chain or type(index) ~= "number" or not q then
    return "|cff1eff00[MAIN]|r"
  end
  local quests = ns.EffectiveQuests(chain)
  index = nil
  for i, eq in ipairs(quests) do
    if eq.id == q.id then index = i; break end
  end
  if not index then return "|cff1eff00[MAIN]|r" end
  local total = #quests
  if q.kind == "lead" then
    return string.format("|cffffcc00[MAIN LEAD-IN: %s %d/%d]|r", chain.name, index, total)
  elseif q.kind == "dungeon" then
    return string.format("|cffff8000[MAIN DUNGEON: %s %d/%d]|r", chain.name, index, total)
  end
  return string.format("|cff1eff00[MAIN: %s %d/%d]|r", chain.name, index, total)
end

------------------------------------------------------------------
-- Missing-link resolver
-- For each chain (in story order), walk its quests in order:
--   completed -> keep walking
--   in log    -> that is your CURRENT step, stop
--   otherwise -> that is your MISSING LINK (go pick it up), stop
-- If a later quest is done/in-log while the target is incomplete,
-- you skipped story: flagged as GAP so you can backfill it.
------------------------------------------------------------------
-- Breadcrumb blocking: a quest whose story-order thread runs
-- through an unavailable (deferred) quest cannot be picked up yet --
-- its breadcrumb comes from a turn-in that cannot happen. Leads and
-- dungeons are independently offered entry points and break the
-- block, which otherwise propagates through following normal quests.
-- Returns a set of blocked quest IDs for one chain quest list.
function ns.BreadcrumbBlockedIDs(quests)
  local blocked, out = false, {}
  for _, q in ipairs(quests or {}) do
    if q and q.id then
      local completed = ns.IsCompleted(q.id)
      local inLog = (not completed) and ns.IsInLog(q.id)
      local deferred = ns.IsStepDeferred
        and ns.IsStepDeferred(q, completed, inLog)
      if deferred then
        blocked = true
      elseif q.kind == "lead" or q.kind == "dungeon" then
        blocked = false
      elseif blocked and not completed and not inLog then
        out[q.id] = true
      end
    end
  end
  return out
end

-- Exclusive quests (issue #56): quests that list each other in
-- exclusiveWith are one step. The member that counts is the first one
-- done, else the first one in the log, else the first one listed.
-- Returns the counted quests and their positions in the full list
-- (nil positions: the list is unchanged).
local function CollapseExclusive(quests)
  local any = false
  for _, q in ipairs(quests) do
    if q.exclusiveWith then any = true; break end
  end
  if not any then return quests, nil end
  local pos, partners = {}, {}
  for i, q in ipairs(quests) do
    if q.id then pos[q.id] = i end
  end
  -- The relation is symmetric: a one-way entry in the data still pairs both.
  for _, q in ipairs(quests) do
    for _, otherID in ipairs(q.exclusiveWith or {}) do
      if pos[otherID] and pos[otherID] ~= pos[q.id] then
        partners[q.id] = partners[q.id] or {}
        partners[otherID] = partners[otherID] or {}
        partners[q.id][#partners[q.id] + 1] = otherID
        partners[otherID][#partners[otherID] + 1] = q.id
      end
    end
  end
  local ranks = {}
  local function rank(id)
    local r = ranks[id]
    if not r then
      r = ns.IsCompleted(id) and 0 or (ns.IsInLog(id) and 1 or 2)
      ranks[id] = r
    end
    return r
  end
  local kept, at = {}, {}
  for i, q in ipairs(quests) do
    local keep = true
    for _, otherID in ipairs(partners[q.id] or {}) do
      local rq, ro = rank(q.id), rank(otherID)
      if ro < rq or (ro == rq and pos[otherID] < i) then keep = false end
    end
    if keep then kept[#kept + 1] = q; at[#kept] = i end
  end
  return kept, at
end

function ns.ResolveChain(chain)
  local quests, at = CollapseExclusive(ns.EffectiveQuests(chain))
  local done, target, targetState, laterProgress = 0, nil, nil, false
  local blocked = ns.BreadcrumbBlockedIDs and ns.BreadcrumbBlockedIDs(quests) or {}
  local deferredTarget = nil
  for i, q in ipairs(quests) do
    local completed, inLog = ns.IsCompleted(q.id), ns.IsInLog(q.id)
    if completed then done = done + 1 end
    if not target then
      if inLog and not completed then
        target, targetState = { quest = q, index = at and at[i] or i }, "IN_PROGRESS"
      elseif not completed and not inLog then
        if ns.IsStepDeferred and ns.IsStepDeferred(q, completed, inLog) then
          if not deferredTarget then
            deferredTarget = { quest = q, index = at and at[i] or i }
          end
        elseif not (q.id and blocked[q.id]) then
          target, targetState = { quest = q, index = at and at[i] or i }, "PICKUP"
        end
      end
    elseif completed or inLog then
      laterProgress = true
    end
  end
  if not target and deferredTarget then
    target, targetState = deferredTarget, "PICKUP"
  end
  local total = #quests
  local state
  if total == 0 then state = "EMPTY"
  elseif done >= total then state = "DONE"
  elseif target and targetState == "IN_PROGRESS" then state = "IN_PROGRESS"
  elseif target and laterProgress then state = "GAP"
  elseif target then state = "PICKUP"
  else state = "PICKUP" end
  return { chain = chain, done = done, total = total, state = state,
           target = target and target.quest or nil,
           targetIndex = target and target.index or nil }
end

-- Per-quest checklist for one chain: [x] done, [>] in log,
-- [!] your next/missing link, [ ] still to come.
function ns.ChainStatusLines(chain)
  local r = ns.ResolveChain(chain)
  local lines = { string.format("%s - %d/%d done [%s]", chain.name, r.done, r.total, r.state) }
  for i, q in ipairs(ns.EffectiveQuests(chain)) do
    local mark
    if ns.IsCompleted(q.id) then mark = "|cff1eff00[x]|r"
    elseif ns.IsInLog(q.id) then mark = "|cffffcc00[>]|r"
    elseif r.target and r.target.id == q.id then mark = "|cffff4040[!]|r"
    else mark = "|cff9d9d9d[ ]|r" end
    lines[#lines + 1] = string.format("  %s %d. %s", mark, i, q.name)
  end
  return lines, r
end

-- The chain the guide should show: pinned chain if set, else the
-- first not-finished, not-skipped chain at/near the player's level,
-- preferring one already in progress. Optional (Forever) chains are
-- never auto-selected, and a stale pin naming one is ignored here:
-- explicit Hub selection via GetChainStep is their only route, so a
-- Human character's auto route can never be hijacked.
function ns.GetActive()
  local level = UnitLevel("player") or 1
  local results, forced = {}, nil
  local firstEligible, nextUpcoming, lastCore = nil, nil, nil
  for _, chain in ipairs(ns.Chains or {}) do
    local r = ns.ResolveChain(chain)
    r.skipped = ns.cdb and ns.cdb.skipped[chain.id] and true or false
    results[#results + 1] = r
    if not ns.IsSideChain(chain) then
      lastCore = r
      -- A follow on a finished chain releases itself (issue #59, question 6).
      if ns.cdb and ns.IsFollowActive and ns.IsFollowActive(ns.cdb.forcedChain, chain.id, r.state) then
        forced = r
      end
      if not r.skipped and r.state ~= "DONE" then
        if r.state == "IN_PROGRESS" or r.state == "GAP" then
          if not firstEligible then firstEligible = r end
        elseif level >= (chain.minLevel or 1) - 2 then
          if not firstEligible then firstEligible = r end
        elseif not nextUpcoming then
          nextUpcoming = r
        end
      end
    end
  end
  return forced or firstEligible or nextUpcoming or lastCore
         or results[#results], results
end

------------------------------------------------------------------
-- Waypoint: Waypoint UI in-world pin, else the native map pin.
-- One managed pin at a time: the previous pin is removed first.
------------------------------------------------------------------
-- Where a quest is turned in: the RouteInfo override when the
-- turn-in NPC differs from the giver, else the giver record itself.
function ns.TurnTarget(q, info)
  local t = info and info.turn
  if t then
    return { name = q.name, giver = t.name or q.giver, zone = t.zone or q.zone,
             map = t.map or q.map, x = t.x, y = t.y }
  end
  return { name = q.name, giver = q.giver, zone = q.zone,
           map = q.map, x = q.x, y = q.y }
end


local ownsNativeWaypoint = false
local ownsWaypointUIPin = false

function ns.ClearWaypointUIWaypoint()
  local W = WaypointUIAPI and WaypointUIAPI.Navigation
  if W and type(W.ClearUserNavigation) == "function" then
    local shouldClear = ownsWaypointUIPin
    if type(W.IsUserNavigationFlagged) == "function" and W.IsUserNavigationFlagged("MainStoryGuide_Waypoint") then
      shouldClear = true
    end
    if shouldClear then
      pcall(W.ClearUserNavigation)
    end
  end
  ownsWaypointUIPin = false
end


-- Clears only pins this addon set (Waypoint UI user waypoint
-- and/or native user waypoint), never a waypoint the player made
-- themselves.
function ns.ClearWaypoint()
  ns.ClearWaypointUIWaypoint()
  if ownsNativeWaypoint then
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
    end
    if C_Map and C_Map.ClearUserWaypoint then
      pcall(C_Map.ClearUserWaypoint)
    end
    ownsNativeWaypoint = false
  end
end

local function ValidWaypointTarget(q)
  if type(q) ~= "table" then return false end
  if type(q.map) ~= "number" or q.map <= 0 then return false end
  if type(q.x) ~= "number" or type(q.y) ~= "number" then return false end
  if q.x < 0 or q.x > 100 or q.y < 0 or q.y > 100 then return false end
  return true
end

function ns.SetWaypointUIWaypoint(q, title, opts)
  if ns.IsSagaReadOnly and ns.IsSagaReadOnly() then return false end
  if ns.db and ns.db.useWaypointUI == false then return false end
  if not ValidWaypointTarget(q) then return false end
  local W = WaypointUIAPI and WaypointUIAPI.Navigation
  if not W or type(W.NewUserNavigation) ~= "function" then return false end
  local quiet = (opts == true) or (type(opts) == "table" and opts.quiet)
  ns.ClearWaypointUIWaypoint()
  local ok, res = pcall(W.NewUserNavigation, {
    name = title or q.name or "Forever Quest Chains",
    mapID = q.map,
    x = q.x,
    y = q.y,
    flags = "MainStoryGuide_Waypoint",
    requestRecolor = true,
    suppressAudio = quiet and true or false,
    fromWUI = true,
  })
  if ok and res ~= nil then
    ownsWaypointUIPin = true
    ownsNativeWaypoint = true
    return true
  end
  return false
end


-- Returns { native = bool, waypointui = bool } so callers
-- can give in-menu feedback; the chat line stays as a mirror, never the only
-- signal. Never claims more than was actually set. opts may be the legacy
-- boolean true or { quiet = true } for the background tracker, which must not
-- spam chat every time the current step changes.
function ns.SetWaypoint(q, opts)
  if ns.IsSagaReadOnly and ns.IsSagaReadOnly() then
    return { native = false, waypointui = false, readOnly = true }
  end
  if not ValidWaypointTarget(q) then
    return { native = false, waypointui = false }
  end
  local quiet = (opts == true) or (type(opts) == "table" and opts.quiet)
  -- The native user waypoint is shared with the player: never touch
  -- it unless it is empty or one this addon set.
  local playerPin = nil
  if C_Map and type(C_Map.GetUserWaypoint) == "function" then
    local ok, pin = pcall(C_Map.GetUserWaypoint)
    if ok then playerPin = pin end
  end
  local isAddonPin = ownsNativeWaypoint or ownsWaypointUIPin
  if not isAddonPin and WaypointUIAPI and WaypointUIAPI.Navigation and WaypointUIAPI.Navigation.IsUserNavigationFlagged then
    if WaypointUIAPI.Navigation.IsUserNavigationFlagged("MainStoryGuide_Waypoint") then
      isAddonPin = true
    end
  end
  local force = type(opts) == "table" and opts.force
  if playerPin ~= nil and not isAddonPin and not force then
    if not quiet then
      Print("The map already has a waypoint of its own, so Forever Quest Chains left it alone.")
    end
    ownsNativeWaypoint = false
    ownsWaypointUIPin = false
    return { native = false, waypointui = false }
  end

  local title = (type(opts) == "table" and opts.title)
    or string.format("Main Story: %s (%s)", q.name or "Story target", q.giver or "?")
  local where = string.format("%s in %s%s", q.giver or q.name or "?", q.zone or "?",
    (q.x and q.y) and string.format(" (%.1f, %.1f)", q.x, q.y) or "")

  -- 1. Prefer Waypoint UI for modern in-world 3D waypoint navigation
  local wui = false
  if not ns.db or ns.db.useWaypointUI ~= false then
    wui = ns.SetWaypointUIWaypoint(q, title, opts)
  end

  if wui then
    if not quiet then
      Print("Waypoint (Waypoint UI in-world pin): " .. where .. ".")
    end
    return { native = true, waypointui = true }
  end

  -- 2. Fall back to native map pin
  local native = false
  if C_Map and type(C_Map.SetUserWaypoint) == "function"
     and UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function" then
    native = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(q.map, q.x / 100, q.y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
    end)
  end
  ownsNativeWaypoint = native and true or false


  if not quiet then
    if native then
      Print("Waypoint (map): " .. where .. ".")
    else
      Print("Go to " .. where .. ".")
    end
  end
  return { native = native and true or false, waypointui = false }
end

-- Background tracking variant: Waypoint UI in-world pin when available,
-- otherwise the native map pin.
function ns.SetTrackedWaypoint(q, title)
  if q and (not ns.db or ns.db.useWaypointUI ~= false)
     and ns.SetWaypointUIWaypoint(q, title, { quiet = true }) then
    return { native = true, waypointui = true }
  end
  return ns.SetWaypoint(q, { quiet = true })
end

local function NormalizeWaypointCoordinate(value)
  if not value then return nil end
  if value >= 0 and value <= 1 then return value * 100 end
  if value > 1 and value <= 100 then return value end
  return nil
end

-- Live Blizzard quest-objective position for the DO step. This is
-- deliberately queried from the game at tracker time: the routed
-- waypoint can change as objectives complete or the player crosses a
-- zone/flight/portal boundary, even when no quest-log event fires.
function ns.GetLiveQuestWaypoint(questID, quest)
  if not questID or not ns.IsInLog(questID) then return nil end

  local function MakeTarget(map, x, y, label)
    x, y = NormalizeWaypointCoordinate(x), NormalizeWaypointCoordinate(y)
    if not map or map <= 0 or not x or not y then return nil end
    return {
      name = quest and quest.name or "Quest objective",
      giver = label or "Quest objective",
      zone = quest and quest.zone or "?",
      map = map, x = x, y = y,
    }
  end

  if C_QuestLog and C_QuestLog.GetNextWaypoint then
    local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, questID)
    local target = ok and MakeTarget(map, x, y, "Quest objective")
    if target then
      if C_QuestLog.GetNextWaypointText then
        local textOk, text = pcall(C_QuestLog.GetNextWaypointText, questID)
        if textOk and text and text ~= "" then target.giver = text end
      end
      return target
    end
  end

  if C_QuestLog and C_QuestLog.GetQuestsOnMap then
    local maps, seen = {}, {}
    local function AddMap(candidate)
      if candidate and candidate > 0 and not seen[candidate] then
        seen[candidate] = true
        maps[#maps + 1] = candidate
      end
    end
    if C_Map and C_Map.GetBestMapForUnit then
      local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
      if ok then AddMap(map) end
    end
    if GetQuestUiMapID then
      local ok, map = pcall(GetQuestUiMapID, questID, true)
      if ok then AddMap(map) end
    end
    for _, map in ipairs(maps) do
      local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, map)
      if ok and type(quests) == "table" then
        for _, info in ipairs(quests) do
          if info.questID == questID then
            local target = MakeTarget(map, info.x, info.y, "Quest objective")
            if target then return target end
          end
        end
      end
    end
  end
  return nil
end

------------------------------------------------------------------
-- Selected-quest locations + detail (pure; the Find Location
-- action every clickable quest row drives). Targets keep the
-- { name=, giver=, zone=, map=, x=, y= } shape SetWaypoint eats.
-- A missing objective pin is reported honestly (objectiveSrc =
-- "none"); the giver is never silently substituted for it.
------------------------------------------------------------------
local function Pinnable(t)
  return t and t.map and t.x and t.y and true or false
end

local function RouteInfoFor(q, source)
  if source == "side" then
    return { task = q.task, turn = q.turn, obj = q.obj }
  end
  return ns.RouteInfoOf(q.id) or {}
end

-- How strongly local Forever data supports this quest existing on
-- the Forever client. This is provenance, not a promise that a
-- private server can never change an ID: Classic references are
-- labelled as such instead of being silently called verified.
function ns.QuestAvailability(q, chain)
  if not q then
    return { state = "unknown", label = "Not in the story guide catalogue." }
  end
  local verified = q.verified or (chain and chain.verified)
  local src = q.src
  if verified == "forever-commented" then
    return { state = "unverified",
             label = "Only disabled/commented Forever guide data; hidden from the guide." }
  end
  if (verified and tostring(verified):sub(1, 7) == "forever")
     or (src and tostring(src):sub(1, 7) == "forever") then
    return { state = "forever", label = "Present in Forever guide data." }
  end
  if verified == "classic" or (src and tostring(src) ~= "") then
    return { state = "classic",
             label = "Classic reference ID; local Forever guide data does not independently cover this step." }
  end
  return { state = "unverified",
           label = "Not independently verified in local Forever data." }
end

-- Structured chain links. Main-story order is itself a link (the
-- saga is authored as one linear chain); explicit q.requires and
-- side-catalogue next= fields are hard follow-up links. Entries are
-- { questID=, name=, kind="required"|"story-order", completed=,
-- inLog= } so the Hub can both display and navigate them.
function ns.QuestPrerequisites(questID)
  local q, chain, catalogueIndex, source = ns.LookupQuest(questID)
  local effectiveIndex = nil
  if chain then
    local quests = ns.EffectiveQuests(chain)
    for i, eq in ipairs(quests) do
      if eq.id == questID then effectiveIndex = i; break end
    end
    -- A quest that is present but filtered out for this character
    -- (class/faction/commented) has no live predecessor or route.
    if not effectiveIndex then return {} end
  end
  if not q then return {} end
  local out, seen = {}, {}
  local function Add(id, name, kind)
    if not id or id == questID or seen[id] then return end
    local rq = nil
    if type(id) == "number" then rq = ns.LookupQuest(id) end
    if type(id) == "number" and not rq then return end
    seen[id] = true
    out[#out + 1] = {
      questID = type(id) == "number" and id or nil,
      name = name or (rq and rq.name) or tostring(id),
      kind = kind or "required",
      completed = type(id) == "number" and ns.IsCompleted(id) or false,
      inLog = type(id) == "number" and ns.IsInLog(id) or false,
    }
  end

  if type(q.requires) == "string" then
    out[#out + 1] = { name = q.requires, kind = "required",
                      completed = false, inLog = false }
  elseif type(q.requires) == "table" then
    for _, req in ipairs(q.requires) do
      if type(req) == "number" then Add(req, nil, "required")
      elseif req then
        out[#out + 1] = { name = tostring(req), kind = "required",
                          completed = false, inLog = false }
      end
    end
  end

  -- Transitive closure: a prerequisite's own prerequisites are part
  -- of this quest's chain. Immediate links come first so "< Prereq"
  -- navigation still steps to the direct predecessor; ancestors
  -- follow, each added once (cycle-safe via Add's seen set).
  local function AddAncestors(id, depth)
    if type(id) ~= "number" or (depth or 0) > 500 then return end
    local rq, rchain, rpos, rsource = ns.LookupQuest(id)
    if not rq then return end
    if rchain then
      local quests = ns.EffectiveQuests(rchain)
      local at = nil
      for i, eq in ipairs(quests) do
        if eq.id == id then at = i; break end
      end
      if at and at > 1 then
        for i = at - 1, 1, -1 do
          local ancestor = quests[i]
          if ancestor and not seen[ancestor.id] then
            Add(ancestor.id, ancestor.name, "story-order")
            AddAncestors(ancestor.id, (depth or 0) + 1)
          end
        end
      end
      if type(rq.requires) == "table" then
        for _, req in ipairs(rq.requires) do
          if type(req) == "number" and not seen[req] then
            Add(req, nil, "required")
            AddAncestors(req, (depth or 0) + 1)
          end
        end
      end
    else
      if type(rq.requires) == "table" then
        for _, req in ipairs(rq.requires) do
          if type(req) == "number" and not seen[req] then
            Add(req, nil, "required")
            AddAncestors(req, (depth or 0) + 1)
          end
        end
      end
      if rsource == "side" then
        for _, rec in pairs(ns.ZoneQuestIndex or {}) do
          if rec.id ~= id and rec.next == id and not seen[rec.id] then
            Add(rec.id, rec.name, "required")
            AddAncestors(rec.id, (depth or 0) + 1)
            break
          end
        end
      end
    end
  end

  if chain and effectiveIndex and effectiveIndex > 1 then
    local quests = ns.EffectiveQuests(chain)
    for i = effectiveIndex - 1, 1, -1 do
      local ancestor = quests[i]
      if ancestor and not seen[ancestor.id] then
        Add(ancestor.id, ancestor.name, "story-order")
        AddAncestors(ancestor.id, 1)
      end
    end
  elseif source == "side" then
    for _, rec in pairs(ns.ZoneQuestIndex or {}) do
      if rec.id ~= questID and rec.next == questID then
        Add(rec.id, rec.name, "required")
        AddAncestors(rec.id, 1)
        break
      end
    end
  end
  for _, entry in ipairs(out) do
    if entry.questID then AddAncestors(entry.questID, 1) end
  end
  return out
end

function ns.QuestSuccessor(questID)
  local q, chain, catalogueIndex, source = ns.LookupQuest(questID)
  if not q then return nil end
  local nxt = nil
  if chain then
    local position = nil
    for i, eq in ipairs(ns.EffectiveQuests(chain)) do
      if eq.id == questID then position = i; break end
    end
    nxt = position and ns.EffectiveQuests(chain)[position + 1] or nil
  elseif source == "side" and q.next and q.next ~= questID then
    nxt = ns.LookupQuest(q.next)
  end
  if not nxt then return nil end
  return { questID = nxt.id, name = nxt.name,
           completed = ns.IsCompleted(nxt.id), inLog = ns.IsInLog(nxt.id) }
end

-- Player-facing requirements derived from guide data: storyline
-- order, level range, item/object starts, dungeon/group notes and
-- explicit side-quest follow-ups. Game prerequisites are only called
-- "Requires" when the data has an explicit link; chain order is
-- labelled as story order so parallel quests are not misrepresented.
function ns.QuestRequirements(questID)
  local q, chain, index, source = ns.LookupQuest(questID)
  if not q then return {}, ns.QuestAvailability(nil) end
  local availability = ns.QuestAvailability(q, chain)
  local lines = {}
  local function Add(text)
    if text and text ~= "" then lines[#lines + 1] = text end
  end

  for _, pre in ipairs(ns.QuestPrerequisites(questID)) do
    if not pre.questID then
      Add("Requires: " .. pre.name)
    else
      local mark = pre.completed and "[x] " or (pre.inLog and "[>] " or "[ ] ")
      if pre.kind == "story-order" then
        Add("Story order: after " .. mark .. "'" .. pre.name .. "'.")
      else
        Add("Prerequisite: " .. mark .. "'" .. pre.name .. "'.")
      end
    end
  end

  if q.reqlevel then
    Add(string.format("Requires level %d.", q.reqlevel))
  end

  if chain and chain.minLevel then
    local level = nil
    if UnitLevel then
      local ok, value = pcall(UnitLevel, "player")
      if ok then level = value end
    end
    Add(string.format("Storyline level range: %d-%d%s.",
      chain.minLevel, chain.maxLevel or 60,
      level and string.format(" (this character is level %d)", level) or ""))
  end

  if q.startItem then
    Add("Start item: " .. q.startItem
        .. (q.startSource and (". " .. q.startSource) or "."))
  elseif q.kind == "item" or q.kind == "drop" then
    Add("Starts from a found or dropped item, not from a quest-giver NPC.")
  end
  if q.deferUntilAvailable then
    Add("Route: if the start item has not dropped, the saga continues; this quest becomes current once the item is carried or the quest is accepted.")
  end
  if q.kind == "dungeon" then
    Add("Dungeon quest: bring a group and complete the objectives inside "
        .. (q.zone or "the dungeon") .. ".")
  end
  if q.faction then Add("Faction: " .. tostring(q.faction) .. ".") end
  if q.note then Add("Guide note: " .. tostring(q.note)) end
  if #lines == 0 then
    Add("No special start requirement in guide data; speak to "
        .. tostring(q.giver or "the quest giver") .. ".")
  end
  return lines, availability
end

-- QuestLocations(questID) -> { accept=, objective=, objectiveSrc=,
-- turnin= } for storyline quests and catalogued zone side quests.
function ns.QuestLocations(questID)
  local q, _, _, source = ns.LookupQuest(questID)
  if not q then
    return { accept = nil, objective = nil, objectiveSrc = "none",
             turnin = nil }
  end
  local info = RouteInfoFor(q, source)
  local objective, objectiveSrc = nil, "none"
  local obj = info.obj
  if type(obj) == "table" and obj.src ~= "none"
     and type(obj.x) == "number" and type(obj.y) == "number" then
    objective = { name = q.name, giver = obj.name or q.giver,
                  zone = obj.zone or q.zone, map = obj.map or q.map,
                  x = obj.x, y = obj.y }
    objectiveSrc = obj.src or "rxp"
  end
  -- For a quest currently in the log, Blizzard's live objective
  -- position is fresher than any static guide coordinate and makes
  -- the detail pane's Find Objective agree with the route tracker.
  local liveObjective = ns.GetLiveQuestWaypoint
                        and ns.GetLiveQuestWaypoint(questID, q)
  if Pinnable(liveObjective) then
    objective, objectiveSrc = liveObjective, "live"
  end
  return {
    accept = { name = q.name, giver = q.giver, zone = q.zone,
               map = q.map, x = q.x, y = q.y },
    objective = objective, objectiveSrc = objectiveSrc,
    turnin = ns.TurnTarget(q, info),
  }
end

-- Everything the quest-detail pane shows for one quest. Journal
-- text is included only once the page is earned (fully blind
-- before that, exactly like JournalPageView).
function ns.QuestDetail(questID)
  local q, chain, index, source = ns.LookupQuest(questID)
  if not q then
    return { state = "side",
             locations = ns.QuestLocations(questID),
             requirements = {},
             availability = ns.QuestAvailability(nil),
             canPin = { accept = false, objective = false, turnin = false },
             reason = "Quest is not in the story guide catalogue." }
  end
  local info = RouteInfoFor(q, source)
  local loc = ns.QuestLocations(questID)
  local completed = ns.IsCompleted(questID)
  local inLog = (not completed) and ns.IsInLog(questID)
  local ready = inLog and ns.IsReadyForTurnIn
                and ns.IsReadyForTurnIn(questID) or false
  local state
  if completed then state = "done"
  elseif ready then state = "ready"
  elseif inLog then state = "inlog"
  elseif not chain then state = "side"
  else
    local r = ns.ResolveChain(chain)
    state = (r.target and r.target.id == questID) and "next" or "todo"
  end
  local defaultKind
  if completed or ready then defaultKind = "turnin"
  elseif inLog then defaultKind = loc.objective and "objective" or "turnin"
  else defaultKind = "accept" end
  local requirements, availability = ns.QuestRequirements(questID)
  local detail = {
    quest = q, chain = chain, index = index,
    total = chain and #ns.EffectiveQuests(chain) or nil,
    source = source, state = state,
    task = info.task or q.task, hint = info.hint, note = q.note,
    requirements = requirements, availability = availability,
    prerequisites = ns.QuestPrerequisites(questID),
    successor = ns.QuestSuccessor(questID),
    locations = loc, defaultKind = defaultKind,
    canPin = { accept = Pinnable(loc.accept),
               objective = Pinnable(loc.objective),
               turnin = Pinnable(loc.turnin) },
  }
  if completed then
    if source == "side" and q.journal then
      detail.journal = { title = q.name, body = q.journal }
    else
      local e = (ns.JournalEntries or {})[questID]
      if e and e.body and e.body ~= "" then
        detail.journal = { title = e.title or q.name, body = e.body }
      end
    end
  end
  return detail
end

local FIND_REASON = {
  accept = "No recorded quest-giver location in guide data yet.",
  objective = "Objective location not in guide data yet.",
  turnin = "No recorded turn-in location in guide data yet.",
}
local FIND_STEP_KIND = { accept = "ACCEPT", objective = "DO",
                         turnin = "TURN IN" }

-- FindLocation(questID, "accept"|"objective"|"turnin") sets the
-- Waypoint UI in-world pin or native pin and reports honestly.
function ns.FindLocation(questID, kind)
  local q = ns.LookupQuest(questID)
  if not q then
    return { native = false, waypointui = false,
             reason = "Quest is not in the story guide catalogue." }
  end
  local target = ns.QuestLocations(questID)[kind]
  if not Pinnable(target) then
    return { native = false, waypointui = false,
             reason = q.noLocation or FIND_REASON[kind]
                      or "No recorded location in guide data yet." }
  end
  local r = ns.SetWaypoint(target)
  ns.LastPinnedKey = questID .. ":" .. (FIND_STEP_KIND[kind] or kind)
  return { native = r.native, waypointui = r.waypointui, target = target }
end

-- Click replacements for the old skip/goto slash verbs.
function ns.SetChainSkipped(chainId, skipped)
  if not ns.cdb or not chainId then return end
  ns.cdb.skipped = ns.cdb.skipped or {}
  if skipped then
    ns.cdb.skipped[chainId] = true
    if ns.cdb.forcedChain == chainId then ns.cdb.forcedChain = nil end
  else
    ns.cdb.skipped[chainId] = nil
  end
  ns.Refresh()
end

function ns.SetForcedChain(chainId)
  if not ns.cdb then return end
  if chainId and ns.IsSagaReadOnly and ns.IsSagaReadOnly() then return end
  ns.cdb.forcedChain = chainId or nil
  ns.Refresh()
end

------------------------------------------------------------------
-- Zones: one definition of a quest's zone (its authored accept
-- zone, dungeon pseudo-zones folded into their parent), the zones
-- a route passes through, and each zone's main + side catalogue.
-- Main and side are disjoint by construction (main wins ties).
------------------------------------------------------------------
function ns.ZoneOf(quest)
  if not quest or not quest.zone then return nil end
  return (ns.ZoneParent or {})[quest.zone] or quest.zone
end

-- Resolve a zone id / name / UiMapID / record to its arc record.
function ns.ResolveZone(key)
  if type(key) == "table" then return key end
  if key == nil then return nil end
  local arcs = ns.ZoneArcs or {}
  if arcs[key] then return arcs[key] end
  for _, z in ipairs(ns.Zones or {}) do
    if z.id == key or z.name == key or z.map == key then return z end
  end
  if (ns.ZoneSideQuests or {})[key] then
    return { id = tostring(key), name = tostring(key), chains = {},
             sideCharted = true }
  end
  return nil
end

-- Distinct zones over an ordered quest list, first-visit order.
function ns.ZonesForQuests(questIDs)
  EnsureIndex()
  local seen, out = {}, {}
  for _, id in ipairs(questIDs or {}) do
    local e = ns.QuestIndex[id]
    local q = (e and e.quest) or ns.ZoneQuestIndex[id]
    local zn = q and ns.ZoneOf(q)
    if zn and not seen[zn] then
      seen[zn] = true
      out[#out + 1] = ns.ResolveZone(zn) or { id = zn, name = zn }
    end
  end
  return out
end

function ns.ZonesOnRoute()
  return ns.ZonesForQuests(ns.StoryRoute or {})
end

-- ZoneCatalog(zone) -> { main = {quest...}, side = {record...} }.
-- Main follows saga route order, then chain order (covers optional
-- Forever zones outside the saga). Side rows never duplicate main.
function ns.ZoneCatalog(zoneKey)
  EnsureIndex()
  local main, side = {}, {}
  local zone = ns.ResolveZone(zoneKey)
  local zoneName = (zone and zone.name)
                   or (type(zoneKey) == "string" and zoneKey) or nil
  if not zoneName then return { main = main, side = side } end
  local added = {}
  for _, id in ipairs(ns.StoryRoute or {}) do
    local e = ns.QuestIndex[id]
    if e and not added[id] and ns.ZoneOf(e.quest) == zoneName then
      added[id] = true; main[#main + 1] = e.quest
    end
  end
  for _, chain in ipairs(ns.Chains or {}) do
    for _, q in ipairs(ns.EffectiveQuests(chain)) do
      if q.id and not added[q.id] and ns.ZoneOf(q) == zoneName then
        added[q.id] = true; main[#main + 1] = q
      end
    end
  end
  local lists = ns.ZoneSideQuests or {}
  local list = lists[zoneName] or (zone and lists[zone.id])
               or lists[zoneKey]
  -- A side row with a faction shows only to that faction: the faction of the
  -- active saga, else of the player (a Horde Dustwallow list holds no Alliance row).
  local faction = ns.SagaFaction and ns.SagaFaction() or nil
  for _, rec in ipairs(list or {}) do
    if rec.id and ns.IsQuestIncluded(rec) and ns.QuestEligible(rec, faction)
       and not added[rec.id] and not ns.QuestIndex[rec.id] then
      added[rec.id] = true; side[#side + 1] = rec
    end
  end
  return { main = main, side = side }
end

------------------------------------------------------------------
-- Spoiler-gated view models (pure). Directory facts (names, zones,
-- counts) are always visible; narrative (backstory, world, gossip,
-- developments, epilogues) unlocks with progress. Locked fragments
-- contribute nothing - no title, speaker, place or body leak.
------------------------------------------------------------------
local function ChainLore(chain)
  local lore = (ns.StorylineLore or {})[chain.id] or {}
  return { teaser = chain.teaser or lore.teaser,
           backstory = chain.backstory or lore.backstory,
           world = chain.world or lore.world,
           gossip = chain.gossip or lore.gossip or {} }
end

-- OverviewView(chain|chainId) per the tier rules: T0 teaser only,
-- T1 started (+backstory/world/unlocked gossip), T2 once a later
-- gossip entry unlocks, T3 complete (+full summary).
function ns.OverviewView(chain)
  if type(chain) == "string" then chain = FindChainById(chain) end
  if not chain then return { tier = 0, gossip = {} } end
  local lore = ChainLore(chain)
  local r = ns.ResolveChain(chain)
  local started = r.done > 0
  if not started then
    for _, q in ipairs(ns.EffectiveQuests(chain)) do
      if ns.IsInLog(q.id) then started = true; break end
    end
  end
  local tier = 0
  if r.state == "DONE" then tier = 3 elseif started then tier = 1 end
  local gossip = {}
  if tier >= 1 then
    for i, g in ipairs(lore.gossip) do
      local after = g.afterQuestId or g.after
      if after and ns.IsCompleted(after) then
        gossip[#gossip + 1] = { speaker = g.speaker, place = g.place,
                                kind = g.kind, text = g.text }
        if tier == 1 and i > 1 then tier = 2 end
      end
    end
  end
  local view = { tier = tier, teaser = lore.teaser, gossip = gossip,
                 state = r.state, done = r.done, total = r.total }
  if tier >= 1 then
    view.backstory = lore.backstory
    view.world = lore.world
  end
  if tier >= 3 then view.summary = chain.summary end
  if #gossip < #lore.gossip then
    view.lockedNote = "More will be told as the story unfolds."
  end
  return view
end

-- ZoneView(zone): Z0 unvisited (directory only), Z1 visited
-- (+summary and unlocked developments), Z2 every listed storyline
-- complete (+backstory bullets and the zone epilogue).
function ns.ZoneView(zoneKey)
  local zone = ns.ResolveZone(zoneKey)
  local cat = ns.ZoneCatalog(zoneKey)
  if not zone then
    zone = { id = tostring(zoneKey), name = tostring(zoneKey),
             chains = {} }
  end
  local visited = false
  for _, q in ipairs(cat.main) do
    if ns.IsCompleted(q.id) or ns.IsInLog(q.id) then
      visited = true; break
    end
  end
  local complete = #(zone.chains or {}) > 0
  for _, cid in ipairs(zone.chains or {}) do
    local c = FindChainById(cid)
    if not c or ns.ResolveChain(c).state ~= "DONE" then
      complete = false; break
    end
  end
  local tier = complete and 2 or (visited and 1 or 0)
  local view = { zone = zone, tier = tier, main = cat.main,
                 side = cat.side,
                 sideCharted = zone.sideCharted ~= false }
  if tier >= 1 then
    view.summary = zone.summary
    view.developments = {}
    for _, d in ipairs(zone.developments or {}) do
      if ns.IsCompleted(d.afterQuestId or d.after) then
        view.developments[#view.developments + 1] = d.text
      end
    end
  end
  if tier >= 2 then
    view.backstory = zone.backstory
    view.epilogue = (ns.ZoneEpilogues or {})[zone.id] or zone.epilogue
  end
  return view
end

------------------------------------------------------------------
-- Subject APIs: saga / chain / zone treated uniformly so the Hub
-- header, counts, route and journal always agree on scope.
-- subject = "saga" | <chainId> | "zone:<zoneIdOrName>"
--         | { kind = "saga"|"chain"|"zone", id = ... }
------------------------------------------------------------------
local function ParseSubject(subject)
  if type(subject) == "table" then
    return subject.kind or "saga", subject.id
  end
  if not subject or subject == "saga" then return "saga", nil end
  local zoneKey = tostring(subject):match("^zone:(.+)$")
  if zoneKey then return "zone", zoneKey end
  return "chain", subject
end

function ns.SubjectQuestIDs(subject)
  local kind, id = ParseSubject(subject)
  if kind == "chain" then
    local chain = FindChainById(id)
    local out = {}
    for _, q in ipairs(ns.EffectiveQuests(chain)) do
      out[#out + 1] = q.id
    end
    return out
  elseif kind == "zone" then
    local cat = ns.ZoneCatalog(id)
    local out = {}
    for _, q in ipairs(cat.main) do out[#out + 1] = q.id end
    for _, q in ipairs(cat.side) do out[#out + 1] = q.id end
    return out
  end
  return ns.StoryRoute or {}
end

function ns.SubjectCounts(subject)
  local ids = ns.SubjectQuestIDs(subject)
  if ns.QuestCounts then return ns.QuestCounts(ids) end
  local done, total = 0, 0
  for _, id in ipairs(ids) do
    total = total + 1
    local manual = ns.cdb and ns.cdb.routeManual
                   and ns.cdb.routeManual[id .. ":TURN IN"]
    if ns.IsCompleted(id) or manual then done = done + 1 end
  end
  return done, total
end

function ns.SubjectStep(subject)
  local kind, id = ParseSubject(subject)
  if kind == "chain" and ns.GetChainStep then
    return ns.GetChainStep(FindChainById(id))
  elseif kind == "zone" and ns.GetZoneStep then
    return ns.GetZoneStep(id)
  end
  return ns.GetRouteStep and ns.GetRouteStep()
end

------------------------------------------------------------------
-- Events + refresh fan-out
------------------------------------------------------------------
local frame = CreateFrame("Frame", "MainStoryGuideCoreFrame")
function ns.Refresh()
  if ns.UpdateRouteTracker then ns.UpdateRouteTracker(false) end
  if ns.RefreshGuide then ns.RefreshGuide() end
  if ns.JournalCheckUnlocks then ns.JournalCheckUnlocks() end
  if ns.RefreshJournal then ns.RefreshJournal() end
  if ns.RefreshRoute then ns.RefreshRoute() end
  if ns.RefreshHub then ns.RefreshHub() end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    InitDB(); BuildIndex()
    -- The native Story Guide panel is the one primary interface.
    -- Legacy Guide/Journal/Route windows are built lazily only if a
    -- fallback slash command ever needs them; nothing pops up at login.
    if ns.BuildHub then pcall(ns.BuildHub) end
    if ns.InitSystemIntegration then pcall(ns.InitSystemIntegration) end
    if ns.StartRouteTracker then pcall(ns.StartRouteTracker) end
    if ns.InitTags then pcall(ns.InitTags) end
    ns.Refresh()
  elseif event == "PLAYER_LOGIN" then
    -- UnitRace can be empty at ADDON_LOADED. Find the saga again now, and
    -- build the view again if the result is different.
    if ns.GetActiveSaga and ns.GetActiveSaga() ~= ns.ActiveSaga then
      BuildIndex()
    end
    ns.Refresh()
  elseif event == "NAME_PLATE_UNIT_ADDED"
         or event == "NAME_PLATE_UNIT_REMOVED" then
    if ns.UpdateQuestSparkles then pcall(ns.UpdateQuestSparkles) end
  else
    -- Quest completion flags can lag the event by a tick.
    if C_Timer and C_Timer.After then C_Timer.After(0.3, ns.Refresh) else ns.Refresh() end
  end
end)

------------------------------------------------------------------
-- Slash commands: /story /mainstory /msg
------------------------------------------------------------------
local function DumpLogQuests()
  local quests = ns.GetLogQuests()
  wipe(ns.cdb.dump)
  Print("Quest log dump (" .. #quests .. "). Saved to MainStoryGuideCharDB.dump for DB fixes:")
  for _, e in ipairs(quests) do
    local isMain, chain = ns.ClassifyByIDOrName(e.questID, e.title)
    ns.cdb.dump[#ns.cdb.dump + 1] = { id = e.questID, name = e.title }
    Print(string.format("  %d  %s  -> %s", e.questID, e.title,
          isMain and ("MAIN (" .. (chain and chain.name or "story") .. ")")
          or "SIDE"))
  end
end

local function ListChains()
  local _, results = ns.GetActive()
  for _, r in ipairs(results) do
    local c = r.chain
    Print(string.format("[%s] %s (Lv %d-%d) %d/%d%s%s", r.state, c.name,
          c.minLevel or 1, c.maxLevel or 60, r.done, r.total,
          r.skipped and " (skipped)" or "",
          r.target and (" -> next: " .. r.target.name) or ""))
  end
  Print("Open /story and click a storyline to follow it.")
end

local function Slash(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  if cmd == nil or cmd == "" or cmd == "show" then
    if ns.ToggleHub then ns.ToggleHub(true)
    elseif ns.ToggleGuide then ns.ToggleGuide(true) end
  elseif cmd == "hide" then
    if ns.ToggleHub then ns.ToggleHub(false) end
    if ns.ToggleGuide then ns.ToggleGuide(false) end
  elseif cmd == "toggle" then
    if ns.ToggleHub then ns.ToggleHub()
    elseif ns.ToggleGuide then ns.ToggleGuide() end
  elseif cmd == "guide" then
    -- One primary interface: the old compact window command now opens
    -- the native Story Guide panel instead of a second window style.
    if ns.ToggleHub then ns.ToggleHub(rest == "hide" and false or true)
    elseif ns.ToggleGuide then ns.ToggleGuide(rest == "hide" and false or true) end
  elseif cmd == "options" or cmd == "config" or cmd == "settings" then
    if ns.OpenOptions then ns.OpenOptions() end
  elseif cmd == "minimap" then
    ns.db.showMinimapButton = not ns.db.showMinimapButton
    if ns.RefreshMinimapButton then ns.RefreshMinimapButton() end
    Print("Minimap button: " .. (ns.db.showMinimapButton and "ON" or "OFF"))
  elseif cmd == "version" or cmd == "ver" then
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    Print("Forever Quest Chains v" .. tostring(get and get(ns.name, "Version") or "?")
      .. " - quote this in bug reports.")
  elseif cmd == "saga" or cmd == "sagas" then
    if rest == "" then
      local act = ns.GetActiveSaga()
      for _, k in ipairs(ns.SagaOrder) do
        local s = ns.Sagas[k]
        Print(string.format("%s%s (%s)%s", k == act and "> " or "  ", s.name,
          s.faction, ns.SagaHasData(k) and "" or " - coming soon"))
      end
      Print("Use /story saga <Race> to view one, /story saga auto to return to this character's saga.")
    elseif rest:lower() == "auto" then
      ns.SetActiveSaga(nil); Print("Viewing this character's saga: " .. ns.Sagas[ns.GetActiveSaga()].name)
    else
      local key
      for _, k in ipairs(ns.SagaOrder) do
        if k:lower() == rest:lower():gsub("%s+", "") then key = k end
      end
      if key and ns.SetActiveSaga(key) then
        Print("Viewing " .. ns.Sagas[key].name .. (ns.IsSagaReadOnly() and " (read-only)" or ""))
      else Print("No saga data for '" .. rest .. "'. Try /story saga") end
    end
  elseif cmd == "chains" or cmd == "list" then
    ListChains()
  elseif cmd == "goto" then
    for _, c in ipairs(ns.Chains or {}) do
      if c.id == rest then ns.cdb.forcedChain = c.id; ns.Refresh()
        Print("Pinned chain: " .. c.name); return end
    end
    Print("Unknown chain id. Open /story to pick a storyline.")
  elseif cmd == "auto" then
    ns.cdb.forcedChain = nil; ns.Refresh(); Print("Guide back to auto (first unfinished chain).")
  elseif cmd == "skip" then
    local active = ns.GetActive()
    if active then ns.cdb.skipped[active.chain.id] = true
      if ns.cdb.forcedChain == active.chain.id then ns.cdb.forcedChain = nil end
      Print("Skipped: " .. active.chain.name .. " (undo it in /story)"); ns.Refresh() end
  elseif cmd == "unskip" then
    wipe(ns.cdb.skipped); Print("All chains unskipped."); ns.Refresh()
  elseif cmd == "waypoint" or cmd == "wp" then
    local active = ns.GetActive()
    if active and active.target then ns.SetWaypoint(active.target)
    else Print("No active story target.") end
  elseif cmd == "done" or cmd == "progress" or cmd == "checklist" then
    local chain
    for _, c in ipairs(ns.Chains or {}) do if c.id == rest then chain = c end end
    if not chain then local a = ns.GetActive(); chain = a and a.chain end
    if chain then
      for _, l in ipairs((ns.ChainStatusLines(chain))) do Print(l) end
      Print("Legend: [x]=done  [>]=in the quest log  [!]=next/missing link  [ ]=to come.")
    else Print("No chain found.") end
  elseif cmd == "logquest" or cmd == "dump" then
    DumpLogQuests()
  elseif cmd == "check" then
    local id = tonumber(rest)
    if id then Print(id .. ": " .. ns.TagText(id) ..
      " completed=" .. tostring(ns.IsCompleted(id)) .. " inLog=" .. tostring(ns.IsInLog(id)))
    else Print("Give a quest ID number, or open /story and click the quest.") end
  elseif cmd == "gossip" then
    ns.db.gossipTags = not ns.db.gossipTags
    Print("Quest-giver tags: " .. (ns.db.gossipTags and "ON" or "OFF"))
  elseif cmd == "journal" or cmd == "book" or cmd == "diary" then
    if rest == "hide" and ns.ToggleHub then ns.ToggleHub(false)
    elseif ns.ToggleHub then ns.ToggleHub(true, "journal")
    elseif ns.ToggleJournal then ns.ToggleJournal(true) end
  elseif cmd == "route" then
    if rest == "hide" then
      if ns.ToggleHub then ns.ToggleHub(false) end
      if ns.ToggleRoute then ns.ToggleRoute(false) end
    elseif rest == "reset" then
      if ns.RouteResetManual then ns.RouteResetManual() end
      Print("Route manual toggles cleared. The route now reads purely from the quest log.")
    elseif rest == "pin" then
      ns.db.routeAutoWaypoint = not ns.db.routeAutoWaypoint
      Print("Route auto-waypoint: " .. (ns.db.routeAutoWaypoint and "ON" or "OFF"))
      ns.Refresh()
    elseif rest == "waypointui" or rest == "wui" then
      ns.db.useWaypointUI = not (ns.db.useWaypointUI ~= false)
      if not ns.db.useWaypointUI and ns.ClearWaypointUIWaypoint then ns.ClearWaypointUIWaypoint() end
      Print("Waypoint UI navigation: " .. (ns.db.useWaypointUI and "ON" or "OFF")
        .. ((ns.db.useWaypointUI and not WaypointUIAPI) and " (Waypoint UI addon not detected - install WaypointUI and /reload)" or ""))
      ns.Refresh()
    elseif rest == "done" or rest == "toggle" then
      if ns.GetRouteStep and ns.RouteToggleStep then
        local step = ns.GetRouteStep()
        if step then ns.RouteToggleStep(step) else Print("Route complete.") end
      end
    else
      if ns.ToggleHub then ns.ToggleHub(true, "route")
      elseif ns.ToggleRoute then ns.ToggleRoute(true) end
    end
  else
    -- /story is the only command a player needs: anything else just
    -- opens the one menu, where every action is clickable. The old
    -- verbs above remain as undocumented compatibility only.
    if ns.ToggleHub then ns.ToggleHub(true) end
    Print("Everything is in the Story Guide - type /story.")
  end
end

SLASH_MAINSTORYGUIDE1 = "/story"
SLASH_MAINSTORYGUIDE2 = "/mainstory"
SLASH_MAINSTORYGUIDE3 = "/msg"
SlashCmdList["MAINSTORYGUIDE"] = Slash

