-- MainStoryGuide system integration.
-- Native entry points only: minimap button, Addon Compartment entry,
-- a quest-log button, a Blizzard Settings/Interface Options panel,
-- and a normal WoW key binding. Every integration is feature-guarded
-- with pcall so an API differences on the Forever client disable that
-- one entry point instead of breaking the addon.
local _, ns = ...

-- Readability: Hub.lua loads first and owns ns.ReadabilityProfile.
-- The fallback mirrors it so options stay sized if load order changes.
ns.ReadabilityProfile = ns.ReadabilityProfile or {
  rowHeight = 28, buttonHeight = 26, title = 20, heading = 16,
  body = 14, bodySize = 14, list = 13, listSize = 13,
  meta = 12, small = 12, button = 13, font = "Fonts\\FRIZQT__.TTF",
}
local R = ns.ReadabilityProfile

local function ApplyFont(fs, size)
  if not fs then return end
  if fs.SetFont then pcall(fs.SetFont, fs, R.font, size or R.body, "") end
  if fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, 1, -1) end
  if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.6) end
end

local function StyleButton(b)
  if b and b.GetFontString then ApplyFont(b:GetFontString(), R.button) end
end

BINDING_HEADER_MAINSTORYGUIDE = "Forever Quest Chains"
BINDING_NAME_MAINSTORYGUIDE_TOGGLE = "Toggle Story Guide"

function MainStoryGuide_Toggle()
  if ns.ToggleHub then ns.ToggleHub() end
end

------------------------------------------------------------------
-- Minimap geometry (pure helpers; unit-tested outside the game)
------------------------------------------------------------------
local atan2 = math.atan2 or math.atan

function ns.MinimapButtonPosition(angle, radius)
  local r = math.rad(angle or 210)
  radius = radius or 80
  return math.cos(r) * radius, math.sin(r) * radius
end

function ns.MinimapAngleFromOffsets(x, y)
  return (math.deg(atan2(y or 0, x or 0)) + 360) % 360
end

------------------------------------------------------------------
-- Minimap button (standard round minimap-button construction)
------------------------------------------------------------------
local minimapButton

local function PositionMinimapButton()
  if not minimapButton or not Minimap then return end
  local radius = (Minimap:GetWidth() or 140) / 2 + 6
  local x, y = ns.MinimapButtonPosition(ns.db and ns.db.minimapAngle or 210, radius)
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ns.RefreshMinimapButton()
  if not minimapButton then return end
  local show = not ns.db or ns.db.showMinimapButton ~= false
  minimapButton:SetShown(show)
  PositionMinimapButton()
end

