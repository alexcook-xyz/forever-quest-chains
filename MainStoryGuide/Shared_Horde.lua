-- MainStoryGuide: Horde spine chains that more than one saga walks (issue #18).
--
-- Format (see Sagas.lua): ns.SharedChains[chainId] = { sagas = { Key = true } }.
-- The Orc saga owns the spine chains (Data_HordeSpine.lua); the Troll, Tauren
-- and Forsaken sagas walk them after their own chains. The anchor quests are
-- the last quest of each own route and the first quest of the spine:
--   Orc and Troll: Conscript of the Horde (840), at the orc outpost in the Barrens
--   Tauren:        Journey to the Crossroads (854), hand-in at Thork
--   Forsaken:      Sample for Helbrim (1358), hand-in at the Crossroads
-- All four then walk Disrupt the Attacks (871, Thork) and on through the Barrens
-- to Stranglethorn Vale, then through the later chains up to the Plaguelands and
-- Winterspring (levels 18 to 60). Load after Sagas.lua and before the Data_ files.

local _, ns = ...
ns.SharedChains = ns.SharedChains or {}
local S = ns.SharedChains

local WALKERS = { Troll = true, Tauren = true, Scourge = true }
for _, id in ipairs({
  "crossroads", "fungal_spores", "raptor_thieves", "kolkar_leaders", "echeyakee",
  "barrens_oases", "harpy_raiders", "northwatch", "tribes_at_war", "gann",
  "warsong", "yenniku", "bloodscalp_trolls", "grom_gol", "egg_hunt", "weapons_of_choice", "tear_of_the_moons",
  "ashenvale_hunt",
  "cenarius_legacy", "freewind_post", "alien_egg", "corrupter",
  "battle_of_hillsbrad", "hillsbrad_rescue", "elixir_of_agony", "swarm_grows",
  "hammerfall", "lost_report", "black_shield", "hammer_may_fall", "trollbane",
  "lack_of_surplus", "brood_of_onyxia", "pool_of_tears", "new_cloak",
  "ogres_of_feralas", "gordunni", "woodpaw", "strange_request", "venom_bottles",
  "ripple", "rinji", "wildhammer_messages", "torntusk", "fall_from_grace",
  "stealing_knowledge", "marvons_workshop", "strange_one", "wild_guardians",
  "shardtooth", "plaguelands", "ranger_lord", "nathanos",
}) do
  S[id] = { sagas = WALKERS }
end
