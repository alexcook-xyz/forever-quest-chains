-- MainStoryGuide Hub story data (issue #59, issue #78).
-- Pure builders for the story view of one storyline: the quest list, the
-- Journal list, the zone section, one reader and one action. No widget is
-- created here, so the code runs in a Lua 5.1 test. HubMap.lua paints the
-- result in the Map & Quest Log frame.
--
-- A section is { title, meta, rows }. A row is
--   { id, name, icon, tone, lines }
--   id: nil for a row that must not respond to a click (a locked page)
--   icon: "next" | "done" | "inlog" | "new" | "locked" | nil
--   tone: "done" (green) | "dim" (grey) | nil (gold)
-- A reader is { title, meta, nextLine, status, blocks, seenKey }.
-- A block is { kind = "head" | "text" | "small", text }.
local _, ns = ...

local STATE_TEXT = {
  done = "Completed", inlog = "In the quest log", ready = "Ready to turn in",
  next = "Not started", todo = "Not started", side = "Side quest",
}
local STATUS_TEXT = { PICKUP = "Not started", IN_PROGRESS = "In progress",
                      GAP = "Story gap", DONE = "Complete" }

local function Esc(value)
  local escape = ns.EscapeUIText
  if escape and value ~= nil then return escape(value) end
  return value
end

local function Block(list, kind, text)
  if text ~= nil and text ~= "" then list[#list + 1] = { kind = kind, text = text } end
end

------------------------------------------------------------------
-- The open storyline
------------------------------------------------------------------
-- The storyline of the Story view: the open one, else the followed one,
-- else the recommended one, else the first of the saga.
function ns.StoryChain(sel)
  local chain = sel.choice and sel.choice ~= "saga" and ns.FindChain(sel.choice)
  if not chain and ns.cdb and ns.cdb.forcedChain then
    chain = ns.FindChain(ns.cdb.forcedChain)
  end
  if not chain then
    local step = ns.GetRouteStep()
    chain = step and step.chain or nil
  end
  if not chain then chain = (ns.Chains or {})[1] end
  if chain then sel.choice = chain.id end
  return chain
end

-- Open one storyline: its selection starts again on the current quest.
function ns.StoryChoose(sel, chainId)
  sel.choice = chainId
  sel.rowId = nil
end

-- The entries of the storyline list: one plain table for each storyline.
function ns.ChooserEntries()
  local out = {}
  local choices = ns.StoryChoices()
  for i = 2, #choices do
    local ch = choices[i]
    local c = ch.chain or {}
    out[#out + 1] = { id = ch.id, name = ch.name, state = ch.state,
      done = ch.done or 0, total = ch.total or 0,
      skipped = ch.skipped, optional = ch.optional,
      minLevel = c.minLevel or 1, maxLevel = c.maxLevel or 60,
      teaser = ch.teaser or ch.summary }
  end
  return out
end

------------------------------------------------------------------
-- Quest reader
------------------------------------------------------------------
-- Reader of one quest. logEntry is set for a side quest that only the
-- quest log knows.
function ns.StoryQuestReader(questID, logEntry)
  local reader = { blocks = {}, questID = questID }
  local blocks = reader.blocks
  if not questID then
    reader.title = "Select a quest"
    Block(blocks, "text", "Choose a quest in the list to read its story details.")
    return reader
  end
  local d = ns.QuestDetail(questID)
  reader.detail = d
  if not d.quest then
    reader.title = Esc((logEntry and logEntry.title) or "Side quest")
    reader.meta = "Side quest" .. ((logEntry and logEntry.level and logEntry.level > 0)
      and (" - Level " .. logEntry.level) or "")
    Block(blocks, "text", "This side quest is not part of a tracked storyline.")
    Block(blocks, "small", d.reason or "No recorded location in guide data yet.")
    return reader
  end
  local q = d.quest
  reader.title = Esc(q.name)
  local shownIndex
  if d.chain and q.id then
    for i, eq in ipairs(ns.EffectiveQuests(d.chain)) do
      if eq.id == q.id then shownIndex = i; break end
    end
  end
  if d.chain then
    reader.meta = string.format("%s - Quest %d of %d - Levels %d-%d",
      Esc(d.chain.name), shownIndex or 0, d.total or 0,
      d.chain.minLevel or 1, d.chain.maxLevel or 60)
  else
    reader.meta = "Side quest - " .. Esc(q.zone or "?")
  end
  reader.state = d.state
  Block(blocks, "text", STATE_TEXT[d.state] or d.state)
  Block(blocks, "text", Esc(d.task))
  Block(blocks, "small", Esc(d.note))
  if d.hint and ns.db and ns.db.showHints then
    Block(blocks, "head", "Hint")
    Block(blocks, "text", Esc(d.hint))
  end
  -- The story text: the Journal page once it is written, else the summary
  -- of the storyline. Coordinates, the Forever flag and the requirement
  -- list stay out of the reader.
  if d.journal then
    -- QuestDetail gives the page only once it is earned (blind before that).
    Block(blocks, "head", Esc(d.journal.title or q.name))
    Block(blocks, "text", Esc(d.journal.body))
    if d.chain then reader.seenKey = q.id end
  elseif d.chain then
    local v = ns.OverviewView(d.chain)
    if v.teaser then
      Block(blocks, "head", "Summary")
      Block(blocks, "text", Esc(v.teaser))
      if v.tier >= 3 then Block(blocks, "text", Esc(v.summary)) end
    end
  end
  return reader
end

-- Warnings for the current step only.
local function StepWarnings(chain, level)
  local blocks = {}
  local r = ns.ResolveChain(chain)
  if r.state == "GAP" and r.target then
    Block(blocks, "small", "An earlier story quest is still open: "
      .. Esc(r.target.name) .. ".")
  elseif chain.minLevel and level < chain.minLevel - 2 then
    Block(blocks, "small", string.format("The story continues at level %d.",
      chain.minLevel))
  end
  return blocks
end

-- The step that a right click on a quest row marks: the first open step of
-- that quest, or its last hand-marked step (to undo it).
function ns.StoryMarkTarget(steps, questID)
  local open, marked
  for _, s in ipairs(steps or {}) do
    if s.questID == questID then
      if not s.done and not open then open = s end
      if s.manual then marked = s end
    end
  end
  if open then return open, "Mark Done" end
  if marked then return marked, "Undo Mark" end
  return nil
end


------------------------------------------------------------------
-- Journal readers
------------------------------------------------------------------
local function OpeningReader(chain)
  local v = ns.OverviewView(chain)
  local r = ns.ResolveChain(chain)
  local reader = { title = "Opening", blocks = {} }
  reader.meta = string.format("%s - Levels %d-%d - %s - %d/%d quests",
    Esc(chain.name), chain.minLevel or 1, chain.maxLevel or 60,
    STATUS_TEXT[r.state] or r.state, r.done, r.total)
  local b = reader.blocks
  Block(b, "text", Esc(v.teaser))
  if v.tier >= 3 then Block(b, "text", Esc(v.summary)) end
  if v.backstory then
    Block(b, "head", "Backstory")
    Block(b, "text", Esc(v.backstory))
  end
  if v.world then
    Block(b, "head", "The World Around")
    Block(b, "text", Esc(v.world))
  end
  if v.gossip and #v.gossip > 0 then
    Block(b, "head", "Voices & Rumors")
    for _, g in ipairs(v.gossip) do
      Block(b, "text", string.format("%s (%s): %s",
        Esc(g.speaker or "Someone"), Esc(g.place or "?"), Esc(g.text or "")))
    end
  end
  Block(b, "small", Esc(v.lockedNote))
  return reader
end

-- Page 0 is the Opening. A locked page has no row, so it has no reader.
local function JournalReader(chain, page)
  if page == 0 then return OpeningReader(chain) end
  local v = ns.JournalPageView(chain, page)
  local reader = { title = Esc(v.title or "?"), blocks = {} }
  if v.kind == "lore" then
    reader.meta = string.format("%s - page %d of %d", Esc(chain.name), v.page, v.total)
  elseif v.kind == "epilogue" then
    reader.meta = "Chapter complete"
  else
    reader.meta = string.format("%s - page %d of %d", Esc(v.questName or "?"),
      v.page, v.total)
  end
  Block(reader.blocks, "text", Esc(v.body or ""))
  reader.seenKey = v.key
  return reader
end

------------------------------------------------------------------
-- Zone reader: the tale of the zone of the current step
------------------------------------------------------------------
local function ZoneReader(zoneName)
  local v = ns.ZoneView(zoneName)
  local z = v.zone or { name = zoneName }
  local reader = { title = Esc(z.name or zoneName or "Zone"), blocks = {} }
  reader.meta = string.format("Levels %d-%d%s - %d main, %d side",
    z.minLevel or 1, z.maxLevel or 60, z.hub and (" - " .. Esc(z.hub)) or "",
    #(v.main or {}), #(v.side or {}))
  local b = reader.blocks
  if v.tier == 0 then
    Block(b, "text", "No step has been taken here yet.")
    Block(b, "text", "The quests of this land are listed on the right. Its story waits to be uncovered on foot.")
  end
  Block(b, "text", Esc(v.summary))
  if v.backstory then
    Block(b, "head", "Backstory")
    if type(v.backstory) == "table" then
      local lines = {}
      for _, item in ipairs(v.backstory) do lines[#lines + 1] = "- " .. Esc(item) end
      Block(b, "text", table.concat(lines, "\n"))
    else
      Block(b, "text", Esc(v.backstory))
    end
  end
  if v.developments and #v.developments > 0 then
    Block(b, "head", "Developments")
    local lines = {}
    for _, item in ipairs(v.developments) do lines[#lines + 1] = "- " .. Esc(item) end
    Block(b, "text", table.concat(lines, "\n"))
  end
  if v.epilogue then
    Block(b, "head", Esc(v.epilogue.title or "Epilogue"))
    Block(b, "text", Esc(v.epilogue.body or ""))
  end
  if z.chains and #z.chains > 0 then
    local names = {}
    for _, cid in ipairs(z.chains) do
      local c = ns.FindChain(cid)
      if c then names[#names + 1] = Esc(c.name) end
    end
    if #names > 0 then
      Block(b, "small", "Storylines here: " .. table.concat(names, ", "))
    end
  end
  if v.sideCharted == false then
    Block(b, "small", "The side roads of this land are not yet charted.")
  end
  return reader
end

------------------------------------------------------------------
-- List sections
------------------------------------------------------------------
-- Section "Quests": done rows, the current row, then the later rows.
local function QuestRows(steps, step)
  local rows, seen, allDone = {}, {}, {}
  for _, s in ipairs(steps or {}) do
    local key = s.routePos or s.questID
    allDone[key] = (allDone[key] ~= false) and s.done and true or false
  end
  for _, s in ipairs(steps or {}) do
    local key = s.routePos or s.questID
    if not seen[key] then
      seen[key] = true
      local row = { id = "q:" .. s.questID, name = Esc(s.quest.name) }
      if ns.IsCompleted(s.questID) or allDone[key] then
        row.icon, row.tone, row.lines = "done", "done", { "Done" }
      elseif step and s.routePos == step.routePos then
        row.icon, row.lines = "next", { Esc(step.task) }
      elseif s.skipped then
        row.tone, row.lines = "dim", { "Skipped" }
      elseif step then
        -- A quest still ahead stays hidden: no name, no objective.
        row.id, row.name, row.tone = nil, "???", "dim"
      else
        row.tone = "dim"
      end
      rows[#rows + 1] = row
    end
  end
  return rows
end

-- Section "Journal": the Opening, one row for each written page and one
-- "???" row (no id, no text) while any page is still locked.
local function JournalRows(chain)
  local rows = { { id = "j:0", name = "Opening" } }
  local locked = false
  for p = 1, ns.JournalPageCount(chain) do
    local v = ns.JournalPageView(chain, p)
    if v.locked then
      locked = true
    else
      local unread = ns.JournalIsUnread(v)
      rows[#rows + 1] = { id = "j:" .. p, name = Esc(v.title or "?"),
        icon = unread and "new" or "done", lines = { unread and "New" or nil } }
    end
  end
  if locked then rows[#rows + 1] = { name = "???", tone = "dim" } end
  return rows
end

-- Section "Also in <zone>": the zone tale and the open side quests of the
-- zone of the current step.
local function ZoneSection(step)
  if not (step and step.quest and ns.ZoneOf and ns.ZoneView) then return nil end
  local zoneName = ns.ZoneOf(step.quest)
  if not zoneName then return nil end
  local rows = { { id = "z:story", name = "Zone Story" } }
  local cat = ns.ZoneCatalog and ns.ZoneCatalog(zoneName)
  for _, rec in ipairs(cat and cat.side or {}) do
    if not ns.IsCompleted(rec.id) then
      rows[#rows + 1] = { id = "s:" .. rec.id, name = Esc(rec.name),
        icon = ns.IsInLog(rec.id) and "inlog" or nil, lines = { "Side quest" } }
    end
  end
  return { title = "Also in " .. Esc(zoneName), rows = rows }, zoneName
end

------------------------------------------------------------------
-- Waypoint line: the pin follows the followed storyline by itself
------------------------------------------------------------------
local function WaypointLine(chain, step)
  if ns.IsSagaReadOnly() then return nil end
  if not (ns.cdb and ns.cdb.forcedChain == chain.id) then return nil end
  if ns.db and ns.db.routeAutoWaypoint == false then return nil end
  local t = ns.GetRouteStepTarget and ns.GetRouteStepTarget(step)
  if t and t.map and t.x and t.y then
    return string.format("Waypoint: %s, %s", Esc(t.giver or t.name or "?"),
      Esc(t.zone or "?"))
  end
  return "No waypoint: this step has no recorded location."
end

-- The one action button of the story view, or nil.
local function StoryAction(chain, r, readOnly, entries)
  local nxt = (r.state == "DONE") and ns.ChooserNext(entries, chain.id, ns.NowChainId())
              or nil
  local label = ns.StoryActionLabel({ readOnly = readOnly, state = r.state,
    followed = ns.cdb and ns.cdb.forcedChain == chain.id,
    started = ns.ChooserStarted({ done = r.done, state = r.state }),
    nextName = nxt and nxt.name })
  if not label then return nil end
  if nxt then return { label = label, kind = "next", chainId = nxt.id } end
  return { label = label, kind = "follow", chainId = chain.id }
end

------------------------------------------------------------------
-- The story view
------------------------------------------------------------------
function ns.StoryView(sel)
  local chain = ns.StoryChain(sel)
  if not chain then
    return { title = "Story Guide", caption = "", sections = {},
             reader = { title = "No storyline", blocks = {} } }
  end
  local r = ns.ResolveChain(chain)
  local state = r.state
  local readOnly = ns.IsSagaReadOnly() and true or false
  local step, _, _, _, steps = ns.GetChainStep(chain)

  local quests = QuestRows(steps, step)
  local sections = {
    { title = "Quests", meta = string.format("%d/%d", r.done, r.total), rows = quests },
    { title = "Journal", rows = JournalRows(chain) },
  }
  local zoneSection, zoneName = ZoneSection(step)
  if zoneSection then sections[#sections + 1] = zoneSection end

  local known = {}
  for _, sec in ipairs(sections) do
    for _, row in ipairs(sec.rows) do
      if row.id then known[row.id] = true end
    end
  end
  local selected = sel.rowId
  if not (selected and known[selected]) then
    selected = (step and "q:" .. step.questID)
      or (quests[#quests] and quests[#quests].id) or "j:0"
  end

  local kind, key = selected:match("^(%a):(.+)$")
  local reader
  if kind == "j" then
    reader = JournalReader(chain, tonumber(key))
  elseif kind == "z" then
    reader = ZoneReader(zoneName)
  else
    reader = ns.StoryQuestReader(tonumber(key))
  end

  -- The other storylines matter only after the last quest.
  local entries = (state == "DONE") and ns.ChooserEntries() or nil
  local action = StoryAction(chain, r, readOnly, entries)
  if kind == "q" then
    local lead = {}
    if step then
      -- The NEXT: line, the warnings and the waypoint belong to the current
      -- step only.
      if step.questID == tonumber(key) then
        reader.nextLine = ns.NextStepLabel(state)
        reader.status = WaypointLine(chain, step)
        lead = StepWarnings(chain, (UnitLevel and UnitLevel("player")) or 1)
      end
    elseif state == "DONE" then
      reader.nextLine = ns.NextStepLabel("DONE")
      Block(lead, "head", "Storyline complete.")
      if not action and not readOnly then
        local allDone = true
        for _, e in ipairs(entries) do
          if e.state ~= "DONE" then allDone = false end
        end
        if allDone then reader.status = "Saga complete." end
      end
    else
      Block(lead, "head", "No current objective.")
      Block(lead, "text", "Every remaining step is toggled off or in a skipped storyline.")
    end
    for i = #lead, 1, -1 do table.insert(reader.blocks, 1, lead[i]) end
  end

  return { title = chain.name, chainId = chain.id,
           caption = string.format("%d / %d story quests done", r.done, r.total),
           sections = sections, selectedId = selected, reader = reader,
           action = action, step = step, steps = steps }
end
