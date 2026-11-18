-- MainStoryGuide Route data: Human storyline.
--
-- ONE linear route through the whole saga, in intended story order.
-- Storylines that overlap in level are interleaved where the narrative
-- and geography meet (e.g. Redridge Under Siege is taken between the Defias
-- chapters). A chain never starts before its quests can be accepted: the
-- Missing Diplomat needs level 28, so it follows the Duskwood chapter.
-- INVARIANT: within the master order, every chain's quests keep the
-- relative order they have in Data_Human.lua and Data_HumanDiplomat.lua.
-- tests/test_human_baseline.py asserts this.
--
-- RouteInfo[questID] = {
--   task = "what to do, in one or two plain sentences",
--   turn = { name=, zone=, map=, x=, y= }  -- only when the turn-in is
-- }                                        -- NOT the quest giver.
-- Waypoints pin accept and turn-in NPCs (giver coords are in
-- Data_Human.lua). Objective locations are described in task text,
-- the same way the quest text itself describes them.

local _, ns = ...

local ELWYNN, WESTFALL, REDRIDGE, DUSKWOOD = 1429, 1436, 1433, 1431
local STORMWIND, DUSTWALLOW, WETLANDS = 1453, 1445, 1437
local BURNING_STEPPES = 1428

-- The master route: segments noted at each interleave.
local HUMAN_ROUTE = {
  -- Chapter I: Northshire's Defence (1-6)
  783, 7, 15, 21, 18, 6, 3903, 54,
  -- Chapter II: Shadows over Elwynn (5-11)
  3904, 3905, 62, 76, 35, 37, 45, 71, 39, 52, 11, 176, 123, 147, 239,
  -- Chapter III: The People's Militia (9-15)
  109, 12, 13, 14, 102,
  -- Chapter IV opens: the Defias investigation goes to Stormwind
  65, 132, 135,
  -- Back to Westfall with Shaw's report
  141, 142,
  -- Overlap: Redridge Under Siege (15-25), before the Deadmines finale
  244, 20, 34, 125, 89, 91,
  -- Chapter IV closes: the Defias traitor, VanCleef, the Unsent Letter
  155, 166, 373,
  -- Chapter VI: The Stockade Uprising (22-29) - gather, then one descent
  377, 386, 387, 388, 389, 391,
  -- Chapter VII: The Legend of Stalvan (22-32)
  66, 67, 68, 69, 70, 72, 74, 75, 78, 79, 80, 97, 98,
  -- Chapter VIII: The Darkness of Duskwood (25-35)
  56, 57, 58, 95, 230, 262, 265, 266, 453, 268,
  -- Sven's road to Morbent Fel: Stormwind, the Wetlands wreck, back to Duskwood
  323, 269, 270, 321, 324, 322, 325, 55,
  -- Chapter IX: The Missing Diplomat (28-38): Stormwind, Duskwood, the Wetlands, Theramore
  1274, 1241, 1242, 1243, 1244, 1245, 1246, 1447, 1247, 1248, 1249, 1250, 1264, 1265, 1266, 1324, 1267,
  -- Chapter X: Onyxia - The True Masters (48-60)
  4182, 4183, 4184, 4185, 4186, 4223, 4224, 4241, 4242, 4264, 4282, 4322,
  6402, 6403, 6501, 6502,
}
if ns.RegisterRoute then ns.RegisterRoute("Human", HUMAN_ROUTE) else ns.StoryRoute = HUMAN_ROUTE end

