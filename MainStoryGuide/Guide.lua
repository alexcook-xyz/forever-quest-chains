-- MainStoryGuide Guide window: RETIRED. The one native Story
-- Guide panel (Hub.lua) replaced this separate window; these
-- entry points remain only so old callers land in the one menu.
local _, ns = ...

function ns.BuildGuide() end
function ns.RefreshGuide() end

function ns.ToggleGuide(show)
  if ns.ToggleHub then ns.ToggleHub(show, "route") end
end
