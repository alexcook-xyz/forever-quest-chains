-- MainStoryGuide Hub: ONE native Blizzard-style window.
-- /story is the only command a player needs; everything else is a
-- click inside this window. The window copies the Blizzard Map & Quest
-- Log (HubMap.lua): a list of storylines, then one story view of the open
-- storyline. The pure rules of the list are in HubChooser.lua; the list and
-- the reader of the story view are in HubStory.lua.
-- This file keeps the shared state and the entry points: ns.ToggleHub,
-- ns.RefreshHub and ns.BuildHub. Settings live in Interface Options.
local _, ns = ...

------------------------------------------------------------------
-- Readability profile (single source of truth for text sizing)
------------------------------------------------------------------
ns.ReadabilityProfile = {
  rowHeight = 28,
  buttonHeight = 26,
  title = 20,
  heading = 16,
  subheading = 14,
  body = 14,
  bodySize = 14,
  list = 13,
  listSize = 13,
  meta = 12,
  small = 12,
  feedback = 12,
  button = 13,
  detailBody = 14,
  overviewBody = 14,
  journalBody = 14,
  font = "Fonts\\FRIZQT__.TTF",
}

------------------------------------------------------------------
-- Pure helpers (no UI calls; unit-tested outside the game)
------------------------------------------------------------------
function ns.FindChain(chainId)
  for _, c in ipairs(ns.Chains or {}) do
    if c.id == chainId then return c end
  end
  return nil
end

-- The story chooser entries: saga first, then each storyline in
-- data order (core Human chains, then optional Forever chains).
function ns.StoryChoices()
  local out = { { id = "saga", name = "The Full Saga",
                  summary = "Every storyline in story order" } }
  for _, c in ipairs(ns.Chains or {}) do
    local r = ns.ResolveChain(c)
    if (not ns.IsChainIncluded or ns.IsChainIncluded(c)) and r.total > 0 then
    out[#out + 1] = { id = c.id, name = c.name, chain = c, summary = c.summary,
                      teaser = c.teaser,
                      done = r.done, total = r.total, state = r.state,
                      optional = (ns.IsSideChain and ns.IsSideChain(c)
                                  or c.optional) and true or false,
                      skipped = (ns.cdb and ns.cdb.skipped
                                 and ns.cdb.skipped[c.id]) and true or false,
                      pinned = (ns.cdb and ns.cdb.forcedChain == c.id)
                               and true or false }
    end
  end
  return out
end

-- Old callers and old saved values name a tab. The Hub has one story view,
-- so a tab word only picks the place inside it: "journal" opens the first
-- unread Journal page, every other word opens the current quest.
function ns.ResolveTab(tab)
  return tab == "journal" and "journal" or "route"
end

-- The storyline that the player follows, or nil. A follow of a finished
-- storyline is released, and a read-only saga never follows.
function ns.FollowedChain()
  local forced = ns.cdb and ns.cdb.forcedChain
  if not forced then return nil end
  if ns.IsSagaReadOnly and ns.IsSagaReadOnly() then return nil end
  local chain = ns.FindChain(forced)
  if chain and ns.IsFollowActive(forced, chain.id, ns.ResolveChain(chain).state) then
    return chain
  end
  return nil
end

-- The id of the storyline that plays now: the followed one, else the
-- storyline of the current route step.
function ns.NowChainId()
  local followed = ns.FollowedChain()
  if followed then return followed.id end
  local step = ns.GetRouteStep()
  return step and step.chain and step.chain.id or nil
end

-- Next-step labels for the smoke-test invariant:
-- every next step shows exactly one NEXT: literal. Engine states
-- (PICKUP / IN_PROGRESS / GAP / DONE in Core.lua ResolveChain) are
-- unchanged; this table is the display-layer mapping only.
local NEXT_STEP_LABEL = {
  PICKUP = "NEXT: PICK UP",
  IN_PROGRESS = "NEXT: IN PROGRESS",
  GAP = "NEXT: STORY GAP",
  DONE = "NEXT: CHAIN COMPLETE",
}

-- NextStepLabel(state) returns the NEXT: display string for one of
-- the four ResolveChain states, or "" for any other value.
function ns.NextStepLabel(state)
  return NEXT_STEP_LABEL[state] or ""
end

------------------------------------------------------------------
-- UI state, shared with HubMap.lua through ns.HubSel
--   view: "chooser" | "story"
--   choice: id of the open storyline
--   rowId: the selected row of the story view ("q:<quest>", "j:<page>",
--          "z:story", "s:<quest>"); nil selects the current quest
--   chooserId: the selected row of the storyline list
------------------------------------------------------------------
local sel = { view = "chooser", choice = nil, rowId = nil, chooserId = nil }
ns.HubSel = sel

-- Selecting a storyline follows it (forcedChain) except the engine
-- never auto-routes optional chains; explicit selection is their only
-- route. Keep cdb write local to avoid a Refresh loop.
function ns.SetForcedChainSoft(chainId)
  if ns.cdb then ns.cdb.forcedChain = chainId end
  if ns.UpdateRouteTracker then ns.UpdateRouteTracker(true) end
end

------------------------------------------------------------------
-- Entry points
------------------------------------------------------------------
function ns.BuildHub()
  return ns.MapHubBuild and ns.MapHubBuild() or nil
end

function ns.RefreshHub()
  if ns.MapHubIsShown and ns.MapHubIsShown() then ns.MapHubRefresh() end
end

-- The Hub opens on the current quest of the followed storyline, else on
-- the storyline list.
local function OpenDefault()
  local followed = ns.FollowedChain()
  if followed then
    sel.view, sel.choice, sel.rowId = "story", followed.id, nil
  else
    sel.view, sel.chooserId = "chooser", nil
  end
end

-- An outside caller (/story route, /story journal) opens the story view.
local function OpenForTab(tab)
  sel.view, sel.choice, sel.rowId = "story", nil, nil
  if ns.ResolveTab(tab) ~= "journal" then return end
  -- The first unread page of the saga, else the Opening of the followed or
  -- the recommended storyline.
  sel.rowId = "j:0"
  for _, c in ipairs(ns.Chains or {}) do
    local p = ns.JournalFirstUnreadPage(c)
    if p then
      sel.choice, sel.rowId = c.id, "j:" .. p
      break
    end
  end
end

function ns.ToggleHub(show, tab)
  if tab == "options" then
    -- Settings live in Interface Options; the Hub view does not change.
    if ns.OpenOptions then ns.OpenOptions() end
    return
  end
  local frame = ns.BuildHub()
  if not frame then return end
  local wasShown = ns.MapHubIsShown()
  local want
  if show == nil then want = not wasShown else want = show and true or false end
  if want and tab then
    OpenForTab(tab)
  elseif want and not wasShown then
    OpenDefault()
  end
  ns.MapHubSetShown(want)
  if want then ns.RefreshHub() end
end
