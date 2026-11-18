-- MainStoryGuide: Durotar chains shared by Orc and Troll sagas (issue #16).
--
-- Format (see Sagas.lua): ns.SharedChains[chainId] = { sagas = { Key = true } }.
-- Orc owns the Valley of Trials and Razor Hill Durotar chains; Troll walks them.
-- Load after Sagas.lua and before the Data_ files.

local _, ns = ...
ns.SharedChains = ns.SharedChains or {}
local S = ns.SharedChains

-- Orc-owned (Data_Orc.lua): Valley of Trials and shared Durotar chains.
S.trials     = { sagas = { Troll = true } }
S.kolkar     = { sagas = { Troll = true } }
S.betrayers  = { sagas = { Troll = true } }
S.peons      = { sagas = { Troll = true } }
S.skull_rock = { sagas = { Troll = true } }
