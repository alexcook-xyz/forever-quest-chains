-- MainStoryGuide Route: THE linear route through the saga.
-- Every story quest becomes up to three steps: ACCEPT, DO, TURN IN.
-- Steps are DERIVED from live game state on every refresh:
--   quest completed        -> all its steps toggled off (done)
--   quest in log           -> ACCEPT toggled off
--   objectives complete    -> DO toggled off
-- So the route always picks up exactly where you are, whenever you
-- install it or come back to it - no saved position to desync.
-- A step can also be toggled off manually (Mark Done /
-- /story route reset clears manual toggles).
local _, ns = ...

------------------------------------------------------------------
-- Quest-ready helper (guarded the same way as Core's helpers)
------------------------------------------------------------------
function ns.IsReadyForTurnIn(questID)
  if not questID then return false end
  if C_QuestLog and C_QuestLog.ReadyForTurnIn then
    local ok, r = pcall(C_QuestLog.ReadyForTurnIn, questID)
    if ok then return r and true or false end
  end
  if C_QuestLog and C_QuestLog.IsComplete then
    local ok, r = pcall(C_QuestLog.IsComplete, questID)
    if ok then return r and true or false end
  end
  if GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local _, _, _, isHeader, _, isComplete, _, id = GetQuestLogTitle(i)
      if not isHeader and id == questID then return isComplete == 1 end
    end
  end
  return false
end

------------------------------------------------------------------
-- Step derivation (pure logic; unit-tested outside the game)
------------------------------------------------------------------
local function TurnTarget(q, info)
  if ns.TurnTarget then return ns.TurnTarget(q, info) end
  local t = info and info.turn
  if t then
    return { name = q.name, giver = t.name or q.giver, zone = t.zone or q.zone,
             map = t.map or q.map, x = t.x, y = t.y }
  end
  return { name = q.name, giver = q.giver, zone = q.zone,
           map = q.map, x = q.x, y = q.y }
end

local function ManualDone(questID, kind)
  return ns.cdb and ns.cdb.routeManual
         and ns.cdb.routeManual[questID .. ":" .. kind] and true or false
end

function ns.HasItem(itemID)
  if not itemID then return false end
  if C_Item and C_Item.GetItemCount then
    local ok, count = pcall(C_Item.GetItemCount, itemID)
    if ok then return (count or 0) > 0 end
  end
  if GetItemCount then
    local ok, count = pcall(GetItemCount, itemID)
    if ok then return (count or 0) > 0 end
  end
  return false
end

-- Drop-start quests marked deferUntilAvailable never trap the linear
-- route while their start item is missing. They become available the
-- moment the item is carried or the quest enters the log.
function ns.IsStepDeferred(q, completed, inLog)
  return q and q.deferUntilAvailable and not completed and not inLog
         and not ns.HasItem(q.startItemID) and true or false
end

local zonePseudoChains = {}
local function ZonePseudoChain(zone)
  local c = zonePseudoChains[zone]
  if not c then
    c = { id = "zone:" .. (zone or "?"), name = zone or "?",
          quests = {} }
    zonePseudoChains[zone] = c
  end
  return c
end

-- Returns steps, currentIndex (nil when finished), doneCount.
-- Works for any ordered quest list: the master route, one chain, a
-- zone's main quests or its side catalogue (shared derivation, so
-- zone quests get the full route treatment). The DO step pins the
-- objective target when guide data has one; objectives are never
-- silently swapped for the giver.
function ns.BuildStepsFor(questIDs)
  local steps, doneCount = {}, 0
local blockedCache = {}
  for routePos, questID in ipairs(questIDs or {}) do
    local e = ns.QuestIndex and ns.QuestIndex[questID]
    local q, chain, chainIndex, info
    if e then
      q, chain, chainIndex = e.quest, e.chain, e.index
      info = ns.RouteInfoOf(questID) or {}
    else
      local rec = ns.ZoneQuestIndex and ns.ZoneQuestIndex[questID]
      if rec then
        q, chain, chainIndex = rec, ZonePseudoChain(rec.zone), routePos
        info = { task = rec.task, turn = rec.turn, obj = rec.obj }
      end
    end
    if q then
      local completed = ns.IsCompleted(questID)
      local inLog = (not completed) and ns.IsInLog(questID)
