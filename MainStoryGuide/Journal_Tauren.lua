-- MainStoryGuide: Tauren saga journal.
--
-- Hand-written prose, one page per chain quest and one epilogue per chain.
-- Close third person, world-focused; every name, number and place comes from
-- the Questie/PandaBase facts in tools/sagas/tauren.facts.json and states no
-- motive or event that the facts do not give (tests/test_story_voice.py).

local _, ns = ...
ns.JournalEntries = ns.JournalEntries or {}
ns.JournalEpilogues = ns.JournalEpilogues or {}

local E = {
-- Camp Narache -------------------------------------------------
[747] = { title = "The Hunt Begins",
  body = "Grull Hawkwind in Camp Narache asked for 7 Plainstrider Feathers and 7 pieces of Plainstrider Meat. They were brought to Grull Hawkwind." },
[750] = { title = "The Hunt Continues",
  body = "Grull Hawkwind asked for 10 Mountain Cougar Pelts. They were brought to Grull Hawkwind in Camp Narache." },
[780] = { title = "The Battleboars",
  body = "Grull Hawkwind asked for the death of Battleboars. Eight Battleboar Snouts and 8 Battleboar Flanks went back to Grull Hawkwind in Camp Narache." },
[752] = { title = "A Humble Task",
  body = "Chief Hawkwind asked for a search for his mother near the water well to the southeast of Camp Narache. Greatmother Hawkwind was there." },
[753] = { title = "A Humble Task",
  body = "Greatmother Hawkwind asked for a Water Pitcher from the water well. It went to Chief Hawkwind in Camp Narache." },
[755] = { title = "Rites of the Earthmother",
  body = "Chief Hawkwind named Seer Graytongue, who lives in the hills directly south of Camp Narache. The road led to Seer Graytongue." },
[95805] = { title = "Grace of An'she and Mu'sha",
  body = "Seer Graytongue gave the Smoldering Incense, which burns to ash in ten minutes. It was carried to the shrine of An'she and Mu'sha in the southeastern hills, and the Ritual Fire there closed the task." },
[757] = { title = "Rite of Strength",
  body = "Seer Graytongue set the Rite of Strength: the Bristlebacks in Brambleblade Ravine. Twelve Bristleback Belts went to Chief Hawkwind in Camp Narache." },
[781] = { title = "Attack on Camp Narache",
  body = "A Dirt-stained Map opened this task. The Bristleback Attack Plans were brought to Chief Hawkwind in Camp Narache." },
[3376] = { title = "Break Sharptusk!",
  body = "Brave Windfeather in Red Cloud Mesa asked for the head of Chief Sharptusk Thornmantle. It was brought to Brave Windfeather." },
[1656] = { title = "A Task Unfinished",
  body = "Antur Fallow gave a Bundle of Furs for Innkeeper Kauth. It went to Innkeeper Kauth in Bloodhoof Village." },
[763] = { title = "Rites of the Earthmother",
  body = "Chief Hawkwind gave the Totem of Hawkwind. It went along the road out of Camp Narache to Baine Bloodhoof in Bloodhoof Village." },

-- Rites of the Earthmother -------------------------------------
[767] = { title = "Rite of Vision",
  body = "Baine Bloodhoof named Zarlman Two-Moons in Bloodhoof Village. Zarlman Two-Moons was the one to speak with." },
[771] = { title = "Rite of Vision",
  body = "Zarlman Two-Moons asked for 2 Well Stones and 2 Ambercorn. They were brought to Zarlman Two-Moons in Bloodhoof Village." },
[772] = { title = "Rite of Vision",
  body = "Zarlman Two-Moons gave the Water of the Seers. It was consumed in front of the tribal fire in Bloodhoof Village, and the vision led to Seer Wiserunner." },
[773] = { title = "Rite of Wisdom",
  body = "Seer Wiserunner named Red Rocks, east of Thunder Bluff. The Ancestral Spirit was there to speak with." },
[775] = { title = "Journey into Thunder Bluff",
  body = "The Ancestral Spirit at Red Rocks named Cairne Bloodhoof. The road led to Cairne Bloodhoof in Thunder Bluff." },
[776] = { title = "Rites of the Earthmother",
  body = "Cairne Bloodhoof in Thunder Bluff asked for the Horn of Arra'chea. It was brought to Cairne Bloodhoof." },

-- The Water Wells of Mulgore -----------------------------------
[748] = { title = "Poison Water",
  body = "Mull Thunderhorn in Bloodhoof Village asked for 6 Prairie Wolf Paws and 4 Plainstrider Talons. They were brought to Mull Thunderhorn." },
[754] = { title = "Winterhoof Cleansing",
  body = "Mull Thunderhorn gave the Winterhoof Cleansing Totem. It was used at the Winterhoof Water Well, and the word went back to Mull Thunderhorn." },
[756] = { title = "Thunderhorn Totem",
  body = "Mull Thunderhorn asked for 6 Stalker Claws and 6 Cougar Claws. They were brought to Mull Thunderhorn." },
[758] = { title = "Thunderhorn Cleansing",
  body = "Mull Thunderhorn gave the Thunderhorn Cleansing Totem. It was used at the Thunderhorn Water Well, and the word went back to Mull Thunderhorn." },
[759] = { title = "Wildmane Totem",
  body = "Mull Thunderhorn asked for 8 Prairie Alpha Teeth. They were brought to Mull Thunderhorn in Bloodhoof Village." },
[760] = { title = "Wildmane Cleansing",
  body = "Mull Thunderhorn gave the Wildmane Cleansing Totem. It was used at the Wildmane Water Well, and the word went back to Mull Thunderhorn." },
[98435] = { title = "Thunderhorn's Report",
  body = "Mull Thunderhorn gave Thunderhorn's Report. It went to Arch Druid Hamuul Runetotem in Thunder Bluff." },

-- The Venture Co. ----------------------------------------------
[749] = { title = "The Ravaged Caravan",
  body = "Morin Cloudstalker asked for a look at the contents of a supply crate at the Ravaged Caravan. The Sealed Supply Crate was examined there." },
[751] = { title = "The Ravaged Caravan",
  body = "The Sealed Supply Crate opened this task. The Venture Co. Documents went back to Morin Cloudstalker near Bloodhoof Village." },
[764] = { title = "The Venture Co.",
  body = "Morin Cloudstalker asked for the death of 14 Venture Co. Workers and 6 Venture Co. Supervisors. The report went back to Morin Cloudstalker." },
[765] = { title = "Supervisor Fizsprocket",
  body = "Morin Cloudstalker asked for the death of Supervisor Fizsprocket. The clipboard of Supervisor Fizsprocket went to Morin Cloudstalker." },
[98424] = { title = "Fizsprocket's Notes",
  body = "The Mulgore Expansion Plans opened this task. The rest of Supervisor Fizsprocket's pages were collected inside The Venture Co. Mine and brought to Morin Cloudstalker near Bloodhoof Village." },
[98427] = { title = "Ceasing Operations",
  body = "Morin Cloudstalker asked for the Clearcutter Key. It was brought to Morin Cloudstalker outside Bloodhoof Village." },

-- Bloodhoof Village --------------------------------------------
[745] = { title = "Sharing the Land",
  body = "Baine Bloodhoof in Bloodhoof Village asked for the death of 10 Palemane Tanners, 8 Palemane Skinners and 5 Palemane Poachers. The report went back to Baine Bloodhoof." },
[761] = { title = "Swoop Hunting",
  body = "Harken Windtotem in Bloodhoof Village asked for 8 Trophy Swoop Quills. They were brought to Harken Windtotem." },
[96130] = { title = "Chakuyak",
  body = "Yaw Sharpmane asked for the defeat of Chakuyak. The pelt of Chakuyak went back to Yaw Sharpmane." },
[99411] = { title = "Kyle's Gone Missing!",
  body = "Ahab Wheathoof at Bloodhoof Village asked for food for a prized puppy, Kyle the Frenzied. Kyle was fed, and the word went back to Ahab Wheathoof." },
[743] = { title = "Dangers of the Windfury",
  body = "Ruul Eagletalon in Bloodhoof Village asked for 8 Windfury Talons. They were brought to Ruul Eagletalon." },
[766] = { title = "Mazzranache",
  body = "Maur Raincaller at Bloodhoof Village asked for a Prairie Wolf Heart, a Flatland Cougar Femur, a Plainstrider Scale and a Swoop Gizzard. They were brought to Maur Raincaller." },
[746] = { title = "Dwarven Digging",
  body = "Baine Bloodhoof asked for 5 Prospector's Picks, smashed at a forge. Five Broken Tools went to Baine Bloodhoof in Bloodhoof Village." },
[770] = { title = "The Demon Scarred Cloak",
  body = "A Demon Scarred Cloak opened this task: to find someone who knows of Ghost Howl. Skorn Whitecloud was that one." },
[833] = { title = "A Sacred Burial",
  body = "Lorekeeper Raintotem asked for the death of 8 Bristleback Interlopers at Red Rocks. The report went back to Lorekeeper Raintotem." },

-- The Galak Centaurs -----------------------------------------
[99079] = { title = "Longwalker Malah",
  body = "Brave Wildrunner named Longwalker Malah Longwind, east of Bloodhoof Village, near the edge of Mulgore. Malah Longwind was found there." },
[99081] = { title = "Grim Tidings",
  body = "Malah Longwind gave Longwalker Malah's Report. It went to Brave Wildrunner in Bloodhoof Village." },
[99101] = { title = "The Report for Baine Bloodhoof",
  body = "Brave Wildrunner sent Longwalker Malah's Report on. It went to Baine Bloodhoof." },
[99080] = { title = "Drive Them Out",
  body = "Baine Bloodhoof asked for the death of 6 Galak Centaurs and 4 Galak Outrunners, and for the head of Herak the Pillager. The head went to Baine Bloodhoof." },
[99082] = { title = "The High Chieftain",
  body = "Baine Bloodhoof named High Chieftain Cairne Bloodhoof in Thunder Bluff. The audience was with Cairne Bloodhoof." },
[98430] = { title = "The Longwalkers",
  body = "Perith Stormhoof asked for help to escape Palemane Rock. The report of Perith Stormhoof's safety went to Cairne Bloodhoof in Thunder Bluff." },

-- Journey to the Crossroads ------------------------------------
[854] = { title = "Journey to the Crossroads",
  body = "Kirge Sternhorn named Thork at the Crossroads in the Barrens. Thork was the one to speak with." },
}
for id, e in pairs(E) do ns.JournalEntries[id] = e end

