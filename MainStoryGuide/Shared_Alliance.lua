-- MainStoryGuide: Alliance chains that more than one saga walks.
--
-- Format (see Sagas.lua): ns.SharedChains[chainId] = { sagas = { Key = true },
-- skip = { [questId] = true } }. The owner keeps the chain; each listed saga
-- sees it in its "shared" group and may walk it on its route. `skip` drops
-- quests a sharing saga can never get.
--
-- Issue #13 (E2 2.1): Dwarves and Gnomes share one starter area and one road
-- through Dun Morogh and Loch Modan. Issue #15 (E2 2.3): the Alliance spine.
-- Dwarf, Gnome and Night Elf sagas join the Human line after their own
-- chains. Northshire and Elwynn stay Human (starter chains). The People's
-- Militia stays Human: Questie gives quest 65 no prerequisite. The Missing
-- Diplomat (issue #38) is generated into Data_HumanDiplomat.lua and joins the spine.
-- Load after Sagas.lua and before the Data_ files.

local _, ns = ...
ns.SharedChains = ns.SharedChains or {}
local S = ns.SharedChains

-- Dwarf-owned (Data_Dwarf.lua): Gnomes start in Coldridge Valley too.
S.coldridge   = { sagas = { Gnome = true } }
S.frostmane   = { sagas = { Gnome = true } }
S.kings_lands = { sagas = { Gnome = true } }
S.excavation  = { sagas = { Gnome = true } }
S.dark_threat = { sagas = { Gnome = true } }

-- Gnome-owned (Data_Gnome.lua): the Gnomeregan dungeon is walked by Dwarves.
S.gnomeregan  = { sagas = { Dwarf = true } }

-- Human-owned (Data_Human.lua and Data_HumanDiplomat.lua): the Alliance spine from level 14 to 60.
-- Issue #43: Redridge Under Siege holds 125 (for 89) and The Darkness of
-- Duskwood holds the Morbent Fel road (323 to 325, for 55), so the race
-- routes walk the whole spine.
local SPINE = { Dwarf = true, Gnome = true, NightElf = true }
S.defias_brotherhood = { sagas = SPINE }
S.redridge           = { sagas = SPINE }
S.stockade           = { sagas = SPINE }
S.stalvan            = { sagas = SPINE }
S.duskwood_darkness  = { sagas = SPINE }
S.missing_diplomat   = { sagas = SPINE }
S.onyxia             = { sagas = SPINE }