local deferred = ns.IsStepDeferred(q, completed, inLog)
      if chain and chain.id then
        if blockedCache[chain.id] == nil then
          local okBQ, cquests = pcall(ns.EffectiveQuests, chain)
          local blist = (okBQ and cquests) or {}
          blockedCache[chain.id] = (ns.BreadcrumbBlockedIDs and ns.BreadcrumbBlockedIDs(blist)) or {}
        end
      end
      local chainBlocked = (chain and chain.id and blockedCache[chain.id]) or {}
      local isBlocked = (not deferred) and q.id and chainBlocked[q.id] and true or false
      -- A deferred quest cannot already be accepted: a spoofed log
      -- state must not flip it to DO/TURN IN. The deferral wins.
      if deferred then inLog = false end
      local ready = inLog and ns.IsReadyForTurnIn(questID)
      local turn = TurnTarget(q, info)
      local itemStart = (info.task and info.task:sub(1, 5) == "This ")
                        or q.kind == "item" or q.kind == "drop"
      local objTarget, objLabel = nil, nil
      local obj = info.obj
      if type(obj) == "table" and obj.src ~= "none"
         and type(obj.x) == "number" and type(obj.y) == "number"
         and type(obj.map) == "number" then
        objTarget = { name = q.name, giver = obj.name or q.giver,
                      zone = obj.zone or q.zone, map = obj.map or q.map,
                      x = obj.x, y = obj.y }
        objLabel = string.format("%s (%s)", obj.name or q.name,
                                 obj.zone or q.zone or "?")
      end

      local defs = {
        { kind = "ACCEPT",
          done = completed or inLog,
          task = (itemStart and info.task) or string.format(
            "Accept '%s' from %s.", q.name, q.giver or "?"),
          target = { name = q.name, giver = q.giver, zone = q.zone,
                     map = q.map, x = q.x, y = q.y },
          targetLabel = string.format("%s (%s)", q.giver or "?", q.zone or "?") },
        { kind = "DO",
          done = completed or ready,
          task = info.task or ("Complete the objectives of '" .. q.name .. "'."),
          target = objTarget,
          targetLabel = objLabel or "See task text / quest log" },
        { kind = "TURN IN",
          done = completed,
          task = string.format("Turn in '%s' to %s.", q.name, turn.giver or "?"),
          target = turn,
          targetLabel = string.format("%s (%s)", turn.giver or "?", turn.zone or "?") },
      }
      for _, d in ipairs(defs) do
        local manual = ManualDone(questID, d.kind)
        local done = d.done or manual
        if done then doneCount = doneCount + 1 end
        steps[#steps + 1] = {
          routePos = routePos, questID = questID, quest = q, chain = chain,
          chainIndex = chainIndex, kind = d.kind, done = done, manual = manual,
          deferred = deferred,
          blocked = isBlocked,
          task = d.task, target = d.target, targetLabel = d.targetLabel,
          key = questID .. ":" .. d.kind,
        }
      end
    end
  end
  local current, deferredCurrent = nil, nil
  for i, s in ipairs(steps) do
    if not s.done then
      if s.deferred then
        if not deferredCurrent then deferredCurrent = i end
      elseif not s.blocked then
        current = i; break
      end
    end
  end
  return steps, current or deferredCurrent, doneCount
end

-- Quest-level progress for display: done, total (quests, not steps).
-- A quest counts done when completed in game, or when its TURN IN
-- step was toggled off by hand.
function ns.QuestCounts(questIDs)
  local done, total = 0, 0
  for _, id in ipairs(questIDs or {}) do
    total = total + 1
    if ns.IsCompleted(id) or ManualDone(id, "TURN IN") then done = done + 1 end
  end
  return done, total
end

function ns.BuildRouteSteps()
  return ns.BuildStepsFor(ns.StoryRoute or {})
end

function ns.GetRouteStep()
  local steps, current, doneCount = ns.BuildRouteSteps()
  -- Pure getter: the background tracker's signature gate owns pin
  -- lifecycle (including clearing it when the route finishes). A
  -- read-only derivation must never delete anyone's waypoint.
  if not current then return nil, nil, #steps, doneCount, steps end
  -- The saga skips through skipped chains: their steps still render
  -- (flagged) and QuestCounts still counts their quests, but the
  -- current step never lands inside one. Chain mode is unaffected.
  local skipped = ns.cdb and ns.cdb.skipped or {}
  local filtered, deferredFiltered = nil, nil
  for i, s in ipairs(steps) do
    s.skipped = (s.chain and skipped[s.chain.id]) and true or false
if not s.done and not s.skipped then
      if s.deferred then
        if not deferredFiltered then deferredFiltered = i end
      elseif not s.blocked and not filtered then
        filtered = i
      end
    end
  end
  current = filtered or deferredFiltered
  return current and steps[current] or nil, current, #steps, doneCount, steps
end