local P = {
narache = { title = "Epilogue: Camp Narache",
  body = "Grull Hawkwind, Chief Hawkwind, Greatmother Hawkwind, Seer Graytongue, Brave Windfeather and Antur Fallow gave the tasks of this chain. It ended with the Totem of Hawkwind for Baine Bloodhoof in Bloodhoof Village." },
rites = { title = "Epilogue: Rites of the Earthmother",
  body = "The rites went from Baine Bloodhoof to Zarlman Two-Moons, Seer Wiserunner and the Ancestral Spirit at Red Rocks. They ended with the Horn of Arra'chea for Cairne Bloodhoof in Thunder Bluff." },
wells = { title = "Epilogue: The Water Wells of Mulgore",
  body = "Mull Thunderhorn in Bloodhoof Village gave the tasks of this chain. The cleansing totems were used at the Winterhoof, Thunderhorn and Wildmane water wells, and Thunderhorn's Report went to Arch Druid Hamuul Runetotem in Thunder Bluff." },
venture = { title = "Epilogue: The Venture Co.",
  body = "Morin Cloudstalker gave the tasks of this chain, from the Ravaged Caravan to The Venture Co. Mine. It ended with the Clearcutter Key for Morin Cloudstalker outside Bloodhoof Village." },
bloodhoof = { title = "Epilogue: Bloodhoof Village",
  body = "Baine Bloodhoof, Harken Windtotem, Yaw Sharpmane, Ahab Wheathoof, Ruul Eagletalon, Maur Raincaller and Lorekeeper Raintotem gave the tasks of this chain. A Demon Scarred Cloak led to Skorn Whitecloud." },
longwalkers = { title = "Epilogue: The Galak Centaurs",
  body = "Longwalker Malah's Report went from Malah Longwind to Brave Wildrunner and to Baine Bloodhoof. The head of Herak the Pillager went to Baine Bloodhoof, and the chain ended with Cairne Bloodhoof in Thunder Bluff." },
crossroads_road = { title = "Epilogue: Journey to the Crossroads",
  body = "Kirge Sternhorn gave the one task of this chain. It ended with Thork at the Crossroads in the Barrens." },
}
for id, e in pairs(P) do ns.JournalEpilogues[id] = e end
