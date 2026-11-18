-- MainStoryGuide Tags: MAIN/SIDE labels at the quest giver,
-- on the quest detail screen, and on quest tooltips.
-- All hooks are guarded: Forever is a beta client, any missing
-- API simply disables that one tag surface instead of erroring.
local _, ns = ...

local taggedTitleFor = nil -- quest title already tagged (avoid re-append)

-- 1) Quest detail / progress / reward screens: tag the title.
local function TagQuestTitle()
  local title = (GetTitleText and GetTitleText()) or nil
  if not title or title == "" then return end
  if taggedTitleFor == title then return end
  local questID = nil
  if GetQuestID then local ok, id = pcall(GetQuestID); if ok then questID = id end end
  -- Also fall back by name when the ID is one we do not know (variant IDs).
  if (not questID or questID == 0 or not ns.QuestIndex[questID])
     and ns.NameIndex[title] then
    questID = ns.NameIndex[title]
  end
  local header = _G["QuestInfoTitleHeader"]
  local tag = ns.TagTextFor and ns.TagTextFor(questID, title)
              or ns.TagText(questID)
  if header and header.GetText and header.SetText then
    local cur = header:GetText() or ""
    if not cur:find("%[MAIN") and not cur:find("%[SIDE%]") then
      header:SetText(tag .. " " .. (ns.EscapeUIText and ns.EscapeUIText(cur) or cur))
      taggedTitleFor = title
    end
  else
    -- Fallback surface: one chat line so the tag is never lost.
    ns.Print(tag .. " " .. title)
    taggedTitleFor = title
  end
end

-- 2) Talking to a quest giver: echo what they offer, MAIN first.
local function TagGossip()
  if ns.db and ns.db.gossipTags == false then return end
  local offered = {}
  if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
    local ok, list = pcall(C_GossipInfo.GetAvailableQuests)
    if ok and list then
      for _, q in ipairs(list) do
        offered[#offered + 1] = { id = q.questID, name = q.title or ("Quest " .. tostring(q.questID)) }
      end
    end
  end
  if #offered == 0 and GetNumAvailableQuests and GetAvailableTitle then
    local ok, count = pcall(GetNumAvailableQuests)
    if ok and type(count) == "number" then
      for i = 1, count do
        local titleOk, t = pcall(GetAvailableTitle, i)
        if titleOk and type(t) == "string" and ns.CleanQuestTitle then
          local clean = ns.CleanQuestTitle(t)
          local id = clean and (ns.NameIndex or {})[clean] or nil
          offered[#offered + 1] = { id = id, name = t }
        end
      end
    end
  end
  if #offered == 0 then return end
  local npcOk, npcName = true, "Quest giver"
  if UnitName then npcOk, npcName = pcall(UnitName, "npc") end
  if not npcOk or type(npcName) ~= "string" or npcName == "" then
    npcName = "Quest giver"
  end
  ns.Print(npcName .. " offers:")
  for _, q in ipairs(offered) do
    if q.name and type(q.name) ~= "string" then q.name = tostring(q.name) end
    local tag = ns.TagTextFor and ns.TagTextFor(q.id, q.name)
                or ns.TagText(q.id)
    local isMain, chain = ns.ClassifyByIDOrName(q.id, q.name)
    if isMain and chain then
      local r = ns.ResolveChain(chain)
      if r.state ~= "EMPTY" then
        ns.Print(string.format("  %s %s (chain %d/%d done%s)", tag, q.name or "?",
          r.done, r.total, (r.target and r.target.id == q.id) and " - THIS IS YOUR NEXT STORY STEP" or ""))
      else
        ns.Print(string.format("  %s %s", tag, q.name or "?"))
      end
    else
      ns.Print(string.format("  %s %s", tag, q.name or "?"))
    end
  end
end

-- 3) Tooltips: if the first line is a known quest name, append its tag.
local function TagTooltip(tooltip)
  if ns.db and ns.db.tooltipTags == false then return end
  if not tooltip or tooltip == GameTooltip and tooltip:IsForbidden() then return end
  local name = tooltip.GetName and tooltip:GetName()
  if not name then return end
  local line1 = _G[name .. "TextLeft1"]
  local text = line1 and line1.GetText and line1:GetText()
  if not text then return end
  -- Strip colour codes / level prefixes for matching.
  if tooltip._msgTaggedFor == text then return end
  local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    :gsub("^%[%d+.-%]%s*", ""):gsub("%s+$", "")
  local questID = ns.NameIndex[clean]
  if not questID then
    -- Never tag SIDE on tooltips. "Not in the story DB" is not proof a
    -- tooltip is a quest at all (items, NPCs, objects...), and guessed
    -- SIDE tags on unrelated tooltips read as broken. MAIN only here.
    return
  end
  tooltip._msgTaggedFor = text
  local _, chain = ns.Classify(questID)
  if not chain then return end
  local quests = ns.EffectiveQuests and ns.EffectiveQuests(chain) or chain.quests
  local position = nil
  for i, eq in ipairs(quests or {}) do
    if eq.id == questID then position = i; break end
  end
  if not position then return end
  tooltip:AddLine(ns.TagText(questID))
  tooltip:AddLine(string.format("|cffbbbbbbStoryline: %s (step %d of %d)|r",
    chain.name, position, #quests))
  tooltip:Show()
end

function ns.InitTags()
  local f = CreateFrame("Frame", "MainStoryGuideTagFrame")
  f:RegisterEvent("QUEST_DETAIL")
  f:RegisterEvent("QUEST_PROGRESS")
  f:RegisterEvent("QUEST_COMPLETE")
  f:RegisterEvent("QUEST_FINISHED")
  f:RegisterEvent("GOSSIP_SHOW")
  f:RegisterEvent("QUEST_GREETING")
  f:SetScript("OnEvent", function(_, event)
    if event == "QUEST_FINISHED" then
      taggedTitleFor = nil
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
      taggedTitleFor = nil
      TagGossip()
    else
      taggedTitleFor = nil
      if C_Timer and C_Timer.After then C_Timer.After(0.05, TagQuestTitle)
      else TagQuestTitle() end
    end
  end)
  if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(t) TagTooltip(t) end)
    GameTooltip:HookScript("OnShow", function(t) TagTooltip(t) end)
    GameTooltip:HookScript("OnHide", function(t) t._msgTaggedFor = nil end)
  end
end
