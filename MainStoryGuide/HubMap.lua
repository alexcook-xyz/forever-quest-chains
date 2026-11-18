-- MainStoryGuide Hub, simple list look (AllTheThings-style).
-- One small window: a title bar with the saga progress, then a plain tree.
-- A storyline is a row; click it to open or close its quest chain. A quest
-- row has a check mark when done, an arrow when current, and a click makes
-- that storyline the followed one (the waypoint follows). Right click a
-- quest to mark it done or undo the mark, a storyline to skip or resume it.
-- The Side Quests view lists the side quests of each zone in chains (issue #2).
-- The data comes from HubChooser.lua / HubStory.lua; this file only paints.
local _, ns = ...

local FRAME_W, FRAME_H = 380, 520
local ROW_H = 22
local INDENT = 16

-- A quest that is still ahead shows as "???" (spoiler-free, issue #91).
-- Set to true to list every quest name in the chain.
local SHOW_AHEAD = true

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.55, 0.55, 0.55 }
local GREEN = { 0.25, 0.85, 0.25 }
local WHITE = { 1, 1, 1 }

local ICON_DONE = "Interface\\Buttons\\UI-CheckBox-Check"
local ICON_NOW = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local ICON_MINUS = "Interface\\Buttons\\UI-MinusButton-Up"

local shell = {}
local state = { built = false, failed = false, open = {}, openInit = false,
                selectedId = nil, entries = {}, mode = "story",
                openZone = {}, pinKey = nil, zoneFocus = nil,
                openSideZone = {}, openSideChain = {}, sidePin = nil }
local pool = {}

------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------
local function UseFont(fs, name, fallback)
  if _G[name] and pcall(fs.SetFontObject, fs, name) then return end
  if fallback then pcall(fs.SetFontObject, fs, fallback) end
end

local function Color(fs, c)
  if fs and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3]) end
end

local function Esc(value)
  local escape = ns.EscapeUIText
  if escape and value ~= nil then return escape(value) end
  return value
end

-- Objective-tracker state of a quest (quest log watch list).
local function LogIndex(qid)
  local f = _G.GetQuestLogIndexByID
  if not f then return nil end
  local ok, idx = pcall(f, qid)
  return ok and idx and idx > 0 and idx or nil
end

local function IsTracked(qid)
  if not (qid and ns.IsInLog(qid)) then return false end
  local api = _G.C_QuestLog
  if api and api.GetQuestWatchType then
    local ok, v = pcall(api.GetQuestWatchType, qid)
    if ok then return v ~= nil end
  end
  local idx = LogIndex(qid)
  if idx and _G.IsQuestWatched then
    local ok, v = pcall(_G.IsQuestWatched, idx)
    return ok and v and true or false
  end
  return false
end

local function SetTracked(qid, on)
  local api = _G.C_QuestLog
  if api and (on and api.AddQuestWatch or api.RemoveQuestWatch) then
    pcall(on and api.AddQuestWatch or api.RemoveQuestWatch, qid)
    return
  end
  local idx, fn = LogIndex(qid), on and _G.AddQuestWatch or _G.RemoveQuestWatch
  if idx and fn then pcall(fn, idx) end
end

local function NewButton(parent, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  return b
end

------------------------------------------------------------------
-- Frame shell
------------------------------------------------------------------
local SHELL_TEMPLATES = { "BasicFrameTemplateWithInset", "ButtonFrameTemplate" }

local function CreateShell()
  local frame
  for _, template in ipairs(SHELL_TEMPLATES) do
    local ok, created = pcall(CreateFrame, "Frame", "MainStoryGuideMapFrame",
                              UIParent, template)
    if ok and created then frame = created; break end
  end
  if not frame then
    frame = CreateFrame("Frame", "MainStoryGuideMapFrame", UIParent, "BackdropTemplate")
    if frame.SetBackdrop then
      frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    end
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() ns.ToggleHub(false) end)
  end
  if frame.CloseButton then
    frame.CloseButton:SetScript("OnClick", function() ns.ToggleHub(false) end)
  end
  frame:SetSize(FRAME_W, FRAME_H)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 24)
  frame:SetMovable(true); frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  if frame.SetToplevel then frame:SetToplevel(true) end
  if UISpecialFrames then tinsert(UISpecialFrames, "MainStoryGuideMapFrame") end
  frame:SetScript("OnShow", function() ns.RefreshHub() end)
  return frame
