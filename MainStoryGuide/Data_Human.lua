-- MainStoryGuide: Human (Alliance) main-story chain database.
--
-- HOW "MAIN STORY" IS DEFINED HERE
-- Vanilla/Forever has no single MSQ like retail. A quest is MAIN if it is
-- part of a named lore chain below (or in Data_HumanDiplomat.lua for The
-- Missing Diplomat), in chain order. Everything else the game offers you
-- is SIDE. Chains are in the order a Human meets them.
--
-- DATA PROVENANCE (shown in-game per chain)
--   verified = "forever" : quest IDs read from the RXPGuides Forever
--                          guides installed on this PC (Interface 16001).
--   verified = "classic": standard Classic quest IDs. Forever keeps
--                          Classic IDs (proven by the "forever" chains),
--                          but confirm with /story logquest if a step
--                          never ticks off, then fix the ID in this file.
--
-- Quest fields: id, name, giver, zone, x/y (giver, 0-100, approx),
-- map (UiMapID for waypoint), note (optional). kind="lead" = breadcrumb
-- that unlocks the chain; kind="dungeon" = dungeon step.
-- requires = {ids} = cross-chain prerequisite quest IDs (numbers only;
-- story-order inside the chain is derived, not listed). reqlevel = minimum
-- character level from the Forever quest database (advisory; RXP/in-game
-- dumps win on conflict).
--
-- Forever-only story (Skyborne / Zephras Isle, IDs 92xxx+) is a separate
-- starter, not the Human path, and is intentionally not tagged yet.

local _, ns = ...
ns.Chains = ns.Chains or {}

local ELWYNN, WESTFALL, REDRIDGE, DUSKWOOD = 1429, 1436, 1433, 1431
local STORMWIND, WETLANDS = 1453, 1437
local BURNING_STEPPES, BLASTED = 1428, 1419

