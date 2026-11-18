-- luacheck config for the MainStoryGuide addon (WoW Forever 1.60.1, Lua 5.1).
-- Goal: catch real bugs (undefined/typo'd globals, accidental global
-- writes, unreachable code). Style-only checks are off so the gate stays
-- meaningful. Add a WoW API name to read_globals only when it truly exists
-- in the 1.60.1 client.
std = "lua51"
max_line_length = false
codes = true
exclude_files = { "WaypointUI/**" }

-- Style/cosmetic checks disabled: unused vars/args, shadowing, empty branches.
ignore = {
  "21.", "23.",  -- unused / never-accessed variable or argument
  "311", "312", "313", -- value assigned/unused
  "431", "432",        -- shadowing upvalue / argument
  "542",               -- empty if branch
  "581",               -- not (x ~= y): intentional nil-means-true toggles
  "611", "612", "613", "614", -- whitespace
}

-- Globals the addon owns (SavedVariables and slash commands from the .toc).
globals = {
  "MainStoryGuideDB",
  "MainStoryGuideCharDB",
  "SlashCmdList",
  "SLASH_MAINSTORYGUIDE1",
  "SLASH_MAINSTORYGUIDE2",
  "SLASH_MAINSTORYGUIDE3",
  "BINDING_HEADER_MAINSTORYGUIDE",
  "BINDING_NAME_MAINSTORYGUIDE_TOGGLE",
  "MainStoryGuide_Toggle",
  "UISpecialFrames",
}

-- Blizzard/WoW API available in Forever.
read_globals = {
  "CreateFrame", "UIParent", "GameTooltip", "Minimap", "GameFontNormal",
  "C_AddOns", "C_GossipInfo", "C_Item", "C_Map", "C_NamePlate",
  "C_QuestLog", "C_SuperTrack", "C_Timer",
  "C_Texture", "ButtonFrameTemplate_HideButtonBar", "NavBar_Initialize",  -- probed in 1.60.1
  "GetAddOnMetadata", "GetCursorPosition", "GetItemCount",
  "GetNumAvailableQuests", "GetNumQuestLogEntries", "GetQuestID",
  "GetQuestLogTitle", "GetQuestUiMapID", "GetQuestsCompleted",
  "GetAvailableTitle", "GetTitleText",
  "UnitClass", "UnitFactionGroup", "UnitIsPlayer", "UnitLevel", "UnitName",
  "UnitRace", "UiMapPoint", "Settings", "WaypointUI", "WaypointUIAPI",
  "AddonCompartmentFrame", "QuestLogFrame", "QuestMapFrame", "ToggleQuestLog",
  "FauxScrollFrame_GetOffset", "FauxScrollFrame_OnVerticalScroll",
  "FauxScrollFrame_Update", "PanelTemplates_SetTab", "PanelTemplates_TabResize",
  "InterfaceOptionsFrame_OpenToCategory", "InterfaceOptions_AddCategory",
  "hooksecurefunc", "wipe", "tinsert", "tremove", "strsplit", "strtrim",
  "format", "date", "time", "GetTime", "IsShiftKeyDown", "IsControlKeyDown",
  "DEFAULT_CHAT_FRAME", "PlaySound", "SOUNDKIT", "BackdropTemplateMixin",
  "GetLocale", "abs", "min", "sort", "strlower", "strupper",
}