end

local function SetShellTitle(text)
  local frame = shell.frame
  if frame.SetTitle then
    frame:SetTitle(text)
  elseif frame.TitleText then
    frame.TitleText:SetText(text)
  end
end

------------------------------------------------------------------
-- List rows
------------------------------------------------------------------
local function NewRow()
  local b = CreateFrame("Button", nil, shell.content)
  b:SetSize(FRAME_W - 44, ROW_H)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.08)
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints(); b.sel:SetColorTexture(1, 0.82, 0, 0.14)
  b.arrow = b:CreateTexture(nil, "ARTWORK")
  b.arrow:SetSize(14, 14)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.text = b:CreateFontString(nil, "OVERLAY")
  UseFont(b.text, "GameFontNormalLeft", "GameFontNormal")
  b.text:SetJustifyH("LEFT")
  if b.text.SetWordWrap then b.text:SetWordWrap(false) end
  b.meta = b:CreateFontString(nil, "OVERLAY")
  UseFont(b.meta, "GameFontHighlightSmall", "GameFontNormalSmall")
  b.meta:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.meta:SetJustifyH("RIGHT")
  b.level = b:CreateFontString(nil, "OVERLAY")
  UseFont(b.level, "GameFontHighlightSmall", "GameFontNormalSmall")
  b.level:SetPoint("RIGHT", b, "RIGHT", -64, 0)
  b.level:SetJustifyH("RIGHT")
  b:SetScript("OnClick", function(self, button)
    if self.onClick then self.onClick(self, button) end
  end)
  b:SetScript("OnEnter", function(self)
    if GameTooltip and self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

-- row: { depth, name, tone, icon, arrow, meta, selected, tip, onClick }
local function PaintRow(index, y, row)
  local r = pool[index]
  if not r then r = NewRow(); pool[index] = r end
  local x = 4 + row.depth * INDENT
  r.arrow:ClearAllPoints()
  r.arrow:SetPoint("LEFT", r, "LEFT", x, 0)
  if row.arrow then
    r.arrow:SetTexture(row.arrow == "open" and ICON_MINUS or ICON_PLUS)
    r.arrow:Show()
  else
    r.arrow:Hide()
  end
  r.icon:ClearAllPoints()
  r.icon:SetPoint("LEFT", r, "LEFT", x + 16, 0)
  if row.icon then r.icon:SetTexture(row.icon); r.icon:Show() else r.icon:Hide() end
  r.text:ClearAllPoints()
  r.text:SetPoint("LEFT", r, "LEFT", x + 36, 0)
  r.text:SetPoint("RIGHT", r, "RIGHT", -112, 0)
  r.text:SetText(row.name or "")
  Color(r.text, row.tone or GOLD)
  r.meta:SetText(row.meta or "")
  Color(r.meta, row.metaTone or WHITE)
  r.level:SetText(row.level or "")
  Color(r.level, row.levelTone or GREY)
  r.sel:SetShown(row.selected and true or false)
  r.tip, r.onClick = row.tip, row.onClick
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", shell.content, "TOPLEFT", 0, -y)
  r:Show()
end

------------------------------------------------------------------
-- Rows of the tree
------------------------------------------------------------------
local function FindEntry(id)
  for _, e in ipairs(state.entries) do
    if e.id == id then return e end
  end
  return nil
end

local function QuestRowsOf(chain, followed)
  local rows = {}
  local step, _, _, _, steps = ns.GetChainStep(chain)
  local seen, allDone = {}, {}
  for _, s in ipairs(steps or {}) do
    local key = s.routePos or s.questID
    allDone[key] = (allDone[key] ~= false) and s.done and true or false
  end
  for _, s in ipairs(steps or {}) do
    local key = s.routePos or s.questID
    if not seen[key] then
      seen[key] = true
      local row = { depth = 1, name = Esc(s.quest.name), step = s, chainId = chain.id }
      if ns.IsCompleted(s.questID) or allDone[key] then
        row.icon, row.tone, row.tip = ICON_DONE, GREEN, "Completed"
      elseif step and s.routePos == step.routePos then
        row.icon, row.tone, row.tip = ICON_NOW, GOLD, Esc(step.task)
        row.current = true
      elseif s.skipped then
        row.tone, row.tip = GREY, "Skipped"
      elseif step and not SHOW_AHEAD then
        row.name, row.tone, row.locked = "???", GREY, true
      else
        row.tone = GREY
      end
      row.tracked = IsTracked(s.questID)
      if row.tracked then row.meta, row.metaTone = "Tracked", GOLD end
      row.selected = (followed and row.current or row.tracked) and true or false
      rows[#rows + 1] = row
    end
  end
  return rows
end

local function ToggleOpen(id)
  state.open[id] = not state.open[id]
  ns.RefreshHub()
end

------------------------------------------------------------------
-- Zones view: every zone with its story and side quests
------------------------------------------------------------------
-- Zones of the saga in route order, then zones that only have side quests.
local function ZoneList()
  local out, seen = {}, {}
  local function add(name)
    if name and not seen[name] then
      seen[name] = true
      local cat = ns.ZoneCatalog(name)
      if #cat.main + #cat.side > 0 then
        out[#out + 1] = { name = name, main = cat.main, side = cat.side }
      end
    end
  end
  for _, z in ipairs(ns.ZonesOnRoute() or {}) do add(z.name or z.id) end
  local extra = {}
  for name in pairs(ns.ZoneSideQuests or {}) do extra[#extra + 1] = name end
  table.sort(extra)
  for _, name in ipairs(extra) do add(name) end
  return out
end

-- The pin target of a zone quest: the turn-in NPC while the quest is in the
-- log (when the data has one), else the quest giver. Nil without coordinates.
local function ZoneQuestTarget(q)
  local t
  if ns.IsInLog(q.id) and q.turn then
    t = ns.TurnTarget(q, { turn = q.turn })
  else
    t = { name = q.name, giver = q.giver, zone = q.zone, map = q.map, x = q.x, y = q.y }
  end
  if type(t.map) == "number" and type(t.x) == "number" and type(t.y) == "number" then
    return t
  end
  return nil
end

-- Follow a side chain (key) or release the follow (nil); the pin is set on the next paint.
local function SetSideFollow(key)
  if ns.cdb then ns.cdb.sideFollow = key end
  state.sidePin = nil
end

-- side (optional): { chain = chain|nil } adds the Side Quests view items:
-- follow or unfollow the chain, jump to the zone view, mark done or undo.
local function ZoneQuestMenu(q, side)
  local items = {}
  local key = "z:" .. tostring(q.id)
  local readOnly = ns.IsSagaReadOnly and ns.IsSagaReadOnly()
  if side and side.chain and not readOnly then
    if ns.cdb and ns.cdb.sideFollow == side.chain.key then
      items[#items + 1] = { text = "Unfollow chain", func = function()
        SetSideFollow(nil)
        ns.ClearWaypoint(); state.pinKey = nil; ns.RefreshHub()
      end }
    else
      items[#items + 1] = { text = "Follow this chain", func = function()
        SetSideFollow(side.chain.key); ns.RefreshHub()
      end }
    end
  end
  if state.pinKey == key then
    items[#items + 1] = { text = "Remove waypoint", func = function()
      ns.ClearWaypoint(); state.pinKey = nil; ns.RefreshHub()
    end }
  else
    local target = ZoneQuestTarget(q)
    if target and not readOnly then
      local who = target.giver or "quest giver"
      items[#items + 1] = { text = "Set waypoint: " .. Esc(who), func = function()
        ns.SetWaypoint(target, { force = true,
          title = Esc(q.name) .. " (" .. Esc(who) .. ")" })
        state.pinKey = key
      end }
    end
  end
  if ns.IsInLog(q.id) then
    local on = IsTracked(q.id)
    items[#items + 1] = { text = on and "Untrack quest" or "Track quest", func = function()
      SetTracked(q.id, not on); ns.RefreshHub()
    end }
  end
  if side then
    if q.zone then
      items[#items + 1] = { text = "Show zone quests: " .. Esc(q.zone), func = function()
        state.mode, state.zoneFocus = "zones", q.zone
        state.openZone[q.zone] = true
        ns.RefreshHub()
      end }
    end
    items[#items + 1] = { text = "Mark Done / Undo Mark", func = function()
      ns.RouteToggleStep({ key = tostring(q.id) .. ":TURN IN" }); ns.RefreshHub()
    end }
  end
  if #items == 0 then
    items[1] = { text = "No recorded location", func = function() end }
  end
  return items
end

local function ZoneQuestRow(q, depth)
  local done = ns.IsCompleted(q.id)
  local inLog = ns.IsInLog(q.id)
  local tracked = IsTracked(q.id)
  local row = { depth = depth, name = Esc(q.name),
    level = q.reqlevel and tostring(q.reqlevel) or nil, levelTone = GREY,
    selected = tracked,
    onClick = function() ns.MapHubMenu(shell.frame, ZoneQuestMenu(q)) end }
  if done then
    row.icon, row.tone = ICON_DONE, GREEN
  elseif inLog then
    row.icon, row.tone = ICON_NOW, GOLD
  else
    row.tone = WHITE
  end
  if tracked then row.meta, row.metaTone = "Tracked", GOLD end
  return row
end

local function PaintZones(level)
  local zones = ZoneList()
  -- A zone picked from a quest menu comes first, once.
  local focus = state.zoneFocus
  state.zoneFocus = nil
  if focus then
    for i, z in ipairs(zones) do
      if z.name == focus then table.remove(zones, i); table.insert(zones, 1, z); break end
    end
  end
  local y, count = 2, 0
  local function put(row)
    count = count + 1
    PaintRow(count, y, row)
    y = y + ROW_H
  end
  for _, z in ipairs(zones) do
    local done, total, lo, hi = 0, 0, nil, nil
    for _, list in ipairs({ z.main, z.side }) do
      for _, q in ipairs(list) do
        total = total + 1
        if ns.IsCompleted(q.id) then done = done + 1 end
        local r = q.reqlevel
        if r and r > 0 then
          lo = (not lo or r < lo) and r or lo
          hi = (not hi or r > hi) and r or hi
        end
      end
    end
    local isOpen = state.openZone[z.name] and true or false
    local levelText, levelTone
    if lo then
      levelText = (lo == hi) and tostring(lo) or (lo .. "-" .. hi)
      levelTone = level < lo and { 1, 0.35, 0.35 } or (level > hi and GREY or GREEN)
    end
    put({ depth = 0, name = Esc(z.name), tone = (done >= total) and GREEN or GOLD,
      arrow = isOpen and "open" or "closed", level = levelText, levelTone = levelTone,
      meta = string.format("%d / %d", done, total),
      metaTone = (done >= total) and GREEN or WHITE,
      onClick = function()
        state.openZone[z.name] = not state.openZone[z.name]
        ns.RefreshHub()
      end })
    if isOpen then
      for _, part in ipairs({ { "Story quests", z.main }, { "Side quests", z.side } }) do
        if #part[2] > 0 then
          local pd = 0
          for _, q in ipairs(part[2]) do if ns.IsCompleted(q.id) then pd = pd + 1 end end
          put({ depth = 1, name = part[1], tone = GREY,
                meta = string.format("%d / %d", pd, #part[2]) })
          for _, q in ipairs(part[2]) do put(ZoneQuestRow(q, 2)) end
        end
      end
    end
  end
  for i = count + 1, #pool do pool[i]:Hide() end
  shell.content:SetHeight(math.max(y + 8, 1))
end

------------------------------------------------------------------
-- Side Quests view: the side quests of each zone, grouped in chains
------------------------------------------------------------------
-- A side quest is done in the game or by hand (the same mark as a route quest).
local function SideDone(id)
  if ns.IsCompleted(id) then return true end
  local manual = ns.cdb and ns.cdb.routeManual
  return manual and manual[tostring(id) .. ":TURN IN"] and true or false
end

-- Zones with side quests for this faction, lowest level first.
local function SideZones()
  local names = {}
  for name in pairs(ns.ZoneSideQuests or {}) do names[#names + 1] = name end
  table.sort(names)
  local out = {}
  for _, name in ipairs(names) do
    local list = ns.ZoneCatalog(name).side
    if #list > 0 then
      local done, total, lo, hi = ns.SideSummary(list, SideDone)
      out[#out + 1] = { name = name, chains = ns.SideChains(list),
        done = done, total = total, lo = lo, hi = hi }
    end
  end
  table.sort(out, function(a, b)
    local x, y = a.lo or 999, b.lo or 999
    if x ~= y then return x < y end
    return a.name < b.name
  end)
  return out
end

local function FindSideChain(zones, key)
  for _, z in ipairs(zones) do
    for _, c in ipairs(z.chains) do
      if c.key == key then return c end
    end
  end
  return nil
end

-- The followed chain keeps its waypoint on the current quest. A finished
-- chain releases the follow, like a finished storyline.
local function SyncSideFollow(zones)
  local key = ns.cdb and ns.cdb.sideFollow
  if type(key) ~= "string" then return end
  local chain = FindSideChain(zones, key)
  if not chain then return end
  local cur = ns.SideChainCurrent(chain, SideDone)
  if not cur then
    SetSideFollow(nil)
    return
  end
  if ns.IsSagaReadOnly and ns.IsSagaReadOnly() then return end
  -- The target moves from the giver to the turn-in NPC once the quest is in the log.
  local pin = tostring(cur.id) .. (ns.IsInLog(cur.id) and ":log" or ":new")
  if state.sidePin == pin then return end
  state.sidePin = pin
  local target = ZoneQuestTarget(cur)
  if target then
    ns.SetWaypoint(target, { force = true, quiet = true,
      title = Esc(cur.name) .. " (" .. Esc(target.giver or "quest giver") .. ")" })
    state.pinKey = "z:" .. tostring(cur.id)
  elseif state.pinKey then
    -- No recorded location: do not leave the pin of an earlier quest.
    ns.ClearWaypoint(); state.pinKey = nil
  end
end

-- One explicit pin at a time: following a storyline releases the followed side chain.
local function FollowStoryline(chainId)
  SetSideFollow(nil)
  ns.SetForcedChainSoft(chainId)
end

local function SideQuestRow(q, depth, chain, current)
  local done = SideDone(q.id)
  local tracked = IsTracked(q.id)
  local row = { depth = depth, name = Esc(q.name),
    level = q.reqlevel and tostring(q.reqlevel) or nil, levelTone = GREY,
    selected = tracked,
    onClick = function(_, button)
      if chain and button ~= "RightButton" then
        if ns.cdb and not (ns.IsSagaReadOnly and ns.IsSagaReadOnly()) then
          SetSideFollow(chain.key); ns.RefreshHub()
        end
      else
        ns.MapHubMenu(shell.frame, ZoneQuestMenu(q, { chain = chain }))
      end
    end }
  if done then
    row.icon, row.tone = ICON_DONE, GREEN
  elseif (current and current.id == q.id) or (not chain and ns.IsInLog(q.id)) then
    row.icon, row.tone = ICON_NOW, GOLD
  else
    row.tone = chain and GREY or WHITE
  end
  if tracked then row.meta, row.metaTone = "Tracked", GOLD end
  return row
end

local function PaintSide(level, zones)
  local followKey = ns.cdb and ns.cdb.sideFollow
  local y, count = 2, 0
  local function put(row)
    count = count + 1
    PaintRow(count, y, row)
    y = y + ROW_H
  end
  for _, z in ipairs(zones) do
    local isOpen = state.openSideZone[z.name] and true or false
    local levelText, levelTone
    if z.lo then
      levelText = (z.lo == z.hi) and tostring(z.lo) or (z.lo .. "-" .. z.hi)
      levelTone = level < z.lo and { 1, 0.35, 0.35 } or (level > z.hi and GREY or GREEN)
    end
    put({ depth = 0, name = Esc(z.name), tone = (z.done >= z.total) and GREEN or GOLD,
      arrow = isOpen and "open" or "closed", level = levelText, levelTone = levelTone,
      meta = string.format("%d / %d", z.done, z.total),
      metaTone = (z.done >= z.total) and GREEN or WHITE,
      onClick = function()
        state.openSideZone[z.name] = not state.openSideZone[z.name]
        ns.RefreshHub()
      end })
    if isOpen then
      for _, chain in ipairs(z.chains) do
        if #chain.quests == 1 then
          put(SideQuestRow(chain.quests[1], 1, nil, nil))
        else
          local done = ns.SideSummary(chain.quests, SideDone)
          local complete = done >= #chain.quests
          local chainOpen = state.openSideChain[chain.key] and true or false
          local current = ns.SideChainCurrent(chain, SideDone)
          put({ depth = 1, name = Esc(chain.quests[1].name),
            tone = complete and GREEN or GOLD,
            arrow = chainOpen and "open" or "closed",
            meta = string.format("%d / %d", done, #chain.quests),
            metaTone = complete and GREEN or WHITE,
            selected = followKey == chain.key,
            onClick = function(_, button)
              if button == "RightButton" and current then
                ns.MapHubMenu(shell.frame, ZoneQuestMenu(current, { chain = chain }))
              else
                state.openSideChain[chain.key] = not state.openSideChain[chain.key]
                ns.RefreshHub()
              end
            end })
          if chainOpen then
            for _, q in ipairs(chain.quests) do put(SideQuestRow(q, 2, chain, current)) end
          end
        end
      end
    end
  end
  for i = count + 1, #pool do pool[i]:Hide() end
  shell.content:SetHeight(math.max(y + 8, 1))
end

local function Paint()
  local saga = ns.Sagas[ns.GetActiveSaga()] or { name = "Saga" }
  local done, total = ns.QuestCounts(ns.StoryRoute or {})
  done, total = done or 0, total or 0
  local level = UnitLevel("player") or 1
  local readOnly = ns.IsSagaReadOnly() and true or false
  local nowId = ns.NowChainId()
  local followed = ns.FollowedChain()
  local entries = ns.ChooserEntries()
  state.entries = entries

  SetShellTitle(saga.name or "Saga")
  local pct = total > 0 and math.floor(done * 100 / total) or 0
  shell.summary:SetText(string.format("Story quests   %d / %d  (%d%%)", done, total, pct))
  Color(shell.summary, done >= total and total > 0 and GREEN or GOLD)
  shell.saga:SetText(ns.SagaPickerButtonText(saga.name))
  local zonesMode = state.mode == "zones"
  local sideMode = state.mode == "side"
  shell.mode:SetText(zonesMode and "Storylines" or "Zones")
  shell.side:SetText(sideMode and "Storylines" or "Side Quests")
  if sideMode or (ns.cdb and ns.cdb.sideFollow) then
    local sideZones = SideZones()
    SyncSideFollow(sideZones)
    if sideMode then
      SetShellTitle((saga.name or "Saga") .. " - Side Quests")
      return PaintSide(level, sideZones)
    end
  end
  if zonesMode then
    SetShellTitle((saga.name or "Saga") .. " - Zones")
    return PaintZones(level)
  end

  -- First paint: open the storyline that plays now (or the one picked).
  local sel = ns.HubSel or {}
  if not state.openInit then
    state.openInit = true
    local first = sel.choice or nowId
    if first then state.open[first] = true end
  elseif sel.choice and state.lastChoice ~= sel.choice then
    state.open[sel.choice] = true
  end
  state.lastChoice = sel.choice

  local y, count = 2, 0
  for _, e in ipairs(entries) do
    local isOpen = state.open[e.id] and true or false
    local tone = GOLD
    if e.state == "DONE" then tone = GREEN
    elseif ns.ChooserDimmed(e, level) or e.skipped then tone = GREY end
    count = count + 1
    -- Recommended level range of the storyline; hidden when the data has none.
    local lo, hi = e.minLevel or 1, e.maxLevel or 60
    local levelText, levelTone
    if not (lo <= 1 and hi >= 60) then
      levelText = (lo == hi) and tostring(lo) or (lo .. "-" .. hi)
      if level < lo then levelTone = { 1, 0.35, 0.35 }
      elseif level > hi then levelTone = GREY
      else levelTone = GREEN end
    end
    PaintRow(count, y, {
      level = levelText, levelTone = levelTone,
      depth = 0, name = Esc(e.name), tone = tone, arrow = isOpen and "open" or "closed",
      meta = string.format("%d / %d", e.done, e.total),
      metaTone = e.state == "DONE" and GREEN or WHITE,
      selected = followed and followed.id == e.id,
      tip = e.skipped and "Skipped storyline (right click to resume)" or nil,
      onClick = function(_, button)
        if button == "RightButton" then
          local label = ns.ChooserMenuLabel(e, readOnly)
          if label then
            ns.MapHubMenu(shell.frame, { { text = label, func = function()
              ns.SetChainSkipped(e.id, not e.skipped); ns.RefreshHub()
            end } })
          end
        else
          ToggleOpen(e.id)
        end
      end })
    y = y + ROW_H
    if isOpen then
      local chain = ns.FindChain(e.id)
      local isFollowed = followed and followed.id == e.id
      for _, row in ipairs(chain and QuestRowsOf(chain, isFollowed) or {}) do
        local step = row.step
        row.onClick = function(_, button)
          if row.locked then return end
          if button == "RightButton" then
            ns.MapHubMenu(shell.frame, ns.MapHubQuestMenu(step, row.chainId))
          elseif not readOnly then
            FollowStoryline(row.chainId)
            ns.RefreshHub()
          end
        end
        count = count + 1
        PaintRow(count, y, row)
        y = y + ROW_H
      end
    end
  end
  for i = count + 1, #pool do pool[i]:Hide() end
  shell.content:SetHeight(math.max(y + 8, 1))
end

------------------------------------------------------------------
-- Menus
------------------------------------------------------------------
-- Right-click items of a quest row: follow its storyline (waypoint and the
-- sparkle on the quest giver), pin the giver, track it, mark it done.
function ns.MapHubQuestMenu(step, chainId)
  local items = {}
  local qid = step.questID
  local readOnly = ns.IsSagaReadOnly and ns.IsSagaReadOnly()
  if not readOnly then
    local followed = ns.FollowedChain()
    if followed and followed.id == chainId then
      items[#items + 1] = { text = "Unfollow storyline", func = function()
        ns.SetForcedChainSoft(nil)
        ns.ClearWaypoint()
        state.pinKey = nil
        ns.RefreshHub()
      end }
    else
      items[#items + 1] = { text = "Follow this storyline", func = function()
        FollowStoryline(chainId); ns.RefreshHub()
      end }
    end
    if state.pinKey == step.key then
      items[#items + 1] = { text = "Remove waypoint", func = function()
        ns.ClearWaypoint()
        state.pinKey = nil
        ns.RefreshHub()
      end }
    else
      local target = ns.GetRouteStepTarget and ns.GetRouteStepTarget(step)
      if target and target.map and target.x and target.y then
        local who = target.giver or (step.quest and step.quest.giver) or "quest giver"
        items[#items + 1] = { text = "Set waypoint: " .. Esc(who), func = function()
          -- A menu click is explicit: it replaces any pin and names it after the quest.
          local qname = step.quest and step.quest.name or target.name
          ns.SetWaypoint(target, { force = true,
            title = qname and (Esc(qname) .. " (" .. Esc(who) .. ")") or nil })
          state.pinKey = step.key
        end }
      end
    end
  end
  if qid and ns.IsInLog(qid) then
    local on = IsTracked(qid)
    items[#items + 1] = { text = on and "Untrack quest" or "Track quest", func = function()
      SetTracked(qid, not on)
      ns.RefreshHub()
    end }
  end
  local zoneName = ns.ZoneOf and step.quest and ns.ZoneOf(step.quest)
  if zoneName then
    items[#items + 1] = { text = "Show zone quests: " .. Esc(zoneName), func = function()
      state.mode, state.zoneFocus = "zones", zoneName
      state.openZone[zoneName] = true
      ns.RefreshHub()
    end }
  end
  items[#items + 1] = { text = "Mark Done / Undo Mark", func = function()
    ns.RouteToggleStep(step); ns.RefreshHub()
  end }
  return items
end

-- items: { { text, func, checked } }; anchor opens under the owner.
function ns.MapHubMenu(owner, items, anchor)
  local menuUtil = _G.MenuUtil
  if menuUtil and menuUtil.CreateContextMenu then
    local ok = pcall(menuUtil.CreateContextMenu, owner, function(_, root)
      for _, item in ipairs(items) do
        if item.checked ~= nil and root.CreateRadio then
          root:CreateRadio(item.text, function() return item.checked end, item.func)
        else
          root:CreateButton(item.text, item.func)
        end
      end
    end)
    if ok then return end
  end
  local init, add, toggle, create = _G.UIDropDownMenu_Initialize,
    _G.UIDropDownMenu_AddButton, _G.ToggleDropDownMenu, _G.UIDropDownMenu_CreateInfo
  if not (init and add and toggle and create) then return end
  if not shell.menu then
    shell.menu = CreateFrame("Frame", "MainStoryGuideRowMenu", UIParent,
                             "UIDropDownMenuTemplate")
  end
  pcall(init, shell.menu, function()
    for _, item in ipairs(items) do
      local info = create()
      info.text, info.func = item.text, item.func
      info.notCheckable = item.checked == nil
      info.checked = item.checked
      add(info)
    end
  end, "MENU")
  pcall(toggle, 1, nil, shell.menu, anchor and owner or "cursor", 0, 0)
end

-- Saga picker: pick the race storyline to play.
function ns.MapHubSagaMenu(owner)
  local entries = ns.SagaPickerEntries(ns.SagaOrder, ns.Sagas, ns.SagaHasData,
                                       ns.GetActiveSaga(), ns.GetPlayerRace())
  local items = {}
  for _, e in ipairs(entries) do
    items[#items + 1] = { text = ns.SagaPickerLabel(e), checked = e.active,
      func = function()
        if ns.SetActiveSaga(e.key) then
          state.openInit = false
          ns.RefreshHub()
        end
      end }
  end
  ns.MapHubMenu(owner, items, true)
end

------------------------------------------------------------------
-- Entry points used by Hub.lua and Sagas.lua
------------------------------------------------------------------
function ns.HubGoHome() ns.RefreshHub() end

function ns.MapHubRefresh()
  if not state.built then return end
  Paint()
end

local function Build()
  local frame = CreateShell()
  shell.frame = frame

  shell.summary = frame:CreateFontString(nil, "OVERLAY")
  UseFont(shell.summary, "GameFontNormal", "GameFontNormal")
  shell.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)

  shell.saga = NewButton(frame, 150, 20)
  shell.saga:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -52)
  shell.saga:SetScript("OnClick", function(self) ns.MapHubSagaMenu(self) end)

  -- Switch between the storyline list, the zone list and the side quest list.
  shell.mode = NewButton(frame, 86, 20)
  shell.mode:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -52)
  shell.mode:SetScript("OnClick", function()
    state.mode = state.mode == "zones" and "story" or "zones"
    ns.RefreshHub()
  end)
  shell.side = NewButton(frame, 100, 20)
  shell.side:SetPoint("LEFT", shell.mode, "RIGHT", 4, 0)
  shell.side:SetScript("OnClick", function()
    state.mode = state.mode == "side" and "story" or "side"
    ns.RefreshHub()
  end)

  local scroll
  local ok, created = pcall(CreateFrame, "ScrollFrame", nil, frame, "ScrollFrameTemplate")
  if ok and created then
    scroll = created
  else
    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  end
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -78)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(FRAME_W - 44, 1)
  scroll:SetScrollChild(content)
  shell.scroll, shell.content = scroll, content

  -- Keep the "Tracked" highlight in step with the objective tracker.
  pcall(frame.RegisterEvent, frame, "QUEST_WATCH_LIST_CHANGED")
  pcall(frame.RegisterEvent, frame, "QUEST_LOG_UPDATE")
  frame:SetScript("OnEvent", function(self)
    if self:IsShown() then ns.RefreshHub() end
  end)

  frame:Hide()
  state.built = true
end

-- Returns the frame, or nil when the build failed.
function ns.MapHubBuild()
  if state.built then return shell.frame end
  if state.failed then return nil end
  local ok, err = pcall(Build)
  if not ok then
    state.failed = true
    state.built = false
    if shell.frame then shell.frame:Hide() end
    if ns.Print then ns.Print("Hub frame error: " .. tostring(err)) end
    return nil
  end
  return shell.frame
end

function ns.MapHubIsShown()
  return state.built and shell.frame:IsShown() and true or false
end

function ns.MapHubSetShown(show)
  if state.built then shell.frame:SetShown(show and true or false) end
end

function ns.MapHubFrame()
  return state.built and shell.frame or nil
end
