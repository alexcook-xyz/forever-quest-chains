-- MainStoryGuide: neutral chains journal (Tirion Fordring, Pamela Redpath, Linken).
--
-- Hand-written prose, one page per chain quest and one epilogue per chain.
-- Close third person, world-focused; every name, number and place comes from
-- the Questie/PandaBase facts in tools/sagas/neutral.facts.json and states no
-- motive or event that the facts do not give (tests/test_story_voice.py).

local _, ns = ...
ns.JournalEntries = ns.JournalEntries or {}
ns.JournalEpilogues = ns.JournalEpilogues or {}

local E = {
-- Tirion Fordring ----------------------------------------------
[5542] = { title = "Demon Dogs",
  body = "Tirion Fordring in the Eastern Plaguelands asked for the death of 20 Plaguehound Runts, 5 Plaguehounds and 5 Frenzied Plaguehounds. The report went back to Tirion Fordring." },
[5543] = { title = "Blood Tinged Skies",
  body = "Tirion Fordring asked for the death of 30 Plaguebats. The report went back to Tirion Fordring." },
[5544] = { title = "Carrion Grubbage",
  body = "Tirion Fordring asked for the death of Carrion Grubs and Devourers and for 15 Slabs of Carrion Worm Meat. The meat went back to Tirion Fordring." },
[5742] = { title = "Redemption",
  body = "Tirion Fordring asked for a hearing. The words of Tirion Fordring were the whole task." },
[5781] = { title = "Of Forgotten Memories",
  body = "Tirion Fordring named the Undercroft, in the southernmost part of the Eastern Plaguelands. Taelan's Hammer was there, and it went back to Tirion Fordring." },
[5845] = { title = "Of Lost Honor",
  body = "Tirion Fordring named Northdale, in the northeast of the Eastern Plaguelands. The Symbol of Lost Honor was there, and it went back to Tirion Fordring." },
[5846] = { title = "Of Love and Family",
  body = "Tirion Fordring named the island of Caer Darrow, in the south of the Plaguelands, as the place to look for clues about a painting. The clues led to Artist Renfray." },
[5848] = { title = "Of Love and Family",
  body = "Artist Renfray named Stratholme, in the north of the Plaguelands. The painting Of Love and Family hung in the Scarlet Bastion, behind a painting of the twin moons. It went back to Tirion Fordring." },
[5861] = { title = "Find Myranda",
  body = "Tirion Fordring sent Tirion's Gift to Uther's Tomb, in the south of the Plaguelands. Myranda the Hag was the one to receive it." },
[5862] = { title = "Scarlet Subterfuge",
  body = "Myranda the Hag gave the Scarlet Illusion. Under the Scarlet Illusion, Tirion's Gift went to Highlord Taelan Fordring in Hearthglen, to the north." },
[5944] = { title = "In Dreams",
  body = "Highlord Taelan Fordring asked for an escort out of Hearthglen. The hand-in went to Tirion Fordring." },
-- Pamela Redpath -----------------------------------------------
[5142] = { title = "Little Pamela",
  body = "Marlene Redpath asked for a search for Pamela Redpath. Pamela Redpath was the one to find." },
[5601] = { title = "Sister Pamela",
  body = "Jessica Redpath asked for a search for Pamela Redpath in Darrowshire. This quest and Little Pamela exclude each other, and both lead to Pamela's Doll." },
[5149] = { title = "Pamela's Doll",
  body = "Pamela Redpath in the Eastern Plaguelands asked for a search for her doll. The doll went back to Pamela Redpath." },
[5241] = { title = "Uncle Carlin",
  body = "Pamela Redpath asked for a search for Carlin Redpath. Carlin Redpath was the one to find." },
[5211] = { title = "Defenders of Darrowshire",
  body = "Carlin Redpath asked for the freedom of 15 Darrowshire Spirits. The report went back to Carlin Redpath." },
[5152] = { title = "Auntie Marlene",
  body = "Pamela Redpath named Marlene Redpath, south of the Ruins of Andorhal. Marlene Redpath was the one to speak with." },
[5153] = { title = "A Strange Historian",
  body = "Marlene Redpath asked that Joseph's Wedding Ring go to Chromie. The ring went to Chromie." },
[5154] = { title = "The Annals of Darrowshire",
  body = "Chromie asked for the Annals of Darrowshire. They went back to Chromie in Andorhal." },
[5210] = { title = "Brother Carlin",
  body = "Chromie asked that the Extended Annals of Darrowshire go to Carlin Redpath in the Eastern Plaguelands. The Extended Annals went to Carlin Redpath." },
[5168] = { title = "Heroes of Darrowshire",
  body = "Carlin Redpath asked for Davil's Libram and Redpath's Shield. Both went back to Carlin Redpath." },
[5181] = { title = "Villains of Darrowshire",
  body = "Carlin Redpath asked for the Skull of Horgus and the Shattered Sword of Marduk. Both went to Carlin Redpath at Light's Hope Chapel." },
[5206] = { title = "Marauders of Darrowshire",
  body = "Carlin Redpath asked for 5 Resonating Skulls and the Mystic Crystal. They went to Carlin Redpath in the Eastern Plaguelands." },
[5941] = { title = "Return to Chromie",
  body = "Carlin Redpath sent a Bundle of Relics to Chromie in Andorhal. Chromie was the one to receive it." },
[5721] = { title = "The Battle of Darrowshire",
  body = "Chromie asked that the Relic Bundle stand in the Darrowshire town square. Davil Lightfire lived until the death of Horgus, Captain Redpath lived until Redpath the Corrupted appeared, and Redpath the Corrupted fell. The spirit of Joseph Redpath spoke at the town square, and Pamela Redpath waited at her home." },
[5942] = { title = "Hidden Treasures",
  body = "Pamela Redpath asked that Joseph's Key open Joseph's Chest." },
-- Linken -------------------------------------------------------
[3844] = { title = "It's a Secret to Everybody",
  body = "A Wrecked Raft in the pond of Un'Goro Crater held a clue about its owner. The clue was in the pond." },
[3845] = { title = "It's a Secret to Everybody",
  body = "A Small Pack in Un'Goro Crater held items. The items belonged to Linken, and they went to Linken." },
[3908] = { title = "It's a Secret to Everybody",
  body = "Linken in Un'Goro Crater sent Linken's Sword to Donova Snowden in Winterspring." },
[3909] = { title = "The Videre Elixir",
  body = "Donova Snowden asked for Gregan Brewspewer in northern Feralas. Gregan Brewspewer told how to get the Videre Elixir, and the answer went back to Donova Snowden in Winterspring." },
[3912] = { title = "Meet at the Grave",
  body = "Donova Snowden named the graveyard outside Gadgetzan. The Videre Elixir was used there, and the instructions of Donova Snowden led to Gaeriyan." },
[3913] = { title = "A Grave Situation",
  body = "Gaeriyan named a gravestone to find after a resurrection." },
[3914] = { title = "Linken's Sword",
  body = "A Conspicuous Gravestone in Tanaris held Linken's Superior Sword. The sword went to Linken in Un'Goro Crater." },
[3941] = { title = "A Gnome's Assistance",
  body = "Linken named J.D. Collie, who was in the cave at Marshal's Refuge." },
[3942] = { title = "Linken's Memory",
  body = "J.D. Collie named Eridan Bluewind in southern Felwood." },
[4084] = { title = "Silver Heart",
  body = "Eridan Bluewind in Felwood asked for 11 Silvery Claws and 1 Irontree Heart. They went back to Eridan Bluewind." },
[4005] = { title = "Aquementas",
  body = "Eridan Bluewind sent the Book of Aquor, the Silvery Claws and the Irontree Heart to Tanaris. The Book of Aquor summoned Aquementas, and the finished totem went to J.D. Collie at Marshal's Refuge." },
[3961] = { title = "Linken's Adventure",
  body = "J.D. Collie sent the Silver Totem of Aquementas to Linken at Marshal's Refuge." },
[3962] = { title = "It's Dangerous to Go Alone",
  body = "Linken named Fire Plume Ridge, south of Marshal's Refuge. The totem removed the protective aura of Blazerunner. After the death of Blazerunner, the Golden Flame lay in the cave. It went back to Linken." },
}
for id, e in pairs(E) do ns.JournalEntries[id] = e end

local P = {
tirion_fordring = { title = "Epilogue: Tirion Fordring",
  body = "Tirion Fordring gave three tasks in the Eastern Plaguelands. The trail then ran through Artist Renfray and Myranda the Hag to Highlord Taelan Fordring, and the chain ended with the escort out of Hearthglen." },
pamela_redpath = { title = "Epilogue: Pamela Redpath",
  body = "Marlene Redpath or Jessica Redpath started the search for Pamela Redpath. The trail ran through Chromie and Carlin Redpath to the battle of Darrowshire, and the chain ended with Hidden Treasures for Pamela Redpath." },
linken = { title = "Epilogue: Linken",
  body = "A wrecked raft and a small pack in Un'Goro Crater started the trail. It ran through Linken, Donova Snowden, Gaeriyan, J.D. Collie and Eridan Bluewind, and ended with Linken at Marshal's Refuge." },
}
for id, e in pairs(P) do ns.JournalEpilogues[id] = e end
