-- MainStoryGuide Journal: a story book that writes itself as you play.
-- Finishing a story quest writes its page; finishing a chain writes
-- its epilogue. Locked pages reveal NOTHING (fully blind): no title,
-- no quest name, no giver. Chapter names stay hidden until the first
-- page of that chapter is written.
local _, ns = ...

local ROMAN = { string.char(73), "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                "XI", "XII", "XIII", "XIV", "XV" }
local LOCKED_BODY = "This page is still blank.\n\nSome stories can only be written by walking them."

------------------------------------------------------------------
-- Pure logic (unit-tested outside the game; no UI calls in here)
------------------------------------------------------------------
function ns.JournalQuestUnlocked(quest)
  return ns.IsCompleted(quest and quest.id) and true or false
end

function ns.JournalEpilogueUnlocked(chain)
  local r = ns.ResolveChain(chain)
  return r.state == "DONE"
end

local function LorePagesFor(chain)
  if chain.lorePages then return chain.lorePages end
  local lore = (ns.StorylineLore or {})[chain.id]
  return (lore and lore.lorePages) or {}
end

-- The composed book for one chapter: quest pages in storyline
-- order, each followed by the lore pages anchored after that
-- quest, then the epilogue. A lore page unlocks when its anchor
-- quest is completed; before that it is fully blind. Optional
-- chains compose over their eligible quests only, so class- or
-- faction-exclusive pages never block a chapter.
-- Page descriptors: { kind=, quest=, questIndex=, lore=,
--                     afterQuestId=, key= }
function ns.JournalPagesForChain(chain)
  local pages = {}
  local quests = ns.EffectiveQuests(chain)
  local byAfter = {}
  for i, lp in ipairs(LorePagesFor(chain)) do
    local after = lp.afterQuestId or lp.after
    if after then
      local t = byAfter[after]
      if not t then t = {}; byAfter[after] = t end
      t[#t + 1] = { lore = lp, ordinal = i }
    end
  end
  for qi, q in ipairs(quests) do
    pages[#pages + 1] = { kind = "quest", quest = q,
                          questIndex = qi, key = q.id }
    for _, e in ipairs(byAfter[q.id] or {}) do
      pages[#pages + 1] = {
        kind = "lore", lore = e.lore, afterQuestId = q.id,
        key = "lore:" .. chain.id .. ":" .. q.id .. ":" .. e.ordinal }
    end
  end
  pages[#pages + 1] = { kind = "epilogue",
                        key = "epilogue:" .. chain.id }
  return pages
end

function ns.JournalPageCount(chain)
  return #ns.JournalPagesForChain(chain)
end

-- Whether one composed page has been written yet.
local function PageUnlocked(chain, desc)
  if desc.kind == "quest" then return ns.JournalQuestUnlocked(desc.quest) end
  if desc.kind == "lore" then return ns.IsCompleted(desc.afterQuestId) end
  return ns.JournalEpilogueUnlocked(chain)
end
ns.JournalPageUnlocked = PageUnlocked

-- pages = quests + anchored lore pages + 1 epilogue.
-- Returns written, total.
function ns.JournalChapterProgress(chain)
  local pages = ns.JournalPagesForChain(chain)
  local written = 0
  for _, desc in ipairs(pages) do
    if PageUnlocked(chain, desc) then written = written + 1 end
  end
  return written, #pages
end

-- What the reader may see for (chain, page) over the composed
-- book. Locked pages return placeholders ONLY - never data from
-- the entry (no title, speaker, quest name or giver).
function ns.JournalPageView(chain, page)
  local pages = ns.JournalPagesForChain(chain)
  local total = #pages
  if page < 1 then page = 1 end
  if page > total then page = total end
  local desc = pages[page]
  if not PageUnlocked(chain, desc) then
    return { locked = true, title = "???", body = LOCKED_BODY,
             page = page, total = total, kind = desc.kind,
             key = desc.key }
  end
  if desc.kind == "quest" then
    local q = desc.quest
    local e = (ns.JournalEntries or {})[q.id] or {}
    local n = #ns.EffectiveQuests(chain)
    return { locked = false, title = e.title or q.name,
             body = (e.body and e.body ~= "" and e.body) or LOCKED_BODY,
             questName = q.name, giver = q.giver, zone = q.zone,
             questID = q.id,
             step = desc.questIndex, chainTotal = n,
             page = page, total = total, kind = "quest", key = q.id }
  elseif desc.kind == "lore" then
    return { locked = false, title = desc.lore.title or "Lore",
             body = desc.lore.body or "",
             page = page, total = total, kind = "lore",
             key = desc.key, afterQuestId = desc.afterQuestId }
  end
  local e = (ns.JournalEpilogues or {})[chain.id] or {}
  return { locked = false, title = e.title or "Epilogue",
           body = (e.body and e.body ~= "" and e.body) or LOCKED_BODY,
           page = page, total = total, kind = "epilogue",
           key = desc.key }
end

-- Chapter heading the reader may see. Blind until 1 page is written.
function ns.JournalChapterHeading(chain, chainIndex)
  local written, total = ns.JournalChapterProgress(chain)
  -- A class chain is a side group, not a numbered chapter (issue #41).
  local label = "Chapter " .. (ROMAN[chainIndex] or tostring(chainIndex))
  if chain.classSpecific == true then label = "Class Chapter" end
  if written == 0 then
    return string.format("%s - ??? (%d/%d pages written)",
                         label, written, total)
  end
  return string.format("%s - %s (%d/%d pages written)",
                       label, chain.name, written, total)
end

-- Total unread (written but never viewed) pages, lore included.
function ns.JournalUnreadCount()
  if not ns.cdb or not ns.cdb.journalSeen then return 0 end
  local n = 0
  for _, chain in ipairs(ns.Chains or {}) do
    for _, desc in ipairs(ns.JournalPagesForChain(chain)) do
      if PageUnlocked(chain, desc)
         and not ns.cdb.journalSeen[desc.key] then n = n + 1 end
    end
  end
  return n
end

-- First unread composed-page index in a chapter, or nil.
function ns.JournalFirstUnreadPage(chain)
  for p = 1, ns.JournalPageCount(chain) do
    if ns.JournalIsUnread(ns.JournalPageView(chain, p)) then return p end
  end
  return nil
end

function ns.JournalIsUnread(view)
  return view and not view.locked and ns.cdb and ns.cdb.journalSeen
         and not ns.cdb.journalSeen[view.key] or false
end

-- Detect newly written pages (quest, lore and epilogue). First run
-- seeds silently (no flood for quests finished before the journal
-- existed). At most one chat line per refresh; optional Forever
-- pages are counted for the unread badge but never announced.
-- The first run waits until the saga is known (issue #37). While
-- UnitRace is empty at ADDON_LOADED, the view is the Human fallback,
-- and a seed of that view leaves the real saga pages unseeded.
function ns.JournalCheckUnlocks()
  if not ns.cdb or not ns.cdb.journalSeen then return end
  local first = not ns.cdb.journalInit
  if first and not ns.SagaKnown() then return end
  local announced = false
  for _, chain in ipairs(ns.Chains or {}) do
    for _, desc in ipairs(ns.JournalPagesForChain(chain)) do
      if PageUnlocked(chain, desc) then
        if first then
          ns.cdb.journalSeen[desc.key] = true
          ns.cdb.journalAnnounced[desc.key] = true
        elseif not ns.cdb.journalAnnounced[desc.key] then
          ns.cdb.journalAnnounced[desc.key] = true
          if not ns.IsSideChain(chain) then announced = true end
        end
      end
    end
  end
  ns.cdb.journalInit = true
  if announced then
    ns.Print("The story grows: new pages await in the journal. Open /story to read them.")
  end
end

-- The journal book for one zone, built with the same shared
-- unlock/blindness rules: main quest pages, side quest pages and
-- the zone epilogue. Returns blind-safe page views in order.
function ns.ZoneJournalPages(zoneKey)
  local views = {}
  local cat = ns.ZoneCatalog and ns.ZoneCatalog(zoneKey)
  local zone = ns.ResolveZone and ns.ResolveZone(zoneKey)
  if not cat then return views end
  for _, q in ipairs(cat.main) do
    if ns.JournalQuestUnlocked(q) then
      local e = (ns.JournalEntries or {})[q.id] or {}
      views[#views + 1] = { locked = false,
        title = e.title or q.name,
        body = (e.body and e.body ~= "" and e.body) or LOCKED_BODY,
        questName = q.name, giver = q.giver, zone = q.zone,
        questID = q.id, kind = "quest", key = q.id }
    else
      views[#views + 1] = { locked = true, title = "???",
        body = LOCKED_BODY, questID = q.id, kind = "quest",
        key = q.id }
    end
  end
  for _, rec in ipairs(cat.side) do
    if ns.IsCompleted(rec.id) then
      views[#views + 1] = { locked = false, title = rec.name,
        body = rec.journal or LOCKED_BODY,
        questName = rec.name, giver = rec.giver, zone = rec.zone,
        questID = rec.id, kind = "side", key = "side:" .. rec.id }
    else
      views[#views + 1] = { locked = true, title = "???",
        body = LOCKED_BODY, questID = rec.id, kind = "side",
        key = "side:" .. rec.id }
    end
  end
  local zoneId = (zone and zone.id) or tostring(zoneKey)
  local zview = ns.ZoneView and ns.ZoneView(zoneKey)
  if zview and zview.tier >= 2 and zview.epilogue then
    views[#views + 1] = { locked = false,
      title = zview.epilogue.title or "Epilogue",
      body = zview.epilogue.body or "",
      kind = "epilogue", key = "zoneepilogue:" .. zoneId }
  else
    views[#views + 1] = { locked = true, title = "???",
      body = LOCKED_BODY, kind = "epilogue",
      key = "zoneepilogue:" .. zoneId }
  end
  for i, v in ipairs(views) do v.page = i; v.total = #views end
  return views
end

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local f, headFS, titleFS, metaFS, bodyFS, listButtons = nil, nil, nil, nil, nil, {}
local sel = { chain = 1, page = 1 }
local MAX_LIST = 18

local function ListLabel(chain, page, selected)
  local v = ns.JournalPageView(chain, page)
  local prefix = selected and "|cffffffff>|r " or "  "
  if v.locked then
    local what = (v.kind == "epilogue") and "??? (chapter ending)" or "???"
    return prefix .. "|cff666666" .. what .. "|r"
  end
  local mark = ns.JournalIsUnread(v) and " |cffffcc00(new)|r" or ""
  local color = (v.kind == "epilogue") and "|cffffcc00" or "|cff1eff00"
  local title = (ns.EscapeUIText and ns.EscapeUIText(v.title or "?")) or "?"
  return prefix .. color .. title .. "|r" .. mark
end

-- First unread page in the book, else first unwritten chapter start.
local function FindOpenTarget()
  for ci, chain in ipairs(ns.Chains or {}) do
    for p = 1, ns.JournalPageCount(chain) do
      if ns.JournalIsUnread(ns.JournalPageView(chain, p)) then
        return ci, p
      end
    end
  end
  return nil, nil
end

function ns.RefreshJournal()
  if not f or not f:IsShown() then return end
  local chains = ns.Chains or {}
  if #chains == 0 then headFS:SetText("No chapters loaded."); return end
  if sel.chain < 1 then sel.chain = 1 end
  if sel.chain > #chains then sel.chain = #chains end
  local chain = chains[sel.chain]
  local total = ns.JournalPageCount(chain)
  if sel.page < 1 then sel.page = 1 end
  if sel.page > total then sel.page = total end

  headFS:SetText(ns.JournalChapterHeading(chain, sel.chain))

  for i = 1, MAX_LIST do
    local b = listButtons[i]
    if i <= total then
      b:Show()
      b.fs:SetText(ListLabel(chain, i, i == sel.page))
    else
      b:Hide()
    end
  end

  local v = ns.JournalPageView(chain, sel.page)
  local safeTitle = (ns.EscapeUIText and ns.EscapeUIText(v.title or "???"))
                    or "???"
  titleFS:SetText(safeTitle)
  if v.locked then
    metaFS:SetText(string.format("Page %d of %d", v.page, v.total))
  elseif v.kind == "epilogue" then
    metaFS:SetText(string.format("Page %d of %d - chapter complete", v.page, v.total))
  else
    metaFS:SetText(string.format("Page %d of %d - %s (step %d of %d)",
      v.page, v.total, v.questName or "?", v.step or 0, v.chainTotal or 0))
  end
  bodyFS:SetText(v.body or "")

  -- Reading a page marks it read (after rendering, so it showed as new).
  if not v.locked and ns.cdb and ns.cdb.journalSeen then
    ns.cdb.journalSeen[v.key] = true
  end
end

local function MakeButton(parent, text, w, x, y, onClick, anchor)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 20)
  b:SetPoint(anchor or "BOTTOMLEFT", parent, anchor or "BOTTOMLEFT", x, y)
  b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

function ns.BuildJournal()
  if f then return end
  f = CreateFrame("Frame", "MainStoryGuideJournalFrame", UIParent, "BackdropTemplate")
  f:SetSize(640, 430)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
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
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  t:SetText("Story Journal")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  headFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  headFS:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
  headFS:SetWidth(600); headFS:SetJustifyH("LEFT")

  -- Clickable page list (left pane)
  for i = 1, MAX_LIST do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(230, 16)
    b:SetPoint("TOPLEFT", headFS, "BOTTOMLEFT", 0, -8 - (i - 1) * 17)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", b, "LEFT", 2, 0)
    fs:SetWidth(226); fs:SetJustifyH("LEFT")
    b.fs = fs
    local idx = i
    b:SetScript("OnClick", function() sel.page = idx; ns.RefreshJournal() end)
    listButtons[i] = b
  end

  -- Reading pane (right)
  titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleFS:SetPoint("TOPLEFT", headFS, "BOTTOMLEFT", 246, -8)
  titleFS:SetWidth(360); titleFS:SetJustifyH("LEFT")

  metaFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  metaFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -4)
  metaFS:SetWidth(360); metaFS:SetJustifyH("LEFT")

  bodyFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  bodyFS:SetPoint("TOPLEFT", metaFS, "BOTTOMLEFT", 0, -10)
  bodyFS:SetWidth(360); bodyFS:SetJustifyH("LEFT")
  bodyFS:SetJustifyV("TOP"); bodyFS:SetSpacing(4)

  MakeButton(f, "< Chapter", 100, 14, 10, function()
    sel.chain = sel.chain - 1; sel.page = 1; ns.RefreshJournal()
  end)
  MakeButton(f, "Chapter >", 100, 120, 10, function()
    sel.chain = sel.chain + 1; sel.page = 1; ns.RefreshJournal()
  end)
  MakeButton(f, "< Page", 90, 250, 10, function()
    sel.page = sel.page - 1; ns.RefreshJournal()
  end)
  MakeButton(f, "Page >", 90, 346, 10, function()
    sel.page = sel.page + 1; ns.RefreshJournal()
  end)

  f:Hide()
end

function ns.ToggleJournal(show)
  if not f then ns.BuildJournal() end
  if show == nil then f:SetShown(not f:IsShown())
  else f:SetShown(show and true or false) end
  if f:IsShown() then
    local ci, p = FindOpenTarget()
    if ci then sel.chain, sel.page = ci, p end
    ns.RefreshJournal()
  end
end

-- RETIRED separate reader window (superseded by the Hub Journal
-- tab): the builders above are unreachable through these public
-- entry points, which now open the one Story Guide panel instead.
ns.BuildJournal = function() end
ns.RefreshJournal = function() end
ns.ToggleJournal = function(show)
  if ns.ToggleHub then ns.ToggleHub(show, "journal") end
end