local R = {
-- Northshire -------------------------------------------------------------
[783]  = { task = "Enter Northshire Abbey and report to Marshal McBride inside.",
  turn = { name = "Marshal McBride", zone = "Elwynn Forest", map = ELWYNN, x = 48.9, y = 41.6 } },
[7]    = { task = "Kill Kobold Vermin in the fields and vineyard north of the Abbey." },
[15]   = { task = "Enter the Echo Ridge Mine north of the Abbey and kill Kobold Workers to scout their numbers." },
[21]   = { task = "Fight through Echo Ridge Mine and kill Kobold Laborers to clear it." },
[18]   = { task = "Kill Defias Thugs in the vineyard southeast of the Abbey and bring back their red bandanas." },
[6]    = { task = "Kill Garrick Padfoot, leader of the vineyard Defias southeast of the Abbey, and bring back his head." },
[54]   = { task = "Follow the road south from Northshire to Goldshire and deliver McBride's report to Marshal Dughan.",
  turn = { name = "Marshal Dughan", zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9 } },
-- Elwynn -----------------------------------------------------------------
[3903] = { task = "Deputy Willem asks you to find Milly Osworth at the Northshire vineyard.",
  turn = { name = "Milly Osworth", zone = "Elwynn Forest", map = ELWYNN, x = 50.7, y = 39.4 } },
[3904] = { task = "Gather bunches of grapes from the Milly's vineyard rows, despite the Defias loitering there." },
[3905] = { task = "Deliver Milly's Grape Manifest to Brother Neals at Northshire Abbey.",
  turn = { name = "Brother Neals (Northshire Abbey)", zone = "Elwynn Forest", map = ELWYNN, x = 49.9, y = 41.9 } },
[62]   = { task = "Explore the Fargodeep Mine south of Goldshire and confirm it is overrun by kobolds. Fully exploring the mine completes it - killing is optional." },
[76]   = { task = "Explore the Jasperlode Mine east of Goldshire and confirm kobolds hold it too." },
[35]   = { task = "Travel east along the road to the bridge by Eastvale and report to Guard Thomas.",
  turn = { name = "Guard Thomas", zone = "Elwynn Forest", map = ELWYNN, x = 74.0, y = 72.4 } },
[37]   = { task = "Search Stone Cairn Lake, east across the river, for the lost guards Rolf and Malakai among the murlocs." },
[45]   = { task = "Find Rolf's corpse at the murloc village on Stone Cairn Lake and learn his fate.",
  turn = { name = "Rolf's corpse (Stone Cairn Lake)", zone = "Elwynn Forest", map = ELWYNN, x = 72.7, y = 60.3 } },
[71]   = { task = "Carry word of Rolf's death back west to Guard Thomas at the bridge.",
  turn = { name = "Guard Thomas", zone = "Elwynn Forest", map = ELWYNN, x = 74.0, y = 72.4 } },
[39]   = { task = "Deliver Guard Thomas' written report back to Marshal Dughan in Goldshire.",
  turn = { name = "Marshal Dughan", zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9 } },
[52]   = { task = "Cull Prowlers and Young Forest Bears along the eastern frontier roads near the bridge and Eastvale." },
[123]  = { task = "This quest begins from a Gold Pickup Schedule: a very rare drop from Riverpaw Runt and Riverpaw Outrunner gnolls in southwestern Elwynn (Gruff Swiftbite always carries one). Use the schedule to accept it, then take it to Marshal Dughan in Goldshire. If none drops, the saga continues and returns to this page when you find one.",
  turn = { name = "Marshal Dughan", zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9 } },
[147]  = { task = "Take Marshal Dughan's order: hunt down the Collector in southwestern Elwynn and bring back The Collector's Ring.",
  turn = { name = "Marshal Dughan", zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9 } },
[11]   = { task = "Kill Riverpaw gnolls in southwestern Elwynn and bring their Painted Gnoll Armbands to Deputy Rainer at Westbrook Garrison.",
         hint = "A Gold Pickup Schedule can drop from the gnolls while looting. It starts the quest for the old pickup schedule." },
[176]  = { task = "Read the Wanted Poster at Westbrook Garrison, hunt Hogger in southwestern Elwynn (group recommended), and bring back his Huge Gnoll Claw.",
  turn = { name = "Marshal Dughan", zone = "Elwynn Forest", map = ELWYNN, x = 42.1, y = 65.9 },
  obj = { name = "Hogger (roams)", zone = "Elwynn Forest", map = ELWYNN, x = 26.1, y = 89.9, src = "rxp" } },
[239]  = { task = "Report to Deputy Rainer at Westbrook Garrison, on the western border of Elwynn.",
  turn = { name = "Deputy Rainer (Westbrook Garrison)", zone = "Elwynn Forest", map = ELWYNN, x = 24.4, y = 74.7 } },
-- People's Militia ---------------------------------------------------------
[109]  = { task = "Cross into Westfall and report to Gryan Stoutmantle at Sentinel Hill.",
  turn = { name = "Gryan Stoutmantle", zone = "Westfall", map = WESTFALL, x = 56.4, y = 47.5 } },
[12]   = { task = "Kill Defias Trappers and Smugglers on the farms around Sentinel Hill." },
[13]   = { task = "Kill Defias Pillagers and Looters on the outlying farms (Moonbrook and the Dagger Hills side)." },
[14]   = { task = "Kill Defias Highwaymen, Pathstalkers and Knuckledusters holding the roads and hills of Westfall." },
[102]  = { task = "Cull Riverpaw gnolls infesting Westfall's farms and bring Captain Danuvin 8 Gnoll Paws." },
}
ns.RouteInfo = ns.RouteInfo or {}
for id, r in pairs(R) do ns.RouteInfo[id] = r end

