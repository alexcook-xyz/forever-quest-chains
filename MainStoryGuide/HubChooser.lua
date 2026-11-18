-- MainStoryGuide Hub chooser rules: pure helpers (issue #59, issue #78).
-- No UI calls and no WoW API calls. Each function takes plain tables,
-- so tests/test_hub_chooser_rules.py runs them in a Lua 5.1 runtime.
--
-- An entry is a plain table:
--   id, name, state ("DONE" | "IN_PROGRESS" | "GAP" | "PICKUP" | "EMPTY"),
--   done, total, minLevel, maxLevel, skipped, optional
local _, ns = ...

-- Section titles in display order.
ns.CHOOSER_SECTIONS = { "Now", "Later", "Complete" }

-- A storyline has started when one quest is done or one is in the log.
function ns.ChooserStarted(entry)
  if (entry.done or 0) > 0 then return true end
  return entry.state == "IN_PROGRESS" or entry.state == "GAP"
end

-- Row icon: "new" (gold !), "progress" (grey ?), "locked" (grey !) or nil.
-- A skipped storyline and a storyline that opens more than 4 levels above
-- the character both get the grey "!". A complete storyline has no icon.
function ns.ChooserIcon(entry, level)
  if entry.skipped then return "locked" end
  if entry.state == "DONE" then return nil end
  if ns.ChooserStarted(entry) then return "progress" end
  if (entry.minLevel or 1) > level + 4 then return "locked" end
  return "new"
end

-- True when the row title is gray (skipped, or the level is too low).
function ns.ChooserDimmed(entry, level)
  return ns.ChooserIcon(entry, level) == "locked"
end

-- The tag at the left end of the line under a row name.
function ns.ChooserTag(entry)
  if entry.skipped then return "Skipped" end
  return string.format("Levels %d-%d", entry.minLevel or 1, entry.maxLevel or 60)
end

-- The section of one entry. A complete storyline is Complete. The storyline
-- that plays now is Now, unless it is skipped. Every other entry is Later.
function ns.ChooserSectionOf(entry, nowId)
  if entry.state == "DONE" then return "Complete" end
  if entry.id == nowId and not entry.skipped then return "Now" end
  return "Later"
end

-- Group entries into sections. A section with no entry is left out.
-- Later entries sort by minimum level, Optional storylines last.
-- Every other sort is stable, so the data order of the saga stays.
function ns.ChooserSections(entries, nowId)
  local buckets = {}
  for _, title in ipairs(ns.CHOOSER_SECTIONS) do buckets[title] = {} end
  for i, entry in ipairs(entries) do
    local list = buckets[ns.ChooserSectionOf(entry, nowId)]
    list[#list + 1] = { entry = entry, order = i }
  end
  table.sort(buckets["Later"], function(a, b)
    local ao, bo = a.entry.optional and 1 or 0, b.entry.optional and 1 or 0
    if ao ~= bo then return ao < bo end
    local al, bl = a.entry.minLevel or 1, b.entry.minLevel or 1
    if al ~= bl then return al < bl end
    return a.order < b.order
  end)
  local out = {}
  for _, title in ipairs(ns.CHOOSER_SECTIONS) do
    local list = buckets[title]
    if #list > 0 then
      local rows = {}
      for n, item in ipairs(list) do rows[n] = item.entry end
      out[#out + 1] = { title = title, rows = rows }
    end
  end
  return out
end

-- The caption under the title.
-- info: raceName, sagaName, level, done, total, readOnly
function ns.ChooserCaption(info)
  local text
  if info.readOnly then
    text = string.format("%s (read-only): %d / %d quests",
      info.sagaName, info.done, info.total)
  else
    text = string.format("Level %d %s - %d / %d quests",
      info.level, info.raceName, info.done, info.total)
  end
  if info.total > 0 and info.done >= info.total then
    text = text .. " - Saga complete"
  end
  return text
end

-- The label of the one action button on the storyline list.
function ns.ChooserActionLabel(entry, readOnly)
  if readOnly then return "View" end
  if entry.skipped then return "Resume" end
  if entry.state == "DONE" then return "Read Again" end
  if ns.ChooserStarted(entry) then return "Continue" end
  return "Begin"
end

-- The storyline that follows the open one: the storyline that plays now,
-- else the first one that is open, not skipped and not the open one.
function ns.ChooserNext(entries, currentId, nowId)
  if nowId and nowId ~= currentId then
    for _, e in ipairs(entries) do
      if e.id == nowId then return e end
    end
  end
  for _, e in ipairs(entries) do
    if e.id ~= currentId and e.state ~= "DONE" and not e.skipped then return e end
  end
  return nil
end

-- The label of the one action button of the story view, or nil when the
-- button is hidden. info: readOnly, state, followed, started, nextName.
-- A read-only saga and a followed storyline in progress have nothing to do.
function ns.StoryActionLabel(info)
  if info.readOnly then return nil end
  if info.state == "DONE" then
    return info.nextName and ("Continue: " .. info.nextName) or nil
  end
  if info.followed then return nil end
  return info.started and "Continue" or "Begin"
end

-- The label of the right-click item of a storyline row, or nil.
function ns.ChooserMenuLabel(entry, readOnly)
  if readOnly then return nil end
  if entry.skipped then return "Resume Storyline" end
  if entry.state == "DONE" then return nil end
  return "Skip Storyline"
end

-- A soft follow (Begin or Continue) must not keep a finished storyline.
-- Returns true when the stored follow still applies to this chain.
function ns.IsFollowActive(forcedChainId, chainId, state)
  return forcedChainId ~= nil and forcedChainId == chainId and state ~= "DONE"
end

-- The saga picker on the first screen: every saga with loaded data, in
-- display order. A player may walk any saga (a Gnome in Northshire can
-- follow the Human story). own marks the character's own race saga.
-- order: saga keys; sagas: key -> { name, faction }; hasData: key -> bool.
function ns.SagaPickerEntries(order, sagas, hasData, activeKey, ownKey)
  local out = {}
  for _, key in ipairs(order) do
    local saga = sagas[key]
    if saga and hasData(key) then
      out[#out + 1] = { key = key, name = saga.name, faction = saga.faction,
                        active = key == activeKey, own = key == ownKey }
    end
  end
  return out
end

-- Menu text of one picker entry.
function ns.SagaPickerLabel(entry)
  if entry.own then return entry.name .. " (home race)" end
  return entry.name .. " (" .. entry.faction .. ")"
end

-- Text on the picker button.
function ns.SagaPickerButtonText(sagaName)
  return "Saga: " .. (sagaName or "?")
end

------------------------------------------------------------------
-- Side quest chains (issue #2). A zone side list holds records in an
-- order where a prerequisite comes first. requires = quest ids; an id
-- that is not in the visible list (other faction, MAIN chain) is not a link.
------------------------------------------------------------------

-- Group a visible side list into chains. A chain is a set of quests that
-- link through requires; a quest with no link is a chain of one.
-- Returns { { key = "<first id>", quests = { rec... } } ... } in list order;
-- the quests of a chain are in prerequisite order.
function ns.SideChains(list)
  list = list or {}
  local index, parent = {}, {}
  for i, rec in ipairs(list) do index[rec.id] = i; parent[i] = i end
  local function find(i)
    while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
    return i
  end
  local needs = {}
  for i, rec in ipairs(list) do
    needs[i] = {}
    for _, r in ipairs(rec.requires or {}) do
      local j = index[r]
      if j and j ~= i then
        needs[i][#needs[i] + 1] = j
        local a, b = find(i), find(j)
        if a ~= b then
          if a < b then parent[b] = a else parent[a] = b end
        end
      end
    end
  end
  local members, order = {}, {}
  for i = 1, #list do
    local root = find(i)
    if not members[root] then members[root] = {}; order[#order + 1] = root end
    local m = members[root]
    m[#m + 1] = i
  end
  local chains = {}
  for _, root in ipairs(order) do
    local placed, quests = {}, {}
    local pending = members[root]
    while #pending > 0 do
      local rest, moved = {}, false
      for _, i in ipairs(pending) do
        local ready = true
        for _, j in ipairs(needs[i]) do
          if not placed[j] then ready = false; break end
        end
        if ready then
          placed[i] = true; quests[#quests + 1] = list[i]; moved = true
        else
          rest[#rest + 1] = i
        end
      end
      -- A cycle in the data must not hang the loop: keep the list order.
      if not moved then
        for _, i in ipairs(rest) do placed[i] = true; quests[#quests + 1] = list[i] end
        rest = {}
      end
      pending = rest
    end
    chains[#chains + 1] = { key = tostring(quests[1].id), quests = quests }
  end
  return chains
end

-- The current quest of a chain: the first quest that is not done and whose
-- prerequisites in the chain are done; else the first quest that is not done;
-- nil when every quest is done. isDone: quest id -> bool.
function ns.SideChainCurrent(chain, isDone)
  local inChain = {}
  for _, q in ipairs(chain.quests) do inChain[q.id] = true end
  local fallback
  for _, q in ipairs(chain.quests) do
    if not isDone(q.id) then
      fallback = fallback or q
      local ready = true
      for _, r in ipairs(q.requires or {}) do
        if inChain[r] and not isDone(r) then ready = false; break end
      end
      if ready then return q end
    end
  end
  return fallback
end

-- done, total, lowest and highest reqlevel of a quest list.
function ns.SideSummary(list, isDone)
  local done, total, lo, hi = 0, 0, nil, nil
  for _, q in ipairs(list) do
    total = total + 1
    if isDone(q.id) then done = done + 1 end
    local r = q.reqlevel
    if r and r > 0 then
      lo = (not lo or r < lo) and r or lo
      hi = (not hi or r > hi) and r or hi
    end
  end
  return done, total, lo, hi
end
