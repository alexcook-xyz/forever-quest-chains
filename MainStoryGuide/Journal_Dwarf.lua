-- MainStoryGuide: Dwarf saga journal (issue #13).
--
-- Hand-written prose, one page per chain quest and one epilogue per chain.
-- Close third person, world-focused; facts only from the Questie/PandaBase
-- facts in tools/sagas/dwarf.facts.json (tests/test_story_voice.py).

local _, ns = ...
ns.JournalEntries = ns.JournalEntries or {}
ns.JournalEpilogues = ns.JournalEpilogues or {}

local E = {
-- Trouble in Coldridge Valley ---------------------------------
[179] = { title = "Meat for the Outfitter",
  body = "Coldridge Valley lies in Dun Morogh. Sten Stoutarm asked for eight pieces of Tough Wolf Meat. The wolves of the valley were hunted across the snow until the count was met. The meat was carried back and laid before Sten Stoutarm. In a frozen valley, provision is the first defense." },
[170] = { title = "Troggs in the Valley",
  body = "Balir Frosthammer named a new threat to Coldridge Valley: the Rockjaw Troggs. Six Rockjaw Troggs and six Burly Rockjaw Troggs were cut down across the valley. The count of the fallen was reported to Balir Frosthammer. Steel answered the threat, and the ranks of the troggs were thinned." },
[233] = { title = "Letters on the Road",
  body = "Sten Stoutarm entrusted a stack of letters to the road. The bundle was carried through Coldridge Valley and delivered into the hands of Talin Keeneye. Even with troggs in the valley, the mail still moved. The stack of letters had reached its mark, and the duty was done." },
[234] = { title = "The Second Letter",
  body = "Talin Keeneye passed a letter onward along the valley road. It was delivered to Grelin Whitebeard, completing the second leg of the Coldridge Valley mail. Each hand that carried it kept the mail moving. The letter rested at last with Grelin Whitebeard, and the work of the valley went on." },
[182] = { title = "The Troll Cave",
  body = "Grelin Whitebeard turned his gaze to the troll cave of Coldridge Valley. Fourteen Frostmane Troll Whelps were slain there at his request. The whelps fell one by one among the cold stone of the cave. Word of the deed was brought back to Grelin Whitebeard. The cave grew quieter." },
[218] = { title = "The Stolen Journal",
  body = "Grelin Whitebeard wanted the journal of Grik'nir the Cold. Grik'nir the Cold was slain, and the journal was taken from him. The pages were carried back across the valley to Grelin Whitebeard. What Grik'nir the Cold had held was his no longer. The journal now rested with Grelin Whitebeard." },
[282] = { title = "Word to the Mountaineer",
  body = "The charge from Grelin Whitebeard was a plain one. At his word, Mountaineer Thalos was sought out and spoken with. The road ran through the cold of Dun Morogh, and the mountaineer was found. Nothing more was asked than that meeting. One errand ended so that the next could begin." },
[420] = { title = "The Report to Kharanos",
  body = "Mountaineer Thalos set Grelin's report on its road to Kharanos. The report was carried through the cold of Dun Morogh. In Kharanos it was placed in the hands of Senir Whitebeard. The errand begun with Mountaineer Thalos was complete. Grelin's report now rested with Senir Whitebeard." },
-- The Frostmane Hold ------------------------------------------
[287] = { title = "Into Frostmane Hold",
  body = "The charge came from Senir Whitebeard in Kharanos. Frostmane Hold was explored in the cold of Dun Morogh. Five Frostmane Headhunters fell before the search was done. The findings returned to Senir Whitebeard in Kharanos. Frostmane Hold had been walked from end to end, and its headhunters were fewer for it." },
[98322] = { title = "The Western Watch",
  body = "From Kharanos, attention turned west. Senir Whitebeard asked after the mountain beyond the town. The road led west of Kharanos, into the high snows of Dun Morogh. The check-in was made at Mountaineer Gretchen's post. In Dun Morogh, the high country is held one post at a time." },
[98319] = { title = "The Grizzled Den",
  body = "Mountaineer Gretchen needed word of Mountaineer Cornelius. The search led into the Grizzled Den, and there Mountaineer Cornelius was found. Word of him was carried back to Mountaineer Gretchen at her post west of Kharanos. Another guardian of the mountain was accounted for. The watch on the peaks endures only while each of its posts is known." },
[98323] = { title = "Gretchen's Report",
  body = "Mountaineer Gretchen set down her account of the watch in a written report. Mountaineer Gretchen's Report was carried east from her post and delivered to Senir Whitebeard in Kharanos. The western mountain had spoken through her words. Senir Whitebeard now held the measure of the watch beside the findings from Frostmane Hold. Scattered accounts were becoming a single picture." },
[291] = { title = "Word to Ironforge",
  body = "Senir's report was ready for Ironforge. It left Kharanos and climbed the road to the city. It was delivered into the hands of Senator Barin Redstone. The findings from the hold and the mountain watch now stood before the city. What began in the snows of Dun Morogh reached the halls of Ironforge." },
-- In Defense of the King's Lands ------------------------------
[224] = { title = "The Southern Watch",
  body = "Mountaineer Cobbleflint kept watch from the southern guard tower of Loch Modan. Across Loch Modan, Stonesplinter Troggs and Stonesplinter Scouts prowled. Ten of each were slain, and the report reached Mountaineer Cobbleflint at the tower. The King's Lands held, for now, under the watch of the southern guard tower." },
[267] = { title = "Teeth of Stone",
  body = "Captain Rugelfuss of the southern guard tower called for Trogg Stone Teeth. Eight Trogg Stone Teeth were gathered and laid before him. The captain received the grim tally at his post. Each tooth was a hard, cold token. It was proof, in stone, of the trogg threat." },
[237] = { title = "Skullthumpers and Seers",
  body = "More of the Stonesplinter remained. Mountaineer Gravelgaw of the southern guard tower named the next foes: the Stonesplinter Skullthumpers and the Stonesplinter Seers. Ten of each fell in the fighting. The report reached Gravelgaw at his post. The watch on the tower grew no lighter, but the Stonesplinter ranks grew thinner." },
[263] = { title = "Shaman and Bonesnappers",
  body = "Mountaineer Wallbang held his own charge at the southern guard tower. His orders named the Stonesplinter Shaman and the Stonesplinter Bonesnappers. Ten of each were slain among the troggs of Loch Modan. Wallbang received the news at his post. Another rank of the Stonesplinter had fallen before the King's Lands." },
[217] = { title = "The Fall of Grawmug",
  body = "Captain Rugelfuss named the final foes: the trogg leader, Grawmug, and his two guards, Gnasher and Brawler. Grawmug was slain. Gnasher and Brawler were slain as well. The report was carried back to the captain in the southern guard tower. The troggs had lost their leader." },
-- Ironband's Excavation ---------------------------------------
[298] = { title = "The Prospector's Report",
  body = "Prospector Ironband kept a dig in Loch Modan, and the progress of that work was set down in writing. Ironband's Progress Report was carried from the excavation to Thelsamar. Jern Hornhelm received the pages in the town. The record of the dig now rested in Thelsamar." },
[301] = { title = "Word to Ironforge",
  body = "The report did not end its road in Thelsamar. Jern Hornhelm sent Ironband's Progress Report onward, out of Loch Modan and into Ironforge. Prospector Stormpike took the pages within the city. Word from a distant dig is easily lost; this word was not. News of the excavation now stood before Ironforge itself." },
[302] = { title = "The Road Back",
  body = "The errand did not end in Ironforge. Prospector Stormpike sent it back toward Loch Modan, an errand of powder for Ironband. Jern Hornhelm was sought out once more in Thelsamar and spoken with there. The matter of the excavation returned to the town that had first sent the report onward. Between Ironforge and the loch, the dig was not forgotten." },
[273] = { title = "Seeking Huldar",
  body = "The excavation stood in need of resupply, and Jern Hornhelm directed the effort toward Huldar. The errand left Thelsamar and passed onward through Loch Modan. Huldar was found, and words were exchanged over the needs of the dig. The resupply of the excavation began with Huldar." },
[454] = { title = "After the Ambush",
  body = "After the ambush, Huldar sent word onward to Miran. Miran was found in Loch Modan and spoken with in turn. The resupply of Ironband's Excavation passed from Huldar to Miran. One hand gave the errand to the next, and the dig still waited on its supplies." },
[309] = { title = "The Shipment Arrives",
  body = "Miran and the shipment arrived at the excavation site, and Prospector Ironband was informed. The resupply that began with Jern Hornhelm in Thelsamar had passed from Huldar to Miran, and through Miran it reached the dig. What the excavation lacked had at last been brought to it." },
[436] = { title = "Explorer Fellhew",
  body = "With the excavation supplied, Jern Hornhelm directed attention toward another figure in Loch Modan. The errand left Thelsamar once more, bound for the explorer. Magmar Fellhew, called Explorer Fellhew, was sought out and found. Words were exchanged in the name of Ironband's Excavation. Where the earth is opened, the explorers follow." },
[297] = { title = "Idols of Stone",
  body = "Magmar Fellhew asked for Carved Stone Idols. Eight were gathered and laid before him in Loch Modan. Each of them was carved from stone. Fellhew received them all, and the count was complete. Whatever the idols mean, they now rest in the keeping of an explorer." },
-- A Dark Threat Looms -----------------------------------------
[250] = { title = "The Eastern Ramp",
  body = "Chief Engineer Hinderweir VII sought a clue to the doings of the Dark Iron Dwarves. The area near the eastern ramp of the Dam in Loch Modan was searched for any sign of their work. There, a Suspicious Barrel waited. The first thread of the plot had been found." },
[199] = { title = "A Clue Returned",
  body = "The Suspicious Barrel yielded a clue, and it was carried back from the eastern ramp of the Dam. Chief Engineer Hinderweir VII in Loch Modan was shown what had been discovered. The question of what the Dark Iron Dwarves were up to still stood unanswered. The Dark Iron Dwarves had left their mark near the Dam." },
[161] = { title = "The Road to Dun Modr",
  body = "The clue was a strange smelling powder. Chief Engineer Hinderweir VII sent it on to Ashlan Stonesmirk, the explosives expert in Dun Modr. The road led out of Loch Modan and into the Wetlands. There the sample was placed in his hands. The powder had left the Dam behind." },
[274] = { title = "A Discovery in Dun Modr",
  body = "Ashlan Stonesmirk studied the strange smelling powder in Dun Modr. His examination brought a new discovery to light. The finding could not be left waiting long. Word of it was carried out of the Wetlands, back to Loch Modan. Chief Engineer Hinderweir VII heard of the new discovery." },
[278] = { title = "Three Ingredients",
  body = "Chief Engineer Hinderweir VII called for three things: Lurker Venom, a Mo'grosh Crystal, and a Crocolisk Tear. Each was gathered and brought before him. The work was grim and patient, the kind that wins no songs. No part of the task was left undone. The engineer had what he required." },
[280] = { title = "Beneath the Dam",
  body = "The Disarming Mixture was carried down into the dark water below the Dam. At its base waited the powder keg, an Explosive Charge. The mixture was stirred into the powder to prevent an explosion. Cold depths pressed close while the work was done. Beneath the waters of Loch Modan, ruin had waited in silence." },
[283] = { title = "The Dam Endures",
  body = "The Disarming Mixture seemed to take effect within the Explosive Charge. Good news was carried up from the depths to Chief Engineer Hinderweir VII. Whatever the Dark Iron Dwarves were up to, the charge beneath the Dam appeared to be quieted. The waters of Loch Modan held still. For now, the Dam endured." },
}
for id, e in pairs(E) do ns.JournalEntries[id] = e end

local P = {
coldridge = { title = "Epilogue: Trouble in Coldridge Valley",
  body = "The trouble in Coldridge Valley was answered blade by blade and letter by letter. Rockjaw Troggs and Frostmane Troll Whelps were cut down, and Grik'nir the Cold fell and his journal was taken. Letters passed from Sten Stoutarm to Talin Keeneye, and from Talin Keeneye to Grelin Whitebeard. Grelin's report rested at last with Senir Whitebeard in Kharanos." },
frostmane = { title = "Epilogue: The Frostmane Hold",
  body = "Frostmane Hold was explored, and five Frostmane Headhunters fell. The western watch was checked, Mountaineer Cornelius was found in the Grizzled Den, and Mountaineer Gretchen's Report reached Kharanos. Senir's report was carried to Ironforge. There it reached Senator Barin Redstone. What was seen in the snows of Dun Morogh now rests before the city." },
kings_lands = { title = "Epilogue: In Defense of the King's Lands",
  body = "The orders came from the southern guard tower of Loch Modan, from its mountaineers and from Captain Rugelfuss. Stonesplinter Troggs, Scouts, Skullthumpers, Seers, Shaman and Bonesnappers were slain in turn. Grawmug, Gnasher and Brawler fell last, and Captain Rugelfuss received the final report. So ended the defense of the King's Lands." },
excavation = { title = "Epilogue: Ironband's Excavation",
  body = "Ironband's Progress Report was carried from Loch Modan to Prospector Stormpike in Ironforge, and word then returned to Jern Hornhelm in Thelsamar. The resupply passed from Jern Hornhelm to Huldar and on to Miran. Miran and the shipment reached the excavation site. Magmar Fellhew received eight Carved Stone Idols. Ironband's Excavation still stands in Loch Modan." },
dark_threat = { title = "Epilogue: A Dark Threat Looms",
  body = "A Suspicious Barrel near the eastern ramp began it, and a strange smelling powder carried the question to Dun Modr. Ashlan Stonesmirk made a new discovery there. Lurker Venom, a Mo'grosh Crystal, and a Crocolisk Tear were gathered, and the Disarming Mixture was stirred into the powder keg at the base of the Dam. Chief Engineer Hinderweir VII received the good news, and the Dam endured." },
}
for id, e in pairs(P) do ns.JournalEpilogues[id] = e end
