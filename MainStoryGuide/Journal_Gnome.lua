-- MainStoryGuide: Gnome saga journal (issue #13).
--
-- Hand-written prose, one page per chain quest and one epilogue per chain.
-- Close third person, world-focused; facts only from the Questie/PandaBase
-- facts in tools/sagas/gnome.facts.json (tests/test_story_voice.py).

local _, ns = ...
ns.JournalEntries = ns.JournalEntries or {}
ns.JournalEpilogues = ns.JournalEpilogues or {}

local E = {
-- Gnomeregan in Exile -----------------------------------------
[412] = { title = "Cogs and Gears",
  body = "In Kharanos, Razzle Sprysprocket pressed on with Operation Recombobulation. The work called for parts, and the parts were gathered: eight Restabilization Cogs and eight Gyromechanic Gears. They were brought to Kharanos and laid before Razzle Sprysprocket. Razzle Sprysprocket received them. Even in exile, the gears of Gnomeregan still turn." },
[2039] = { title = "The Search for Bingles",
  body = "In Ironforge, Gnoarn gave word: Bingles Blastenheimer was to be found. The search began there, in the mountain city. The trail led out of Ironforge and into Loch Modan. There, beyond the halls of stone, Bingles Blastenheimer was found. In Loch Modan, the search for Bingles Blastenheimer came to its end." },
[2038] = { title = "Tools of the Trade",
  body = "In Loch Modan, Bingles Blastenheimer was found without his supplies. Four were missing: Bingles' Wrench, Bingles' Screwdriver, Bingles' Hammer and Bingles' Blastencapper. Each one was sought out, found and gathered up. Each was returned to Bingles Blastenheimer in Loch Modan. Not one of the four was left behind." },
[2041] = { title = "Word to Stormwind",
  body = "Gnoarn in Ironforge sent word to Stormwind City. The road left the mountain city and ended in Stormwind City. There Shoni the Shilent was found and spoken with. The exiles of Gnomeregan are not bound to a single city, and this thread led away from Ironforge." },
[2040] = { title = "Into the Deadmines",
  body = "Shoni the Shilent sought the Gnoam Sprecklesprocket, and it lay within the Deadmines. The assault went underground, into the dark beneath the earth. The Gnoam Sprecklesprocket was retrieved from the depths. It was carried back to Stormwind City and placed in the hands of Shoni the Shilent. The Gnoam Sprecklesprocket rests now with Shoni the Shilent in Stormwind City." },
-- The Fall of Gnomeregan --------------------------------------
[2928] = { title = "Guts for Shoni",
  body = "In Stormwind City, Shoni the Shilent called for the inner workings of machines. Twenty-four Robo-mechanical Guts were gathered within Gnomeregan. Each one was carried back along the long road to Stormwind. Shoni received the salvaged parts in full. Even in ruin, the machines of the fallen city still hold value." },
[2923] = { title = "A Summons to Ironforge",
  body = "Brother Sarno of Stormwind City sent word to Ironforge. The message named Tinkmaster Overspark, and the road led to him. In Ironforge the Tinkmaster was found and spoken with. The summons had reached its end. The road to the lost city runs through the halls of Ironforge." },
[2922] = { title = "Techbot's Memory Core",
  body = "Tinkmaster Overspark sought a single prize from the depths of Gnomeregan. Techbot's Memory Core lay somewhere within the ruined halls. The core was found and recovered. It was carried back to Ironforge and placed in the Tinkmaster's hands. Techbot's Memory Core was saved from the dark." },
[2927] = { title = "Word for Kharanos",
  body = "In Ironforge, Gnoarn sent the call onward to Kharanos. The road wound out of the great city and into the snows of Dun Morogh. Ozzie Togglevolt waited there in the village. The message was delivered and heard. Even in Dun Morogh, the fall of Gnomeregan is felt." },
[2926] = { title = "Filling the Leaden Phial",
  body = "Ozzie Togglevolt handed over an Empty Leaden Collection Phial and a plain purpose. Radioactive fallout clung to the Irradiated Invaders and Irradiated Pillagers. The phial was turned upon them until it was full. The tainted sample was carried back to Kharanos. Ozzie Togglevolt received the full phial of radioactive fallout." },
[2962] = { title = "More Green Glow",
  body = "Ozzie Togglevolt required a stronger sample. That fallout lay within Gnomeregan itself. High Potency Radioactive Fallout was gathered there, unstable and quick to collapse. It was rushed back to Kharanos, and the Heavy Leaden Collection Phial was returned with it. The fallout reached Ozzie Togglevolt before it could collapse." },
[2924] = { title = "Essential Artificials",
  body = "Klockmort Spannerspan of Ironforge called for Essential Artificials from Gnomeregan. Twelve were recovered from within the city's halls. Each was carried out of the ruin and back to Ironforge. Klockmort received the full count. What remains of the city is reclaimed one piece at a time." },
[2930] = { title = "The Prismatic Punch Card",
  body = "Master Mechanic Castpipe of Ironforge sought the records of Gnomeregan. A Prismatic Punch Card held what was needed. The card was found within the city and carried back intact. Castpipe received it in Ironforge without loss. Knowledge that had seemed lost was rescued from the dark." },
[2929] = { title = "The Grand Betrayal",
  body = "High Tinker Mekkatorque called for an end to Mekgineer Thermaplugg. The way into Gnomeregan was taken once more. There, among the ruined halls of the city, Mekgineer Thermaplugg was slain. Word of his death was carried back to the High Tinker in Ironforge. The call of High Tinker Mekkatorque was answered." },
}
for id, e in pairs(E) do ns.JournalEntries[id] = e end

local P = {
exiles = { title = "Epilogue: Gnomeregan in Exile",
  body = "The road of the exiles ran from Kharanos to Loch Modan, from Ironforge to Stormwind City. Cogs and gears reached Razzle Sprysprocket, and Bingles Blastenheimer had his supplies returned to him. From the Deadmines, the Gnoam Sprecklesprocket was carried back to Shoni the Shilent. Such is the way of Gnomeregan in Exile. The work of the exiles endures." },
gnomeregan = { title = "Epilogue: The Fall of Gnomeregan",
  body = "Salvage reached Stormwind City and Ironforge, and Techbot's Memory Core was returned to Tinkmaster Overspark. In Kharanos, Ozzie Togglevolt received the radioactive fallout. Mekgineer Thermaplugg was slain in Gnomeregan, and High Tinker Mekkatorque received the word. The fall of Gnomeregan cannot be undone." },
}
for id, e in pairs(P) do ns.JournalEpilogues[id] = e end