R = {
-- Defias Brotherhood -------------------------------------------------------
[65]   = { task = "Begin Stoutmantle's investigation: seek the contact who owes him a favor and can speak of the Brotherhood's leadership." },
[132]  = { task = "Take Wiley's Note from Lakeshire back to Gryan Stoutmantle at Sentinel Hill in Westfall.",
  turn = { name = "Gryan Stoutmantle", zone = "Westfall", map = WESTFALL, x = 56.4, y = 47.5 } },
[135]  = { task = "Take Wiley's Note from Gryan Stoutmantle to Master Mathias Shaw at SI:7 in Stormwind.",
  turn = { name = "Master Mathias Shaw", zone = "Stormwind City", map = STORMWIND, x = 78.7, y = 60.1 } },
[141]  = { task = "Take Master Mathias Shaw's report from SI:7 in Stormwind back to Gryan Stoutmantle at Sentinel Hill.",
  turn = { name = "Gryan Stoutmantle", zone = "Westfall", map = WESTFALL, x = 56.4, y = 47.5 } },
[142]  = { task = "Track down the Defias Messenger in Westfall and bring his message to Gryan Stoutmantle.",
  turn = { name = "Gryan Stoutmantle", zone = "Westfall", map = WESTFALL, x = 56.4, y = 47.5 } },
[155]  = { task = "Escort the Defias Traitor to the Defias hideout in Westfall, then report what he showed you to Gryan Stoutmantle.",
  turn = { name = "Gryan Stoutmantle", zone = "Westfall", map = WESTFALL, x = 56.4, y = 47.5 } },
[166]  = { task = "DUNGEON: The Deadmines (entrance in Moonbrook, group). Fight to the ship and bring back the Head of Edwin VanCleef." },
[373]  = { task = "This quest begins from An Unsent Letter, dropped by Edwin VanCleef in the Deadmines. Deliver it to Baros Alexston in Stormwind City (Cathedral Square).",
  turn = { name = "Baros Alexston", zone = "Stormwind City", map = STORMWIND, x = 49.8, y = 57.3 } },
-- Redridge -----------------------------------------------------------------
[244]  = { task = "Travel east to Lakeshire in Redridge Mountains and report on the gnoll threat as Marshal Dughan directs.",
  turn = { name = "Deputy Feldon (Lakeshire)", zone = "Redridge Mountains", map = REDRIDGE, x = 26.4, y = 44.0 } },
[20]   = { task = "Kill Blackrock orcs (Champions and their kin) in the canyons north of Lakeshire for Marshal Marris." },
[34]   = { task = "Kill Bellygrub, the monstrous boar ravaging the farms south of Lakeshire, and bring Guard Parker his tusk." },
[125]  = { task = "Recover Foreman Oslow's toolbox from the bottom of Lake Everstill and bring it back to him in Lakeshire." },
[89]   = { task = "Recover Foreman Oslow's stolen tools and supplies (from gnolls and orcs around Lake Everstill) so the bridge work can continue." },
[91]   = { task = "Enforce Magistrate Solomon's law: kill the Blackrock orcs he names on Redridge's borders and bring proof." },
-- Stockade -----------------------------------------------------------------
[377]  = { task = "DUNGEON (gather now, do in the Stockade run below): kill Dextren Ward in the Stormwind Stockade." },
[386]  = { task = "DUNGEON (gather now, do in the Stockade run): bring Guard Berton the head of Targorr the Dread, in the Stockade." },
[387]  = { task = "DUNGEON - THE STOCKADE RUN (take all Stockade quests in together): kill the Defias Prisoners, Convicts and Insurgents in the Stockade for Warden Thelwater." },
[388]  = { task = "DUNGEON (same Stockade run): collect the Defias prisoners' bandanas for Nikova Raskol." },
[389]  = { task = "Take Baros Alexston's lead to Warden Thelwater at the Stockade entrance in Stormwind (pick it up now, hand it in on the Stockade run).",
  turn = { name = "Warden Thelwater", zone = "Stormwind City", map = STORMWIND, x = 51.5, y = 69.4 } },
[391]  = { task = "DUNGEON (same Stockade run): kill Bazil Thredd and bring his head back to Warden Thelwater." },
-- Stalvan ------------------------------------------------------------------
[66]   = { task = "This story begins from A Faded Journal Page, found in a footlocker in Moonbrook's schoolhouse (southern Westfall). Read it to begin." },
[67]   = { task = "Ask in Westfall about the name Stalvan Mistmantle and follow where the memory points: toward Duskwood's records." },
[68]   = { task = "Open the Old Footlocker at Moonbrook and take what it holds to Clerk Daltry in Darkshire.",
  turn = { name = "Clerk Daltry", zone = "Duskwood", map = DUSKWOOD, x = 72.6, y = 46.9 } },
[69]   = { task = "Search Clerk Daltry's town records in Darkshire (Duskwood) for entries on Stalvan Mistmantle." },
[70]   = { task = "Follow Daltry's records further - pages are missing, so chase the next surviving entry as directed." },
[72]   = { task = "Continue tracing Stalvan's employment as a tutor through the records Daltry can still provide." },
[74]   = { task = "Take what you have learned to Tobias Mistmantle, Stalvan's brother, in Stormwind (Cathedral Square)." },
[75]   = { task = "Read the family letters Tobias keeps, and follow what they reveal back toward Duskwood." },
[78]   = { task = "Hear the old tale from the Grandma in western Duskwood - the part of the story no record kept." },
[79]   = { task = "Report your findings to Commander Althea Ebonlocke of the Night Watch in Darkshire." },
[80]   = { task = "Carry Commander Ebonlocke's findings to Clerk Daltry in Darkshire so the records can be completed.",
  turn = { name = "Clerk Daltry", zone = "Duskwood", map = DUSKWOOD, x = 72.6, y = 46.9 } },
[97]   = { task = "Carry Daltry's completed findings across Darkshire to Commander Althea Ebonlocke.",
  turn = { name = "Commander Althea Ebonlocke", zone = "Duskwood", map = DUSKWOOD, x = 73.5, y = 46.8 } },
[98]   = { task = "Go to Manor Mistmantle in northern Duskwood, destroy Stalvan Mistmantle when he appears, and bring the Mistmantle Family Ring to Madame Eva (group recommended).",
  turn = { name = "Madame Eva", zone = "Duskwood", map = DUSKWOOD, x = 75.7, y = 45.3 },
  obj = { name = "Stalvan Mistmantle", zone = "Duskwood", map = DUSKWOOD, x = 77.4, y = 36.1, src = "rxp" } },
-- Darkness of Duskwood -------------------------------------------------------
[56]   = { task = "Kill 8 Skeletal Warriors and 6 Skeletal Mages for Commander Althea Ebonlocke of the Night Watch in Darkshire." },
[57]   = { task = "Do the Night Watch's work for Commander Ebonlocke: cull the undead pressing out of Raven Hill and Duskwood's dark corners." },
[58]   = { task = "Kill 20 Plague Spreaders around the Raven Hill crypts west of Darkshire for Commander Ebonlocke.",
  obj = { name = "Plague Spreaders", zone = "Duskwood", map = DUSKWOOD, x = 23.6, y = 35.0, src = "rxp" } },
[95]   = { task = "Speak with Sven Yorgen in far western Duskwood and take up his revenge." },
[230]  = { task = "Go to Sven's camp in southern Duskwood.",
  turn = { name = "Sven Yorgen", zone = "Duskwood", map = DUSKWOOD, x = 7.8, y = 34.1 } },
[262]  = { task = "Return to Sven Yorgen in far western Duskwood about the shadowy figure.",
  turn = { name = "Madame Eva", zone = "Duskwood", map = DUSKWOOD, x = 75.7, y = 45.3 } },
[265]  = { task = "Speak with Madame Eva and carry on the search for the shadowy figure.",
  turn = { name = "Clerk Daltry", zone = "Duskwood", map = DUSKWOOD, x = 72.6, y = 46.9 } },
[266]  = { task = "Speak with Clerk Daltry in Darkshire, then inquire at the inn.",
  turn = { name = "Tavernkeep Smitts", zone = "Duskwood", map = DUSKWOOD, x = 73.9, y = 44.4 } },
[453]  = { task = "Speak with Tavernkeep Smitts and find the shadowy figure.",
  turn = { name = "Jitters", zone = "Duskwood", map = DUSKWOOD, x = 18.4, y = 56.5 } },
[268]  = { task = "Speak with Jitters in western Duskwood, then return to Sven Yorgen.",
  turn = { name = "Sven Yorgen", zone = "Duskwood", map = DUSKWOOD, x = 7.7, y = 34.1 } },
[323]  = { task = "Kill 15 Skeletal Raiders, 3 Skeletal Healers and 3 Skeletal Warders, then return to Sven Yorgen." },
[269]  = { task = "Give Jitters' Completed Journal to Bishop Farthing in Stormwind.",
  turn = { name = "Bishop Farthing", zone = "Stormwind City", map = STORMWIND, x = 49.9, y = 46.0 } },
[270]  = { task = "Go to Menethil Harbor in the Wetlands and speak with Glorin Steelbrow.",
  turn = { name = "Glorin Steelbrow", zone = "Wetlands", map = WETLANDS, x = 10.6, y = 60.6 } },
[321]  = { task = "Search the wreckage of The Flying Osprey in the Wetlands for the Waterlogged Chest.",
  turn = { name = "Waterlogged Chest", zone = "Wetlands", map = WETLANDS, x = 12.1, y = 64.2 } },
[324]  = { task = "This quest begins at the Waterlogged Chest. Gather 5 Lightforge Ingots, then return to Glorin Steelbrow in Menethil Harbor.",
  turn = { name = "Glorin Steelbrow", zone = "Wetlands", map = WETLANDS, x = 10.6, y = 60.6 } },
[322]  = { task = "Take the Crate of Lightforge Ingots to Grimand Elmore in Stormwind.",
  turn = { name = "Grimand Elmore", zone = "Stormwind City", map = STORMWIND, x = 59.7, y = 33.8 } },
[325]  = { task = "Bring Morbent's Bane to Sven Yorgen in Duskwood.",
  turn = { name = "Sven Yorgen", zone = "Duskwood", map = DUSKWOOD, x = 7.8, y = 34.1 } },
[55]   = { task = "Use Morbent's Bane on Morbent Fel, kill him, then return the Bane to Sven Yorgen at his camp." },
-- Missing Diplomat -----------------------------------------------------------
[1274] = { task = "Travel to Stormwind City, speak to Thomas, then find Bishop DeLavey in Stormwind Keep.",
  turn = { name = "Bishop DeLavey", zone = "Stormwind City", map = STORMWIND, x = 80.2, y = 44.1 } },
[1241] = { task = "Find Jorgen in Stormwind City, the next step of the trail.",
  turn = { name = "Jorgen", zone = "Stormwind City", map = STORMWIND, x = 76.3, y = 85.1 } },
[1242] = { task = "Deliver Jorgen's Sealed Note to Elling Trias in Stormwind City.",
  turn = { name = "Elling Trias", zone = "Stormwind City", map = STORMWIND, x = 66.0, y = 74.1 } },
[1243] = { task = "Give the Sealed Note to Watcher Backus in Duskwood.",
  turn = { name = "Watcher Backus", zone = "Duskwood", map = DUSKWOOD, x = 74.8, y = 44.2 } },
[1244] = { task = "Find the Defias Docket and return it to Watcher Backus in Duskwood." },
[1245] = { task = "Bring the Defias Docket to Elling Trias in Stormwind.",
  turn = { name = "Elling Trias", zone = "Stormwind City", map = STORMWIND, x = 66.0, y = 74.1 } },
[1246] = { task = "Speak to Dashel Stonefist in Stormwind.",
  turn = { name = "Dashel Stonefist", zone = "Stormwind City", map = STORMWIND, x = 74.3, y = 59.2 } },
[1447] = { task = "Defeat Dashel Stonefist in Stormwind.",
  obj = { name = "Dashel Stonefist", zone = "Stormwind City", map = STORMWIND, x = 74.3, y = 59.2, src = "questie" } },
[1247] = { task = "Speak to Elling Trias in Stormwind.",
  turn = { name = "Elling Trias", zone = "Stormwind City", map = STORMWIND, x = 66.0, y = 74.1 } },
[1248] = { task = "Follow Elling Trias's lead north to Menethil Harbor and report to Mikhail at the inn.",
  turn = { name = "Mikhail", zone = "Wetlands", map = WETLANDS, x = 10.6, y = 60.8 } },
[1249] = { task = "Subdue Tapoke \"Slim\" Jahn before he escapes, then return to Mikhail in Menethil Harbor.",
  obj = { name = "Tapoke \"Slim\" Jahn", zone = "Wetlands", map = WETLANDS, x = 10.5, y = 60.3, src = "questie" } },
[1250] = { task = "Question the beaten Tapoke Jahn, then carry what he reveals back to Mikhail.",
  turn = { name = "Mikhail", zone = "Wetlands", map = WETLANDS, x = 10.6, y = 60.8 } },
[1264] = { task = "Sail to Kalimdor and find Commander Samaul in Dustwallow Marsh.",
  turn = { name = "Commander Samaul", zone = "Dustwallow Marsh", map = DUSTWALLOW, x = 68.0, y = 48.7 } },
[1265] = { task = "Search Sentry Point for any sign of Private Hendel.",
  turn = { name = "Archmage Tervosh", zone = "Dustwallow Marsh", map = DUSTWALLOW, x = 66.4, y = 49.3 } },
[1266] = { task = "Find Private Hendel in Dustwallow Marsh.",
  turn = { name = "Private Hendel", zone = "Dustwallow Marsh", map = DUSTWALLOW, x = 45.2, y = 24.6 } },
[1324] = { task = "Defeat Private Hendel in Dustwallow Marsh, then return to Archmage Tervosh with the result.",
  obj = { name = "Private Hendel", zone = "Dustwallow Marsh", map = DUSTWALLOW, x = 45.2, y = 24.6, src = "questie" },
  turn = { name = "Archmage Tervosh", zone = "Dustwallow Marsh", map = DUSTWALLOW, x = 66.4, y = 49.3 } },
[1267] = { task = "Present the whole trail to Lady Jaina Proudmoore in Dustwallow Marsh. Listen well: this chapter ends without the King, and that is the point." },
-- Onyxia ---------------------------------------------------------------------
[4182] = { task = "Kill Black dragonkin in the Burning Steppes for Helendis Riverhorn at Morgan's Vigil." },
[4183] = { task = "Take Marshal Maxwell's letter from Morgan's Vigil to Magistrate Solomon in Lakeshire, Redridge.",
  turn = { name = "Magistrate Solomon", zone = "Redridge Mountains", map = REDRIDGE, x = 29.9, y = 53.5 } },
[4184] = { task = "Carry Solomon's sealed letter onward to Highlord Bolvar Fordragon in Stormwind Keep.",
  turn = { name = "Highlord Bolvar Fordragon", zone = "Stormwind City", map = STORMWIND, x = 78.2, y = 18.3 } },
[4185] = { task = "Present the matter at court and take the court's response for Solomon.",
  turn = { name = "Magistrate Solomon", zone = "Redridge Mountains", map = REDRIDGE, x = 29.9, y = 53.5 } },
[4186] = { task = "Carry the chain of letters on as directed between the court, Solomon, and Maxwell. Watch who benefits from the delay." },
[4223] = { task = "Continue the letter chain back toward the Burning Steppes as directed; the investigation stops waiting on the court." },
[4224] = { task = "Find Ragged John at his fire in the Burning Steppes and hear the tale of Marshal Windsor." },
[4241] = { task = "DUNGEON: Blackrock Depths (group). Fight into the Detention Block and find Marshal Windsor in his cell." },
[4242] = { task = "Speak with Windsor in his cell, then carry his word back to Marshal Maxwell at Morgan's Vigil.",
  turn = { name = "Marshal Maxwell", zone = "Burning Steppes", map = BURNING_STEPPES, x = 85.8, y = 68.7 } },
[4264] = { task = "This quest begins from A Crumpled Up Note, dropped by Blackrock Depths Detention Block trash. Keep killing until it drops, then give it to Windsor.",
  turn = { name = "Marshal Windsor (BRD cell)", zone = "Blackrock Depths", map = BURNING_STEPPES, x = 42.0, y = 83.0 } },
[4282] = { task = "DUNGEON: Blackrock Depths. Kill General Angerforge and Golem Lord Argelmach to recover Windsor's lost papers." },
[4322] = { task = "DUNGEON ESCORT: clear the entire Detention Block FIRST, then accept Jail Break and escort Windsor out. Take care who accepts it first - the escort starts on accept." },
[6402] = { task = "Meet Marshal Windsor at the gates of Stormwind City and walk with him toward the Keep. Stay close." },
[6403] = { task = "Stay for the entire event in Stormwind Keep (do not leave mid-scene), then speak with Highlord Bolvar Fordragon to finish." },
[6501] = { task = "Take Bolvar's charge and seek Haleh, the blue dragon, hidden in Mazthoril cave in southern Winterspring." },
[6502] = { task = "DUNGEON: Upper Blackrock Spire (raid). Kill General Drakkisath and take his Blood, then return to Haleh in Mazthoril for the Drakefire Amulet - your key to Onyxia's Lair." },
}
for id, r in pairs(R) do ns.RouteInfo[id] = r end