local chains = {

{ id = "northshire", name = "Northshire's Defence", race = "Human",
  zone = "Elwynn Forest", minLevel = 1, maxLevel = 6, verified = "forever",
  summary = "Kobolds and Defias thieves press Northshire Abbey. First orders from Marshal McBride.",
  quests = {
    { id = 783,  name = "A Threat Within",          giver = "Deputy Willem",       zone = "Elwynn Forest", map = ELWYNN, x = 48.2, y = 42.8, reqlevel = 1 },
    { id = 7,    name = "Kobold Camp Cleanup",      giver = "Marshal McBride",     zone = "Elwynn Forest", map = ELWYNN, x = 48.9, y = 41.6, reqlevel = 1 },
    { id = 15,   name = "Investigate Echo Ridge",   giver = "Marshal McBride",     zone = "Elwynn Forest", map = ELWYNN, x = 48.9, y = 41.6, reqlevel = 1 },
    { id = 21,   name = "Skirmish at Echo Ridge",   giver = "Marshal McBride",     zone = "Elwynn Forest", map = ELWYNN, x = 48.9, y = 41.6, reqlevel = 1 },
    { id = 18,   name = "Brotherhood of Thieves",   giver = "Deputy Willem",       zone = "Elwynn Forest", map = ELWYNN, x = 48.2, y = 42.8, note = "First Defias sighting. This thread runs to level 60.", reqlevel = 2 },
    { id = 6,    name = "Bounty on Garrick Padfoot", giver = "Deputy Willem",      zone = "Elwynn Forest", map = ELWYNN, x = 48.2, y = 42.8, reqlevel = 2 },
    { id = 54,   name = "Report to Goldshire",      giver = "Marshal McBride",     zone = "Elwynn Forest", map = ELWYNN, x = 48.9, y = 41.6, kind = "lead", reqlevel = 1 },
  } },

{ id = "elwynn", name = "Shadows over Elwynn", race = "Human",
  zone = "Elwynn Forest", minLevel = 5, maxLevel = 11, verified = "forever",
  summary = "Goldshire's mines are overrun, the Riverpaw gnolls raid the roads, and two guards never came back from Stone Cairn Lake.",
  quests = {
    { id = 3903, name = "Milly Osworth",            giver = "Deputy Willem",       zone = "Elwynn Forest", map = ELWYNN, x = 48.2, y = 42.8, kind = "lead", requires = {18}, reqlevel = 2 },
    { id = 3904, name = "Milly's Harvest",          giver = "Milly Osworth",       zone = "Elwynn Forest", map = ELWYNN, x = 50.7, y = 39.4, requires = {18}, reqlevel = 2 },
    { id = 3905, name = "Grape Manifest",           giver = "Milly Osworth",       zone = "Elwynn Forest", map = ELWYNN, x = 50.7, y = 39.4, reqlevel = 2 },
    { id = 62,   name = "The Fargodeep Mine",       giver = "Marshal Dughan",      zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9, reqlevel = 4 },
    { id = 76,   name = "The Jasperlode Mine",      giver = "Marshal Dughan",      zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9, reqlevel = 4 },
    { id = 35,   name = "Further Concerns",         giver = "Marshal Dughan",      zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9, kind = "lead", reqlevel = 7 },
    { id = 37,   name = "Find the Lost Guards",     giver = "Guard Thomas",        zone = "Elwynn Forest", map = ELWYNN, x = 74.0, y = 72.4, reqlevel = 7 },
    { id = 45,   name = "Discover Rolf's Fate",     giver = "Guard Thomas",        zone = "Elwynn Forest", map = ELWYNN, x = 74.0, y = 72.4, reqlevel = 7 },
    { id = 71,   name = "Report to Thomas",         giver = "Rolf's corpse (Stone Cairn Lake)", zone = "Elwynn Forest", map = ELWYNN, x = 72.7, y = 60.3, reqlevel = 7 },
    { id = 39,   name = "Deliver Thomas' Report",   giver = "Guard Thomas",        zone = "Elwynn Forest", map = ELWYNN, x = 74.0, y = 72.4, reqlevel = 7 },
    { id = 52,   name = "Protect the Frontier",     giver = "Guard Thomas",        zone = "Elwynn Forest", map = ELWYNN, x = 74.0, y = 72.4, reqlevel = 7 },
    { id = 11,   name = "Riverpaw Gnoll Bounty",    giver = "Deputy Rainer (Westbrook Garrison)", zone = "Elwynn Forest", map = ELWYNN, x = 24.4, y = 74.7, reqlevel = 6 },
    
    { id = 176,  name = "Wanted: \"Hogger\"",       giver = "Wanted Poster (Westbrook Garrison)", zone = "Elwynn Forest", map = ELWYNN, x = 24.6, y = 74.7, note = "Group quest. Hogger, terror of Elwynn.", reqlevel = 5 },
    { id = 123,  name = "The Collector",            giver = "Gold Pickup Schedule (item drop)", zone = "Elwynn Forest", map = ELWYNN, kind = "item", verified = "forever", startItem = "Gold Pickup Schedule", startItemID = 1307, startSource = "Very rare drop from Riverpaw Runt and Riverpaw Outrunner gnolls; Gruff Swiftbite always carries one. Use the schedule to start the quest, then take it to Marshal Dughan.", deferUntilAvailable = true, reqlevel = 7 },
        { id = 147,  name = "Manhunt",                  giver = "Marshal Dughan",        zone = "Elwynn Forest",        map = ELWYNN, x = 42.1, y = 65.9, reqlevel = 7 },
        { id = 239,  name = "Westbrook Garrison Needs Help!", giver = "Marshal Dughan", zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9, kind = "lead", reqlevel = 6 },
  } },

{ id = "peoples_militia", name = "The People's Militia", race = "Human",
  zone = "Westfall", minLevel = 9, maxLevel = 15, verified = "forever",
  summary = "Stormwind abandoned Westfall. Gryan Stoutmantle raises a militia of farmers against the Defias who took their land.",
  quests = {
    { id = 109,  name = "Report to Gryan Stoutmantle", giver = "Marshal Dughan",   zone = "Elwynn Forest", map = ELWYNN,   x = 42.1, y = 65.9, kind = "lead", reqlevel = 9 },
    { id = 12,   name = "The People's Militia",     giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL, x = 56.4, y = 47.5, reqlevel = 9 },
    { id = 13,   name = "The People's Militia",     giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL, x = 56.4, y = 47.5, reqlevel = 9 },
    { id = 14,   name = "The People's Militia",     giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL, x = 56.4, y = 47.5, reqlevel = 9 },
    { id = 102,  name = "Patrolling Westfall",      giver = "Captain Danuvin",     zone = "Westfall",      map = WESTFALL, x = 56.0, y = 47.4, reqlevel = 8 },
  } },

{ id = "defias_brotherhood", name = "The Defias Brotherhood", race = "Human",
  zone = "Westfall", minLevel = 14, maxLevel = 22, verified = "classic",
  summary = "Carry Wiley's Note to Stormwind, unmask the Defias traitor in Westfall, then take Edwin VanCleef's head in the Deadmines.",
  quests = {
    { id = 65,   name = "The Defias Brotherhood",   giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL,  x = 56.4, y = 47.5, reqlevel = 14 },
    { id = 132,  name = "The Defias Brotherhood",   giver = "Wiley the Black",     zone = "Redridge Mountains", map = REDRIDGE, x = 26.5, y = 45.3, note = "Wiley's Note, for Gryan Stoutmantle in Westfall.", reqlevel = 14 },
    { id = 135,  name = "The Defias Brotherhood",   giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL,  x = 56.4, y = 47.5, note = "Wiley's Note, for Master Mathias Shaw in Stormwind.", reqlevel = 14 },
    { id = 141,  name = "The Defias Brotherhood",   giver = "Master Mathias Shaw", zone = "Stormwind City", map = STORMWIND, x = 78.7, y = 60.1, reqlevel = 14 },
    { id = 142,  name = "The Defias Brotherhood",   giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL,  x = 56.4, y = 47.5, note = "Track down the Defias Messenger in Westfall.", reqlevel = 14 },
    { id = 155,  name = "The Defias Brotherhood",   giver = "The Defias Traitor",  zone = "Westfall",      map = WESTFALL,  x = 55.7, y = 47.5, note = "Escort the traitor to the Defias hideout.", reqlevel = 14 },
    { id = 166,  name = "The Defias Brotherhood",   giver = "Gryan Stoutmantle",   zone = "Westfall",      map = WESTFALL,  x = 56.4, y = 47.5, kind = "dungeon", note = "The Deadmines: bring back Edwin VanCleef's head.", reqlevel = 14 },
    { id = 373,  name = "The Unsent Letter",        giver = "Drops from Edwin VanCleef", zone = "The Deadmines", map = WESTFALL, x = 42.6, y = 71.9, kind = "drop", startItem = "An Unsent Letter", startSource = "Dropped by Edwin VanCleef in the Deadmines. Use the letter to start the quest.", note = "VanCleef's letter points at Baros Alexston in Stormwind. The conspiracy goes higher.", reqlevel = 16 },
  } },

{ id = "redridge", name = "Redridge Under Siege", race = "Human",
  zone = "Redridge Mountains", minLevel = 15, maxLevel = 25, verified = "forever",
  summary = "Blackrock orcs press the roads while Lakeshire begs Stormwind for help that never comes.",
  quests = {
    { id = 244,  name = "Encroaching Gnolls",       giver = "Marshal Dughan",      zone = "Elwynn Forest",       map = ELWYNN,   x = 42.1, y = 65.9, kind = "lead", reqlevel = 11 },
    { id = 20,   name = "Blackrock Menace",         giver = "Marshal Marris",      zone = "Redridge Mountains",  map = REDRIDGE, x = 26.8, y = 48.6, reqlevel = 18 },
    { id = 34,   name = "An Unwelcome Guest",       giver = "Guard Parker",        zone = "Redridge Mountains",  map = REDRIDGE, x = 30.6, y = 58.9, reqlevel = 18 },
    { id = 125,  name = "The Lost Tools",           giver = "Foreman Oslow",       zone = "Redridge Mountains",  map = REDRIDGE, x = 27.1, y = 48.6, reqlevel = 15 },
    { id = 89,   name = "The Everstill Bridge",     giver = "Foreman Oslow",       zone = "Redridge Mountains",  map = REDRIDGE, x = 27.2, y = 47.3, reqlevel = 15 },
    { id = 91,   name = "Solomon's Law",            giver = "Magistrate Solomon",  zone = "Redridge Mountains",  map = REDRIDGE, x = 29.9, y = 53.5, reqlevel = 17 },
  } },

{ id = "stockade", name = "The Stockade Uprising", race = "Human",
  zone = "Stormwind City", minLevel = 22, maxLevel = 29, verified = "classic",
  summary = "VanCleef is dead but his men riot inside the Stockade. Warden Thelwater wants Bazil Thredd's head.",
  quests = {
    { id = 377,  name = "Crime and Punishment",     giver = "Councilman Millstipe", zone = "Duskwood",           map = DUSKWOOD,  x = 72.4, y = 47.9, kind = "dungeon", reqlevel = 22 },
    { id = 386,  name = "What Comes Around...",     giver = "Guard Berton",        zone = "Redridge Mountains", map = REDRIDGE,  x = 26.2, y = 45.8, kind = "dungeon", reqlevel = 22 },
    { id = 387,  name = "Quell The Uprising",       giver = "Warden Thelwater",    zone = "Stormwind City",     map = STORMWIND, x = 51.5, y = 69.4, kind = "dungeon", reqlevel = 22 },
    { id = 388,  name = "The Color of Blood",       giver = "Nikova Raskol",       zone = "Stormwind City",     map = STORMWIND, x = 64.6, y = 72.6, kind = "dungeon", reqlevel = 22 },
    { id = 389,  name = "Bazil Thredd",             giver = "Baros Alexston",      zone = "Stormwind City",     map = STORMWIND, x = 49.8, y = 57.3, requires = {373}, reqlevel = 16, note = "Speak with Warden Thelwater at the Stockade." },
    { id = 391,  name = "The Stockade Riots",       giver = "Warden Thelwater",    zone = "Stormwind City",     map = STORMWIND, x = 51.5, y = 69.4, kind = "dungeon", reqlevel = 16 },
  } },

{ id = "stalvan", name = "The Legend of Stalvan", race = "Human",
  zone = "Duskwood", minLevel = 22, maxLevel = 32, verified = "classic",
  summary = "A muddy journal page in Westfall starts Azeroth's darkest ghost story: Stalvan Mistmantle and the family he butchered.",
  quests = {
    { id = 66,   name = "The Legend of Stalvan",    giver = "A Faded Journal Page (Moonbrook schoolhouse)", zone = "Westfall", map = WESTFALL, x = 49.2, y = 77.4, kind = "item", startItem = "A Faded Journal Page", startSource = "Found in the weathered chest at the Moonbrook schoolhouse. Read the page to start the quest.", reqlevel = 22 },
    { id = 67,   name = "The Legend of Stalvan",    giver = "Gryan Stoutmantle",   zone = "Westfall",         map = WESTFALL, x = 56.4, y = 47.5, reqlevel = 22 },
    { id = 68,   name = "The Legend of Stalvan",    giver = "Old Footlocker (Moonbrook)", zone = "Westfall", map = WESTFALL, x = 41.5, y = 66.7, kind = "item", startSource = "Open the Old Footlocker at Moonbrook; its contents start this link in the chain.", reqlevel = 22 },
    { id = 69,   name = "The Legend of Stalvan",    giver = "Clerk Daltry",        zone = "Duskwood",         map = DUSKWOOD, x = 72.3, y = 46.9, reqlevel = 22 },
    { id = 70,   name = "The Legend of Stalvan",    giver = "Clerk Daltry",        zone = "Duskwood",         map = DUSKWOOD, x = 72.3, y = 46.9, reqlevel = 22 },
    { id = 72,   name = "The Legend of Stalvan",    giver = "Clerk Daltry",        zone = "Duskwood",         map = DUSKWOOD, x = 72.3, y = 46.9, reqlevel = 22 },
    { id = 74,   name = "The Legend of Stalvan",    giver = "Tobias Mistmantle (Stormwind Cathedral Square)", zone = "Stormwind City", map = STORMWIND, x = 54.4, y = 54.3, reqlevel = 22 },
    { id = 75,   name = "The Legend of Stalvan",    giver = "Tobias Mistmantle",   zone = "Stormwind City",   map = STORMWIND, x = 54.4, y = 54.3, reqlevel = 22 },
    { id = 78,   name = "The Legend of Stalvan",    giver = "Grandma (Duskwood)",  zone = "Duskwood",         map = DUSKWOOD, x = 17.5, y = 28.8, reqlevel = 22 },
    { id = 79,   name = "The Legend of Stalvan",    giver = "Commander Althea Ebonlocke", zone = "Duskwood",  map = DUSKWOOD, x = 73.7, y = 46.7, reqlevel = 22 },
    { id = 80,   name = "The Legend of Stalvan",    giver = "Commander Althea Ebonlocke", zone = "Duskwood",  map = DUSKWOOD, x = 73.7, y = 46.7, reqlevel = 22 },
    { id = 97,   name = "The Legend of Stalvan",    giver = "Clerk Daltry",        zone = "Duskwood",         map = DUSKWOOD, x = 72.6, y = 46.9, reqlevel = 22 },
    { id = 98,   name = "The Legend of Stalvan",    giver = "Commander Althea Ebonlocke", zone = "Duskwood",  map = DUSKWOOD, x = 73.5, y = 46.8, note = "Manor Mistmantle. Loot the Mistmantle Family Ring, then face Stalvan.", reqlevel = 22 },
  } },

{ id = "duskwood_darkness", name = "The Darkness of Duskwood", race = "Human",
  zone = "Duskwood", minLevel = 25, maxLevel = 35, verified = "classic",
  summary = "Morbent Fel raises the dead of Raven Hill, and Sven Yorgen seeks vengeance against a shadowy figure.",
  quests = {
    { id = 56,   name = "The Night Watch",          giver = "Commander Althea Ebonlocke", zone = "Duskwood", map = DUSKWOOD, x = 73.5, y = 46.8, reqlevel = 18 },
    { id = 57,   name = "The Night Watch",          giver = "Commander Althea Ebonlocke", zone = "Duskwood", map = DUSKWOOD, x = 73.7, y = 46.7, reqlevel = 18 },
    { id = 58,   name = "The Night Watch",          giver = "Commander Althea Ebonlocke", zone = "Duskwood", map = DUSKWOOD, x = 73.7, y = 46.8, reqlevel = 18 },
    { id = 95,   name = "Sven's Revenge",              giver = "Sven Yorgen",         zone = "Duskwood", map = DUSKWOOD, x = 7.8,  y = 34.1, reqlevel = 20, verified = "forever" },
    { id = 230,  name = "Sven's Camp",                 giver = "Found along the road", zone = "Duskwood", map = DUSKWOOD, x = 49.9, y = 77.8, kind = "item", reqlevel = 20, verified = "forever" },
    { id = 262,  name = "The Shadowy Figure",          giver = "Sven Yorgen",         zone = "Duskwood", map = DUSKWOOD, x = 7.8,  y = 34.1, reqlevel = 20, verified = "forever" },
    { id = 265,  name = "The Shadowy Search Continues", giver = "Madame Eva",         zone = "Duskwood", map = DUSKWOOD, x = 75.7, y = 45.3, reqlevel = 20, verified = "forever" },
    { id = 266,  name = "Inquire at the Inn",          giver = "Clerk Daltry",        zone = "Duskwood", map = DUSKWOOD, x = 72.6, y = 46.9, reqlevel = 20, verified = "forever" },
    { id = 453,  name = "Finding the Shadowy Figure",  giver = "Tavernkeep Smitts",   zone = "Duskwood", map = DUSKWOOD, x = 73.9, y = 44.4, reqlevel = 20, verified = "forever" },
    { id = 268,  name = "Return to Sven",              giver = "Jitters",             zone = "Duskwood", map = DUSKWOOD, x = 18.4, y = 56.5, reqlevel = 20, verified = "forever" },
    { id = 323,  name = "Proving Your Worth",          giver = "Sven Yorgen",         zone = "Duskwood", map = DUSKWOOD, x = 7.8,  y = 34.1, reqlevel = 20 },
    { id = 269,  name = "Seeking Wisdom",              giver = "Sven Yorgen",         zone = "Duskwood", map = DUSKWOOD, x = 7.8,  y = 34.1, reqlevel = 20 },
    { id = 270,  name = "The Doomed Fleet",            giver = "Bishop Farthing",     zone = "Stormwind City", map = STORMWIND, x = 49.9, y = 46.0, reqlevel = 20 },
    { id = 321,  name = "Lightforge Iron",             giver = "Glorin Steelbrow",    zone = "Wetlands", map = WETLANDS, x = 10.6, y = 60.6, reqlevel = 20 },
    { id = 324,  name = "The Lost Ingots",             giver = "Waterlogged Chest",   zone = "Wetlands", map = WETLANDS, x = 12.1, y = 64.2, kind = "item", startSource = "Open the Waterlogged Chest in the wreckage of The Flying Osprey; it starts this link in the chain.", reqlevel = 20 },
    { id = 322,  name = "Blessed Arm",                 giver = "Glorin Steelbrow",    zone = "Wetlands", map = WETLANDS, x = 10.6, y = 60.6, reqlevel = 20 },
    { id = 325,  name = "Armed and Ready",             giver = "Grimand Elmore",      zone = "Stormwind City", map = STORMWIND, x = 59.7, y = 33.8, reqlevel = 20 },
    { id = 55,   name = "Morbent Fel",                 giver = "Sven Yorgen",         zone = "Duskwood", map = DUSKWOOD, x = 7.8,  y = 34.1, reqlevel = 20 },
  } },

{ id = "onyxia", name = "Onyxia: The True Masters", race = "Human",
  zone = "Burning Steppes", minLevel = 48, maxLevel = 60, verified = "forever",
  summary = "ENDGAME. The Defias, the missing King, the puppet in Stormwind: it was Lady Katrana Prestor all along. Free Marshal Windsor and unmask the black dragon Onyxia.",
  quests = {
    { id = 4182, name = "Dragonkin Menace",         giver = "Helendis Riverhorn",  zone = "Burning Steppes", map = BURNING_STEPPES, x = 94.5, y = 31.6, reqlevel = 48 },
    { id = 4183, name = "The True Masters",         giver = "Marshal Maxwell",     zone = "Burning Steppes", map = BURNING_STEPPES, x = 85.8, y = 68.7, reqlevel = 48 },
    { id = 4184, name = "The True Masters",         giver = "Magistrate Solomon",  zone = "Redridge Mountains", map = REDRIDGE,   x = 29.9, y = 53.5, reqlevel = 48 },
    { id = 4185, name = "The True Masters",         giver = "Highlord Bolvar Fordragon", zone = "Stormwind City", map = STORMWIND, x = 78.2, y = 18.3, reqlevel = 48 },
    { id = 4186, name = "The True Masters",         giver = "Highlord Bolvar Fordragon", zone = "Stormwind City", map = STORMWIND, x = 78.2, y = 18.3, reqlevel = 48 },
    { id = 4223, name = "The True Masters",         giver = "Magistrate Solomon",  zone = "Redridge Mountains", map = REDRIDGE,   x = 29.9, y = 53.5, reqlevel = 48 },
    { id = 4224, name = "The True Masters",         giver = "Ragged John (Burning Steppes)", zone = "Burning Steppes", map = BURNING_STEPPES, x = 65.1, y = 23.9, reqlevel = 48 },
    { id = 4241, name = "Marshal Windsor",          giver = "Marshal Maxwell",     zone = "Burning Steppes", map = BURNING_STEPPES, x = 85.8, y = 68.7, kind = "dungeon", note = "Blackrock Depths. Windsor is in the Detention Block cells.", reqlevel = 48 },
    { id = 4242, name = "Abandoned Hope",           giver = "Marshal Windsor (BRD cell)", zone = "Blackrock Depths", map = BURNING_STEPPES, x = 42.0, y = 83.0, kind = "dungeon", reqlevel = 48 },
    { id = 4264, name = "A Crumpled Up Note",       giver = "Drops from BRD trash (Detention Block)", zone = "Blackrock Depths", map = BURNING_STEPPES, x = 42.0, y = 83.0, kind = "dungeon", startItem = "A Crumpled Up Note", startSource = "Random drop from Blackrock Depths Detention Block trash after speaking with Marshal Windsor. Use the note to start the quest.", note = "Random drop. Keep killing until it drops, then give it to Windsor.", reqlevel = 50 },
    { id = 4282, name = "A Shred of Hope",          giver = "Marshal Windsor (BRD cell)", zone = "Blackrock Depths", map = BURNING_STEPPES, x = 42.0, y = 83.0, kind = "dungeon", note = "Kill General Angerforge and Golem Lord Argelmach.", reqlevel = 50 },
    { id = 4322, name = "Jail Break!",              giver = "Marshal Windsor (BRD cell)", zone = "Blackrock Depths", map = BURNING_STEPPES, x = 42.0, y = 83.0, kind = "dungeon", note = "Escort. Clear Detention Block first. Do NOT let anyone auto-accept for you.", reqlevel = 50 },
    { id = 6402, name = "Stormwind Rendezvous",     giver = "Marshal Maxwell",     zone = "Burning Steppes", map = BURNING_STEPPES, x = 85.8, y = 68.7, note = "Meet Windsor at the Stormwind gates. Walk with him.", reqlevel = 50 },
    { id = 6403, name = "The Great Masquerade",     giver = "Marshal Windsor (Stormwind Keep)", zone = "Stormwind City", map = STORMWIND, x = 78.2, y = 18.3, note = "THE reveal. Stay for the whole event, then speak to Bolvar.", reqlevel = 50 },
    { id = 6501, name = "The Dragon's Eye",         giver = "Highlord Bolvar Fordragon", zone = "Stormwind City", map = STORMWIND, x = 78.2, y = 18.3, reqlevel = 50 },
    { id = 6502, name = "Drakefire Amulet",         giver = "Haleh (Mazthoril, Winterspring)", zone = "Winterspring", x = 54.5, y = 51.5, kind = "dungeon", note = "UBRS: the Blood of Drakkisath. This amulet opens Onyxia's Lair.", reqlevel = 50 },
  } },
}

if ns.RegisterChains then ns.RegisterChains(chains)
else for _, c in ipairs(chains) do ns.Chains[#ns.Chains + 1] = c end end