function ns.BuildMinimapButton()
  if minimapButton or not Minimap then return end
  local b = CreateFrame("Button", "MainStoryGuideMinimapButton", Minimap)
  minimapButton = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  if b.SetFrameLevel then b:SetFrameLevel(8) end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetMovable(true)
  b:SetClampedToScreen(true)

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  icon:SetSize(19, 19)
  b.icon = icon

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Border")
  border:SetSize(52, 52)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  local dragging = false
  b:SetScript("OnDragStart", function(self)
    dragging = true
    self._suppressClick = false
    self:SetScript("OnUpdate", function()
      if not Minimap or not GetCursorPosition then return end
      local cx, cy = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale() or 1
      local mx, my = GetCursorPosition()
      if cx and cy and mx and my then
        local angle = ns.MinimapAngleFromOffsets(mx / scale - cx, my / scale - cy)
        if ns.db then ns.db.minimapAngle = angle end
        self._suppressClick = true
        PositionMinimapButton()
      end
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    dragging = false
    self:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnClick", function(self, button)
    if self._suppressClick then self._suppressClick = false; return end
    if button == "RightButton" then
      if ns.OpenOptions then ns.OpenOptions() end
    else
      MainStoryGuide_Toggle()
    end
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Story Guide", 1, 1, 1)
    GameTooltip:AddLine("Left-click: open the story guide", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Right-click: options", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Drag: move this button", 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  PositionMinimapButton()
  ns.RefreshMinimapButton()
end

local function RegisterAddonCompartment()
  if not AddonCompartmentFrame or not AddonCompartmentFrame.RegisterAddon then return end
  pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
    text = "Forever Quest Chains",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    notCheckable = true,
    registerForAnyClick = true,
    func = function(_, _, _, _, clickType)
      if clickType == "RightButton" then
        if ns.OpenOptions then ns.OpenOptions() end
      else
        MainStoryGuide_Toggle()
      end
    end,
    funcOnEnter = function(owner)
      if GameTooltip then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText("Story Guide", 1, 1, 1)
        GameTooltip:AddLine("Follow the main storyline and read your story journal.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
      end
    end,
    funcOnLeave = function() if GameTooltip then GameTooltip:Hide() end end,
  })
end

------------------------------------------------------------------
-- Blizzard Settings / Interface Options panel
------------------------------------------------------------------
local optionsPanel, optionsCategory, optionChecks

function ns.RefreshOptionsPanel()
  if not optionChecks or not ns.db then return end
  for _, c in pairs(optionChecks) do
    if c.frame and c.frame.SetChecked then c.frame:SetChecked(c.get() and true or false) end
  end
end

local function ApplyOptionsDefaults()
  if not ns.db then return end
  ns.db.gossipTags = true
  ns.db.tooltipTags = true
  ns.db.routeAutoWaypoint = true
  ns.db.showHints = false
  ns.db.useWaypointUI = true
  ns.db.questSparkles = true
  ns.db.questKillMarks = true
  ns.db.showMinimapButton = true
  ns.RefreshOptionsPanel()
  ns.RefreshMinimapButton()
  ns.Refresh()
end

local function MakeOptionCheck(panel, key, label, y, get, set)
  local check = CreateFrame("CheckButton", "MainStoryGuideOptions" .. key, panel,
                            "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, y)
  if check.SetSize then check:SetSize(28, 28) end
  local text = check.Text or _G[check:GetName() .. "Text"]
  if text and text.SetText then text:SetText(label); ApplyFont(text, R.body) end
  check:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
    ns.RefreshMinimapButton()
    ns.Refresh()
  end)
  optionChecks[key] = { frame = check, get = get }
  return check
end

function ns.BuildOptionsPanel()
  if optionsPanel then return optionsPanel end
  local panel = CreateFrame("Frame", "MainStoryGuideOptionsPanel", UIParent)
  optionsPanel = panel
  optionChecks = {}
  panel.name = "Forever Quest Chains"
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ApplyFont(title, R.title)
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  title:SetText("Forever Quest Chains")

  local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ApplyFont(subtitle, R.body)
  if subtitle.SetTextColor then subtitle:SetTextColor(0.88, 0.88, 0.88) end
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  subtitle:SetWidth(560)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetHeight(32)
  subtitle:SetJustifyV("TOP")
  subtitle:SetText("Story route, journal, quest labels and waypoint options.")

  -- 36px checkbox rows so the 14pt labels never crowd each other.
  MakeOptionCheck(panel, "Minimap", "Show minimap button", -92,
    function() return ns.db.showMinimapButton ~= false end,
    function(v) ns.db.showMinimapButton = v end)
  MakeOptionCheck(panel, "Gossip", "Quest-giver story labels in chat", -128,
    function() return ns.db.gossipTags end,
    function(v) ns.db.gossipTags = v end)
  MakeOptionCheck(panel, "Tooltip", "Story labels on quest tooltips", -164,
    function() return ns.db.tooltipTags end,
    function(v) ns.db.tooltipTags = v end)
  MakeOptionCheck(panel, "AutoWaypoint", "Automatically pin the current route target", -200,
    function() return ns.db.routeAutoWaypoint end,
    function(v) ns.db.routeAutoWaypoint = v end)
  MakeOptionCheck(panel, "WaypointUI", "Use Waypoint UI in-world navigation when installed", -236,
    function() return ns.db.useWaypointUI ~= false end,
    function(v)
      ns.db.useWaypointUI = v
      if not v and ns.ClearWaypointUIWaypoint then ns.ClearWaypointUIWaypoint() end
    end)
  MakeOptionCheck(panel, "Sparkles", "Sparkle on current quest giver / turn-in", -308,
    function() return ns.db.questSparkles ~= false end,
    function(v) ns.db.questSparkles = v end)
  MakeOptionCheck(panel, "KillMarks", "Skull icon on current kill target", -344,
    function() return ns.db.questKillMarks ~= false end,
    function(v) ns.db.questKillMarks = v end)
  MakeOptionCheck(panel, "Hints", "Show spoiler hints in the story reader", -380,
    function() return ns.db.showHints == true end,
    function(v) ns.db.showHints = v end)

  -- One row of 3 buttons: open the Hub and the two bulk resets.
  local function OptionButton(text, x, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(160, 22); StyleButton(b)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -428)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
  end
  OptionButton("Open Story Guide", 24, MainStoryGuide_Toggle)
  OptionButton("Resume All Skipped", 192, function()
    if ns.cdb and ns.cdb.skipped then wipe(ns.cdb.skipped) end
    ns.Refresh()
  end)
  OptionButton("Reset Manual Marks", 360, function()
    if ns.RouteResetManual then ns.RouteResetManual() end
  end)

  panel:SetScript("OnShow", ns.RefreshOptionsPanel)
  panel.OnRefresh = ns.RefreshOptionsPanel
  panel.refresh = ns.RefreshOptionsPanel
  panel.OnCommit = function() end
  panel.okay = function() end
  panel.OnDefault = ApplyOptionsDefaults
  panel.default = ApplyOptionsDefaults

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok and category then
      optionsCategory = category
      pcall(Settings.RegisterAddOnCategory, category)
    end
  end
  if not optionsCategory and InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, panel)
  end
  ns.RefreshOptionsPanel()
  return panel
end

function ns.OpenOptions()
  local panel = ns.BuildOptionsPanel()
  ns.RefreshOptionsPanel()
  if optionsCategory and Settings and Settings.OpenToCategory then
    local id = optionsCategory.ID or optionsCategory
    if pcall(Settings.OpenToCategory, id) then return end
  end
  if InterfaceOptionsFrame_OpenToCategory then
    pcall(InterfaceOptionsFrame_OpenToCategory, panel)
    pcall(InterfaceOptionsFrame_OpenToCategory, panel)
  end
end

------------------------------------------------------------------
-- Small native book button on the Blizzard quest details/log UI
------------------------------------------------------------------
local questLogButton

local function QuestLogParent()
  if QuestLogFrame then return QuestLogFrame, false end
  if QuestMapFrame and QuestMapFrame.DetailsFrame then
    return QuestMapFrame.DetailsFrame, true
  end
  return nil, false
end

function ns.BuildQuestLogButton()
  if questLogButton then return questLogButton end
  local parent, isDetails = QuestLogParent()
  if not parent then return nil end

  local b = CreateFrame("Button", "MainStoryGuideQuestLogButton", parent)
  questLogButton = b
  b:SetSize(26, 26)
  b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", isDetails and -38 or -38, isDetails and -6 or -10)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  icon:SetSize(17, 17)

  b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
  local normal = b:GetNormalTexture()
  if normal then normal:SetSize(38, 38) end
  b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      ns.OpenOptions()
    else MainStoryGuide_Toggle() end
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Story Guide", 1, 1, 1)
    GameTooltip:AddLine("Open the story route and journal.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Right-click for options.", 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local systemWatcher = CreateFrame("Frame")
systemWatcher:RegisterEvent("ADDON_LOADED")
systemWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
systemWatcher:SetScript("OnEvent", function(_, event, addonName)
  if event == "PLAYER_ENTERING_WORLD"
     or addonName == "Blizzard_WorldMap" or addonName == "Blizzard_QuestLog" then
    ns.BuildQuestLogButton()
  end
end)
if hooksecurefunc and ToggleQuestLog then
  hooksecurefunc("ToggleQuestLog", function() ns.BuildQuestLogButton() end)
end

local systemInitialized = false
function ns.InitSystemIntegration()
  if systemInitialized then return end
  systemInitialized = true
  ns.BuildMinimapButton()
  ns.BuildOptionsPanel()
  RegisterAddonCompartment()
  ns.BuildQuestLogButton()
end
