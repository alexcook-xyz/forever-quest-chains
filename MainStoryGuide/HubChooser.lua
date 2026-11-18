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