-- Current step for ONE storyline, ignoring the master route.
-- Explicit selection wins over skip; optional chains route over
-- their eligible quests only.
function ns.GetChainStep(chain)
  if not chain then return nil, nil, 0, 0, {} end
  local ids = {}
  for _, q in ipairs(ns.EffectiveQuests(chain)) do ids[#ids + 1] = q.id end
  local steps, current, doneCount = ns.BuildStepsFor(ids)
  return current and steps[current] or nil, current, #steps, doneCount, steps
end

-- Current step over one zone's storyline quests (saga order).
function ns.GetZoneStep(zoneKey)
  local cat = ns.ZoneCatalog and ns.ZoneCatalog(zoneKey)
  local ids = {}
  for _, q in ipairs(cat and cat.main or {}) do ids[#ids + 1] = q.id end
  local steps, current, doneCount = ns.BuildStepsFor(ids)
  return current and steps[current] or nil, current, #steps, doneCount, steps
end

-- Current step over one zone's side catalogue, same derivation.
function ns.GetZoneSideStep(zoneKey)
  local cat = ns.ZoneCatalog and ns.ZoneCatalog(zoneKey)
  local ids = {}
  for _, q in ipairs(cat and cat.side or {}) do ids[#ids + 1] = q.id end
  local steps, current, doneCount = ns.BuildStepsFor(ids)
  return current and steps[current] or nil, current, #steps, doneCount, steps
end

-- Toggle a step off/on by hand (safety valve if detection ever misses).
function ns.RouteToggleStep(step)
  if not step or not ns.cdb then return end
  ns.cdb.routeManual = ns.cdb.routeManual or {}
  if ns.cdb.routeManual[step.key] then
    ns.cdb.routeManual[step.key] = nil
  else
    ns.cdb.routeManual[step.key] = true
  end
  ns.Refresh()
end

function ns.RouteResetManual()
  if ns.cdb then ns.cdb.routeManual = {} end
  ns.Refresh()
end

------------------------------------------------------------------
-- Background route tracker. This is the RestedXP-style always-on
-- part: it derives the current step from live quest state, opens the
-- native wayfinder as soon as a target exists, and advances
-- when ACCEPT -> DO -> TURN IN -> the next quest changes. It does
-- not depend on any window being shown. The ticker
-- only changes that waypoint when the route state meaningfully moves.
------------------------------------------------------------------
local routeTrackerSignature = nil
local routeTrackerOwnsPin = false
local routeTrackerStarted = false
local routeTrackerTicker = nil
local routeTrackerFrame = nil

local function PinnableTarget(target)
  return target and target.map and target.x and target.y and true or false
end

local function RouteTrackerMode()
  if WaypointUIAPI and WaypointUIAPI.Navigation and (not ns.db or ns.db.useWaypointUI ~= false) then
    return "waypointui"
  end
  return "native"
end

-- The one target-resolution rule shared by the background tracker
-- and manual "Find Location" buttons: DO steps prefer Blizzard's
-- live objective waypoint; accepting and turning in use the story
-- data's NPC coordinates.
function ns.GetRouteStepTarget(step)
  if not step then return nil end
  if step.kind == "DO" and ns.GetLiveQuestWaypoint then
    local liveTarget = ns.GetLiveQuestWaypoint(step.questID, step.quest)
    if PinnableTarget(liveTarget) then return liveTarget end
  end
  return step.target
end

local function TargetSignature(step, target)
  local t = target or (step and step.target)
  if not PinnableTarget(t) then return step.key .. "|no-target|" .. RouteTrackerMode() end
  return string.format("%s|%s|%s|%.3f|%.3f", step.key,
    RouteTrackerMode(), tostring(t.map), t.x, t.y)
end

function ns.GetTrackedRouteStep()
  local forced = ns.cdb and ns.cdb.forcedChain or nil
  if forced and ns.SubjectStep then
    local step = ns.SubjectStep(forced)
    if step then return step, forced end
  end
  if ns.GetRouteStep then
    local step = ns.GetRouteStep()
    return step, "saga"
  end
  return nil, "saga"
end

------------------------------------------------------------------
-- Quest NPC sparkles: a gold animated overlay on the nameplate of
-- the one NPC the current tracked step sends you to. Only ACCEPT
-- (the quest giver) and TURN IN (the turn-in NPC) steps have such
-- an NPC; DO steps and item/drop starts never mark anyone. Guide
-- data names carry location suffixes ("Marshal Windsor (BRD
-- cell)") and sometimes colour codes, so names are normalized on
-- both sides before matching against live unit names.
------------------------------------------------------------------
function ns.NormalizeNPCName(name)
  if name == nil then return nil end
  if type(name) ~= "string" then name = tostring(name) end
  local clean = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  clean = clean:gsub("|n", " ")
  clean = clean:gsub("%s*%(.*%)%s*$", "")
  clean = clean:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  return clean
end

-- GetQuestSparkleTarget([step]) -> { kind=, name=, questID=,
-- target= } for the current tracked ACCEPT/TURN IN step, else nil.
-- step = false forces "no step" (internal clear, no derivation).
function ns.GetQuestSparkleTarget(step)
  if step == false then return nil end
  if step == nil then
    if not ns.GetTrackedRouteStep then return nil end
    step = ns.GetTrackedRouteStep()
  end
  if not step or step.done or step.skipped then return nil end
  if step.kind ~= "ACCEPT" and step.kind ~= "TURN IN" then return nil end
  if step.kind == "ACCEPT" then
    -- Mirror BuildStepsFor's itemStart rule: these quests begin
    -- from a found/dropped item, so there is no giver NPC to mark.
    local q = step.quest
    if q and (q.kind == "item" or q.kind == "drop" or q.startItem) then
      return nil
    end
    local info = step.questID and ns.RouteInfoOf(step.questID)
    local task = (info and info.task) or (q and q.task)
    if type(task) == "string" and task:sub(1, 5) == "This " then
      return nil
    end
  end
  local target = step.target
  local raw = (target and target.giver) or step.targetLabel
              or (step.kind == "ACCEPT" and step.quest
                  and step.quest.giver)
  local name = ns.NormalizeNPCName(raw)
  if not name or name == "" or name == "?" or name == "Unknown" then
    return nil
  end
  return { kind = step.kind, name = name, questID = step.questID,
           target = target }
end

local sparkleOverlays = {} -- nameplate frame -> reusable overlay

local function HideSparkleOverlay(overlay)
  if not overlay then return end
  if overlay.msgSparkleAnim then pcall(overlay.msgSparkleAnim.Stop,
                                        overlay.msgSparkleAnim) end
  if overlay.msgSpinAnim then pcall(overlay.msgSpinAnim.Stop,
                                     overlay.msgSpinAnim) end
  if overlay.Hide then pcall(overlay.Hide, overlay) end
end

local function BuildSparkleOverlay(plate)
  local overlay = CreateFrame("Frame", nil, plate)
  overlay:SetSize(64, 64)
  overlay:SetPoint("CENTER", plate, "CENTER", 0, 12)
  overlay:EnableMouse(false)
  if overlay.SetFrameLevel and plate.GetFrameLevel then
    overlay:SetFrameLevel((plate:GetFrameLevel() or 0) + 10)
  end
  local glow = overlay:CreateTexture(nil, "OVERLAY")
  glow:SetSize(64, 64)
  glow:SetPoint("CENTER", overlay, "CENTER")
  glow:SetTexture("Interface\\Cooldown\\ping4")
  glow:SetVertexColor(1, 0.82, 0.1, 0.8)
  glow:SetBlendMode("ADD")
  local star = overlay:CreateTexture(nil, "OVERLAY")
  star:SetSize(42, 42)
  star:SetPoint("CENTER", overlay, "CENTER")
  star:SetTexture("Interface\\Cooldown\\star4")
  star:SetVertexColor(1, 0.85, 0.2, 1)
  star:SetBlendMode("ADD")
  -- Gentle gold pulse; the star slowly spins where texture
  -- animation groups exist (failure just leaves the pulse).
  local pulse = overlay:CreateAnimationGroup()
  local alpha = pulse:CreateAnimation("Alpha")
  alpha:SetFromAlpha(0.35)
  alpha:SetToAlpha(1)
  alpha:SetDuration(0.7)
  if alpha.SetSmoothing then alpha:SetSmoothing("IN_OUT") end
  pulse:SetLooping("BOUNCE")
  overlay.msgSparkleAnim = pulse
  local spinOk, spin = pcall(function()
    local g = star:CreateAnimationGroup()
    local rot = g:CreateAnimation("Rotation")
    rot:SetRadians(6.283185)
    rot:SetDuration(6)
    g:SetLooping("REPEAT")
    return g
  end)
  if spinOk then overlay.msgSpinAnim = spin end
  overlay:Hide()
  return overlay
end

local function ShowSparkleOverlay(plate)
  local overlay = sparkleOverlays[plate]
  if not overlay then
    if not CreateFrame then return end
    local ok, built = pcall(BuildSparkleOverlay, plate)
    if not ok or not built then return end
    overlay = built
    sparkleOverlays[plate] = overlay
  end
  local shown = false
  if overlay.IsShown then
    local ok, r = pcall(overlay.IsShown, overlay)
    shown = ok and r and true or false
  end
  if shown then return end
  if overlay.Show then pcall(overlay.Show, overlay) end
  if overlay.msgSparkleAnim then pcall(overlay.msgSparkleAnim.Play,
                                        overlay.msgSparkleAnim) end
  if overlay.msgSpinAnim then pcall(overlay.msgSpinAnim.Play,
                                     overlay.msgSpinAnim) end
end

local function PlateUnitName(plate)
  -- Blizzard forbids addons from touching secure/protected nameplates.
  -- Those plates are identifiable NPCs we still must not mark.
  if plate.IsForbidden then
    local ok, forbidden = pcall(plate.IsForbidden, plate)
    if ok and forbidden then return nil end
  end
  local unit = plate.namePlateUnitToken
  if not unit and plate.UnitFrame then unit = plate.UnitFrame.unit end
  if not unit then unit = plate.unit end
  if not unit then return nil end
  if UnitIsPlayer then
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if ok and isPlayer then return nil end
  end
  if not UnitName then return nil end
  local ok, name = pcall(UnitName, unit)
  if not ok then return nil end
  return ns.NormalizeNPCName(name)
end

-- UpdateQuestSparkles([step]): mark every visible nameplate whose
-- unit is the current step's NPC and hide every stale overlay.
-- Safe to call every tracker tick: plates that appear later get
-- marked, and a step change (or the setting being off) clears the
-- old mark. Returns the sparkle target (or nil).
function ns.UpdateQuestSparkles(step)
  local sparkle = nil
  if not ns.db or ns.db.questSparkles ~= false then
    sparkle = ns.GetQuestSparkleTarget(step)
  end
  local plates = nil
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local ok, result = pcall(C_NamePlate.GetNamePlates)
    if ok and type(result) == "table" then plates = result end
  end
  if not plates then
    for _, overlay in pairs(sparkleOverlays) do
      HideSparkleOverlay(overlay)
    end
    return sparkle
  end
  local seen = {}
  for _, plate in ipairs(plates) do
    if plate then
      seen[plate] = true
      local match = false
      if sparkle then
        local visible = true
        if plate.IsShown then
          local ok, shown = pcall(plate.IsShown, plate)
          if ok and not shown then visible = false end
        end
        if visible then
          local unitName = PlateUnitName(plate)
          match = unitName ~= nil and unitName ~= ""
                  and (unitName == sparkle.name
                       or unitName:lower() == sparkle.name:lower())
        end
      end
      if match then
        ShowSparkleOverlay(plate)
      elseif sparkleOverlays[plate] then
        HideSparkleOverlay(sparkleOverlays[plate])
      end
    end
  end
  for plate, overlay in pairs(sparkleOverlays) do
    if not seen[plate] then HideSparkleOverlay(overlay) end
  end
  return sparkle
end

-- Quest kill marks: a static raid-skull icon above the nameplate of
-- the one mob the current tracked DO step sends you to kill. Only DO
-- steps whose route data names an objective mob (info.obj.name) mark
-- anyone; without an authored kill name there is no mark. The skull
-- is Blizzard's own raid target art, so it reads as a game marker
-- rather than addon decoration. No group, no privileges, no target
-- changes: it only annotates nameplates you can already see.
-- GetQuestKillTarget([step]) -> { kind=, name=, questID=, target= }
-- for the current tracked DO step, else nil.
-- step = false forces "no step" (internal clear, no derivation).
function ns.GetQuestKillTarget(step)
  if step == false then return nil end
  if step == nil then
    if not ns.GetTrackedRouteStep then return nil end
    step = ns.GetTrackedRouteStep()
  end
  if not step or step.done or step.skipped then return nil end
  if step.kind ~= "DO" then return nil end
  if not step.target then return nil end
  -- The mark must name an authored kill target, never the quest
  -- giver fallback that DO targets carry when obj.name is missing.
  local info = step.questID and ns.RouteInfoOf(step.questID)
  local oname = info and info.obj and info.obj.name
  if type(oname) ~= "string" or oname == "" then
    local rec = step.questID and ns.ZoneQuestIndex
                and ns.ZoneQuestIndex[step.questID]
    local robj = rec and rec.obj
    oname = robj and robj.name
  end
  if type(oname) ~= "string" or oname == "" then return nil end
  local name = ns.NormalizeNPCName(oname)
  if not name or name == "" or name == "?" or name == "Unknown" then
    return nil
  end
  return { kind = "DO", name = name, questID = step.questID,
           target = step.target }
end

local killMarkOverlays = {} -- nameplate frame -> reusable overlay

local function HideKillMarkOverlay(overlay)
  if not overlay then return end
  if overlay.Hide then pcall(overlay.Hide, overlay) end
end

local function BuildKillMarkOverlay(plate)
  local overlay = CreateFrame("Frame", nil, plate)
  overlay:SetSize(30, 30)
  overlay:SetPoint("BOTTOM", plate, "TOP", 0, 2)
  overlay:EnableMouse(false)
  if overlay.SetFrameLevel and plate.GetFrameLevel then
    overlay:SetFrameLevel((plate:GetFrameLevel() or 0) + 10)
  end
  local skull = overlay:CreateTexture(nil, "OVERLAY")
  skull:SetSize(28, 28)
  skull:SetPoint("CENTER", overlay, "CENTER")
  skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
  overlay:Hide()
  return overlay
end

local function ShowKillMarkOverlay(plate)
  local overlay = killMarkOverlays[plate]
  if not overlay then
    if not CreateFrame then return end
    local ok, built = pcall(BuildKillMarkOverlay, plate)
    if not ok or not built then return end
    overlay = built
    killMarkOverlays[plate] = overlay
  end
  local shown = false
  if overlay.IsShown then
    local ok, r = pcall(overlay.IsShown, overlay)
    shown = ok and r and true or false
  end
  if shown then return end
  if overlay.Show then pcall(overlay.Show, overlay) end
end

-- UpdateQuestKillMarks([step]): mark every visible nameplate whose
-- unit is the current step's kill target and hide every stale mark.
-- Mirrors UpdateQuestSparkles and refreshes on the same path.
-- Returns the kill target (or nil).
function ns.UpdateQuestKillMarks(step)
  local kill = nil
  if not ns.db or ns.db.questKillMarks ~= false then
    kill = ns.GetQuestKillTarget(step)
  end
  local plates = nil
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local ok, result = pcall(C_NamePlate.GetNamePlates)
    if ok and type(result) == "table" then plates = result end
  end
  if not plates then
    for _, overlay in pairs(killMarkOverlays) do
      HideKillMarkOverlay(overlay)
    end
    return kill
  end
  local seen = {}
  for _, plate in ipairs(plates) do
    if plate then
      seen[plate] = true
      local match = false
      if kill then
        local visible = true
        if plate.IsShown then
          local ok, shown = pcall(plate.IsShown, plate)
          if ok and not shown then visible = false end
        end
        if visible then
          local unitName = PlateUnitName(plate)
          match = unitName ~= nil and unitName ~= ""
                  and (unitName == kill.name
                       or unitName:lower() == kill.name:lower())
        end
      end
      if match then
        ShowKillMarkOverlay(plate)
      elseif killMarkOverlays[plate] then
        HideKillMarkOverlay(killMarkOverlays[plate])
      end
    end
  end
  for plate, overlay in pairs(killMarkOverlays) do
    if not seen[plate] then HideKillMarkOverlay(overlay) end
  end
  return kill
end

-- TrackerPinPresent(): is the pin this tracker believes it owns
-- still on the map? Returns "ours" (provably ours), "foreign"
-- (provably someone else's pin), "gone" (no pin at all), or
-- "unknown" (no API to tell: keep the old believe-it behavior).
-- Only confident signals act; anything ambiguous keeps prior behavior.
local function TrackerPinPresent()
  local W = WaypointUIAPI and WaypointUIAPI.Navigation
  if RouteTrackerMode() == "waypointui" and W then
    local tracked, flagged
    if type(W.IsUserNavigationTracked) == "function" then
      local ok, v = pcall(W.IsUserNavigationTracked)
      if ok then tracked = v end
    end
    if type(W.IsUserNavigationFlagged) == "function" then
      local ok, v = pcall(W.IsUserNavigationFlagged,
                          "MainStoryGuide_Waypoint")
      if ok then flagged = v end
    end
    if flagged == true then return "ours" end
    if tracked == true and flagged == false then return "foreign" end
    if tracked == false then
      -- Nothing tracked: a native pin now would be the player's own.
      if C_Map and type(C_Map.GetUserWaypoint) == "function" then
        local ok, pin = pcall(C_Map.GetUserWaypoint)
        if ok then
          if pin ~= nil then return "foreign" end
          return "gone"
        end
      end
      return "unknown"
    end
    return "unknown"
  end
  if C_Map and type(C_Map.GetUserWaypoint) == "function" then
    local ok, pin = pcall(C_Map.GetUserWaypoint)
    if ok then
      if pin ~= nil then return "present" end
      return "gone"
    end
  end
  return "unknown"
end

-- PlayerFarFrom(target): true only when the player's position is
-- known and clearly away from the target. Guards the lost-pin
-- resync so arrival never flickers: standing at the target needs
-- no pin. Any doubt returns false (prior behavior).
local function PlayerFarFrom(target)
  if not target or type(target.map) ~= "number" then return false end
  if not (C_Map and type(C_Map.GetPlayerMapPosition) == "function") then
    return false
  end
  local ok, x, y = pcall(C_Map.GetPlayerMapPosition, target.map, "player")
  if not ok or type(x) ~= "number" or type(y) ~= "number" then
    return false
  end
  if x >= 0 and x <= 1 then x = x * 100 end
  if y >= 0 and y <= 1 then y = y * 100 end
  if type(target.x) ~= "number" or type(target.y) ~= "number" then
    return false
  end
  local dx, dy = x - target.x, y - target.y
  return (dx * dx + dy * dy) > 4
end

-- One routing-unavailable notice per session: a tracker that can
-- never pin must say so instead of failing silently every tick.
local routePinNoSystemWarned = false
local function WarnRoutingUnavailable()
  if routePinNoSystemWarned then return end
  routePinNoSystemWarned = true
  if ns.Print then
    ns.Print("In-world routing needs the WaypointUI addon enabled " ..
             "(this client has no map pin API of its own).")
  end
end

function ns.UpdateRouteTracker(force)
  if ns.IsSagaReadOnly and ns.IsSagaReadOnly() then
    if routeTrackerOwnsPin and ns.ClearWaypoint then ns.ClearWaypoint() end
    routeTrackerOwnsPin = false
    routeTrackerSignature = "readonly"
    ns.RouteTrackerSignature = routeTrackerSignature
    return nil, routeTrackerSignature, "readonly", nil
  end
  if ns.db and ns.db.routeAutoWaypoint == false then
    if routeTrackerSignature ~= "disabled" then
      if routeTrackerOwnsPin and ns.ClearWaypoint then ns.ClearWaypoint() end
      routeTrackerOwnsPin = false
      routeTrackerSignature = "disabled"
      ns.RouteTrackerSignature = routeTrackerSignature
    end
    ns.UpdateQuestSparkles()
    ns.UpdateQuestKillMarks()
    return nil, routeTrackerSignature, "disabled", nil
  end

  local step, subject = ns.GetTrackedRouteStep()
  if not step then
    if (force or routeTrackerSignature ~= "none") and routeTrackerOwnsPin
       and ns.ClearWaypoint then
      ns.ClearWaypoint()
    end
    routeTrackerOwnsPin = false
    routeTrackerSignature = "none"
    ns.RouteTrackerSignature = routeTrackerSignature
    ns.UpdateQuestSparkles(false)
    ns.UpdateQuestKillMarks(false)
    return nil, routeTrackerSignature, "complete", subject
  end

  local effectiveTarget = ns.GetRouteStepTarget(step)
  step.trackerTarget = effectiveTarget
  local signature = TargetSignature(step, effectiveTarget)
  if not PinnableTarget(effectiveTarget) then
    if (force or routeTrackerSignature ~= signature) and routeTrackerOwnsPin
       and ns.ClearWaypoint then
      ns.ClearWaypoint()
    end
    routeTrackerOwnsPin = false
    routeTrackerSignature = signature
    ns.RouteTrackerSignature = routeTrackerSignature
    ns.UpdateQuestSparkles(step)
    ns.UpdateQuestKillMarks(step)
    return step, signature, "no-target", subject
  end

  if not force and routeTrackerSignature == signature and routeTrackerOwnsPin then
    local presence = TrackerPinPresent()
    if presence == "foreign" then
      -- Another pin owns the map now: drop ownership (never stomp
      -- it) and let later ticks retry once it clears.
      routeTrackerOwnsPin = false
      routeTrackerSignature = nil
      ns.RouteTrackerSignature = routeTrackerSignature
      ns.UpdateQuestSparkles(step)
      ns.UpdateQuestKillMarks(step)
      return step, signature, "unchanged", subject
    end
    if presence ~= "gone" or not PlayerFarFrom(effectiveTarget) then
      ns.UpdateQuestSparkles(step)
      ns.UpdateQuestKillMarks(step)
      return step, signature, "unchanged", subject
    end
    -- The pin was lost without a step change and the player is far
    -- from the target: fall through and set it again.
  elseif TrackerPinPresent() == "foreign" then
    -- Fresh step, but the map already carries someone else's pin:
    -- yield (the native setter already refuses these) and retry later.
    routeTrackerOwnsPin = false
    routeTrackerSignature = nil
    ns.RouteTrackerSignature = routeTrackerSignature
    ns.UpdateQuestSparkles(step)
    ns.UpdateQuestKillMarks(step)
    return step, signature, "unchanged", subject
  end
  if not ns.SetWaypoint and not ns.SetTrackedWaypoint then
    ns.UpdateQuestSparkles(step)
    ns.UpdateQuestKillMarks(step)
    return step, signature, "unavailable", subject
  end

  local result
  if ns.SetTrackedWaypoint then
    result = ns.SetTrackedWaypoint(effectiveTarget)
  else
    result = ns.SetWaypoint(effectiveTarget, { quiet = true })
  end
  routeTrackerOwnsPin = result and (result.native or result.waypointui) and true or false
  if not routeTrackerOwnsPin and RouteTrackerMode() == "native"
     and not (C_Map and type(C_Map.SetUserWaypoint) == "function") then
    WarnRoutingUnavailable()
  end
  routeTrackerSignature = routeTrackerOwnsPin and signature or nil
  ns.RouteTrackerSignature = routeTrackerSignature
  ns.UpdateQuestSparkles(step)
  ns.UpdateQuestKillMarks(step)
  return step, signature,
         (routeTrackerOwnsPin and "pinned" or "unavailable"), subject
end

function ns.StartRouteTracker()
  if routeTrackerStarted then
    ns.UpdateRouteTracker(true)
    return true
  end
  routeTrackerStarted = true
  ns.UpdateRouteTracker(true)

  if C_Timer and C_Timer.NewTicker then
    local ok, ticker = pcall(C_Timer.NewTicker, 1, function()
      ns.UpdateRouteTracker(false)
    end)
    if ok then
      routeTrackerTicker = ticker
      ns.RouteTrackerTicker = ticker
      return true
    end
  end

  if CreateFrame then
    routeTrackerFrame = CreateFrame("Frame", "MainStoryGuideRouteTrackerFrame")
    local elapsed = 0
    routeTrackerFrame:SetScript("OnUpdate", function(_, dt)
      elapsed = elapsed + (dt or 0)
      if elapsed >= 1 then
        elapsed = 0
        ns.UpdateRouteTracker(false)
      end
    end)
    return true
  end
  return false
end

------------------------------------------------------------------
-- UI: compact follow window (RestedXP-style current step)
------------------------------------------------------------------
local f, headFS, stepFS, listFS, bar, barText
local KIND_COLOR = {
  ["ACCEPT"]  = "|cff1eff00",
  ["DO"]      = "|cffffcc00",
  ["TURN IN"] = "|cff7fd4ff",
}

function ns.RefreshRoute()
  if not f or not f:IsShown() then return end
  local step, idx, total, doneCount, steps = ns.GetRouteStep()
  local qDone, qTotal = ns.QuestCounts(ns.StoryRoute or {})

  bar:SetMinMaxValues(0, math.max(qTotal, 1))
  bar:SetValue(qDone)
  barText:SetText(string.format("%d / %d quests done", qDone, qTotal))

  if not step then
    headFS:SetText("|cffffcc00The Human storyline is complete.|r")
    stepFS:SetText("Every step of the route is toggled off.\nRead how it ends in the Journal tab (/story).")
    listFS:SetText("")
    return
  end

  local levelNote = ""
  local lvl = (UnitLevel and UnitLevel("player")) or 1
  if step.chain.minLevel and lvl < step.chain.minLevel - 2 then
    levelNote = string.format(
      "\n|cffff4040This chapter begins around level %d - adventure elsewhere, the route will wait.|r",
      step.chain.minLevel)
  end

  headFS:SetText(string.format("%sQUEST %d/%d: %s|r\n|cffffffff%s|r |cff9d9d9d(%s %d/%d)|r",
    KIND_COLOR[step.kind] or "", step.routePos or 0, qTotal, step.kind,
    step.quest.name, step.chain.name, step.chainIndex, #step.chain.quests))

  stepFS:SetText(step.task
    .. "\n|cffbbbbbbWhere: " .. (step.targetLabel or "?")
    .. ((step.target and step.target.x and step.target.y)
        and string.format(" (%.1f, %.1f)", step.target.x, step.target.y) or "")
    .. "|r" .. levelNote
    .. (step.manual and "\n|cff9d9d9d(toggled by hand)|r" or ""))

  -- Previous steps toggled off + upcoming steps, story order.
  local lines = {}
  for i = math.max(1, idx - 2), idx - 1 do
    local s = steps[i]
    lines[#lines + 1] = string.format("|cff666666[x] %s: %s|r", s.kind, s.quest.name)
  end
  lines[#lines + 1] = string.format("|cffffffff[>] %s: %s|r", step.kind, step.quest.name)
  for i = idx + 1, math.min(#steps, idx + 4) do
    local s = steps[i]
    lines[#lines + 1] = string.format("|cff9d9d9d[ ] %s: %s|r", s.kind, s.quest.name)
  end
  listFS:SetText(table.concat(lines, "\n"))

  -- Automatic pinning is owned by the background route tracker;
  -- this retired window renders only and never moves the arrow.
end

local function MakeButton(parent, text, w, x, y, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 20); b:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
  b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

function ns.BuildRouteFrame()
  if f then return end
  f = CreateFrame("Frame", "MainStoryGuideRouteFrame", UIParent, "BackdropTemplate")
  f:SetSize(340, 270)
  f:SetPoint("CENTER", UIParent, "CENTER", -420, 120)
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })

  local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  t:SetText("Story Route")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  headFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  headFS:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
  headFS:SetWidth(312); headFS:SetJustifyH("LEFT")

  bar = CreateFrame("StatusBar", nil, f)
  bar:SetSize(312, 14)
  bar:SetPoint("TOPLEFT", headFS, "BOTTOMLEFT", 0, -24)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.2, 0.8, 0.2)
  bar:SetMinMaxValues(0, 1); bar:SetValue(0)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0, 0, 0, 0.6)
  barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  barText:SetPoint("CENTER", bar, "CENTER")

  stepFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  stepFS:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -8)
  stepFS:SetWidth(312); stepFS:SetJustifyH("LEFT"); stepFS:SetSpacing(2)

  listFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listFS:SetPoint("TOPLEFT", stepFS, "BOTTOMLEFT", 0, -10)
  listFS:SetWidth(312); listFS:SetJustifyH("LEFT"); listFS:SetSpacing(1)

  MakeButton(f, "Waypoint", 90, 12, 10, function()
    local step = ns.GetRouteStep()
    local target = step and ns.GetRouteStepTarget(step)
    if target then ns.SetWaypoint(target)
    elseif step then ns.Print(step.task) end
  end)
  MakeButton(f, "Mark Done", 90, 106, 10, function()
    local step = ns.GetRouteStep()
    if step then ns.RouteToggleStep(step) end
  end)
  MakeButton(f, "Journal", 80, 200, 10, function()
    if ns.ToggleJournal then ns.ToggleJournal(true) end
  end)
  MakeButton(f, "Pin", 44, 284, 10, function()
    if ns.db then
      ns.db.routeAutoWaypoint = not ns.db.routeAutoWaypoint
      ns.Print("Route auto-waypoint: " .. (ns.db.routeAutoWaypoint and "ON" or "OFF"))
      ns.Refresh()
    end
  end)

  f:Hide()
end

function ns.ToggleRoute(show)
  if not f then ns.BuildRouteFrame() end
  if show == nil then f:SetShown(not f:IsShown())
  else f:SetShown(show and true or false) end
  if f:IsShown() then ns.RefreshRoute() end
end

-- RETIRED separate route window (superseded by the Hub Route
-- tab): the builder above is unreachable through these public
-- entry points, which now open the one Story Guide panel instead.
ns.BuildRouteFrame = function() end
ns.RefreshRoute = function() end
ns.ToggleRoute = function(show)
  if ns.ToggleHub then ns.ToggleHub(show, "route") end
end
