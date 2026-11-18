-- MainStoryGuide: Orc saga journal.
--
-- Hand-written prose, one page per chain quest and one epilogue per chain.
-- Close third person, world-focused; every name, number and place comes from
-- the Questie/PandaBase facts in tools/sagas/orc.facts.json and states no
-- motive or event that the facts do not give (tests/test_story_voice.py).

local _, ns = ...
ns.JournalEntries = ns.JournalEntries or {}
ns.JournalEpilogues = ns.JournalEpilogues or {}

local E = {
-- The Valley of Trials ----------------------------------------
[4641] = { title = "Speak With Gornek",
  body = "Kaltunk marked Gornek's place on the map: the Den, a building to the west in the Valley of Trials. Gornek was the one to speak with." },
[788] = { title = "Cutting Teeth",
  body = "Gornek set the first task at the Den. Ten Mottled Boars were killed, and the report went back to Gornek." },
[789] = { title = "Sting of the Scorpid",
  body = "Gornek asked for 10 Scorpid Worker Tails. They were gathered and brought to him in the Den." },
[4402] = { title = "Galgar's Cactus Apple Surprise",
  body = "Galgar asked for 10 Cactus Apples, which grow near cactuses. They were brought to him." },
[790] = { title = "Sarkoth",
  body = "Hana'zua asked for the death of Sarkoth. The claw of Sarkoth was the proof to bring back to Hana'zua." },
[804] = { title = "Sarkoth",
  body = "The news of Hana'zua's plight went from Hana'zua to Gornek at the Den." },
[5441] = { title = "Lazy Peons",
  body = "Foreman Thazz'ril lent his Foreman's Blackjack. Five sleeping Lazy Peons were woken with it, and the blackjack went back to the Foreman in the Valley of Trials." },
[6394] = { title = "Thazz'ril's Pick",
  body = "Thazz'ril's Pick was brought to Foreman Thazz'ril." },
[794] = { title = "Burning Blade Medallion",
  body = "The Burning Blade Medallion was brought to Zureetha Fargaze, outside the Den." },
[805] = { title = "Report to Sen'jin Village",
  body = "Zureetha Fargaze sent word on to Master Gadrin in Sen'jin Village. The valley ended with that report." },
-- Thwarting Kolkar Aggression ---------------------------------
[786] = { title = "Thwarting Kolkar Aggression",
  body = "Lar Prowltusk, outside Sen'jin Village, wanted 3 sets of Attack Plans in Kolkar Crag destroyed. The report went back to him." },
[837] = { title = "Encroachment",
  body = "Gar'Thok at Razor Hill asked for 4 Razormane Quilboars, 4 Razormane Scouts, 4 Razormane Dustrunners and 4 Razormane Battleguards to be killed. The count was reported to him." },
-- Vanquish the Betrayers --------------------------------------
[784] = { title = "Vanquish the Betrayers",
  body = "Gar'Thok in Razor Hill asked for 10 Kul Tiras Sailors, 8 Kul Tiras Marines and Lieutenant Benedict to be killed. The report went back to Razor Hill." },
[825] = { title = "From the Wreckage",
  body = "Gar'Thok of Razor Hill asked for 3 Gnomish Tools from the wreckage off the coast. They were brought to him." },
[830] = { title = "The Admiral's Orders",
  body = "Admiral Proudmoore's Orders came out of an Aged Envelope. They went to Gar'Thok in Razor Hill." },
[831] = { title = "The Admiral's Orders",
  body = "Gar'Thok passed Admiral Proudmoore's Orders on to Nazgrel in Thrall's chamber in Orgrimmar." },
-- Securing the Red Canyon -------------------------------------
[2161] = { title = "A Peon's Burden",
  body = "Ukor handed over Ukor's Burden. It was carried to Innkeeper Grosk in Razor Hill." },
[834] = { title = "Winds in the Desert",
  body = "Rezlak, near Orgrimmar, asked for 5 Sacks of Supplies. They were returned to him." },
[835] = { title = "Securing the Lines",
  body = "Rezlak asked for 12 Dustwind Savages and 8 Dustwind Storm Witches to be killed near Drygulch Ravine." },
[791] = { title = "Canvas Scraps",
  body = "Furl Scornbrow in the Razor Hill watchtower asked for 8 Canvas Scraps. They were brought to him." },
[816] = { title = "Lost But Not Forgotten",
  body = "Misha Tor'kren asked for a sign of Kron's fate. It went to her at the farmstead northwest of Razor Hill." },
-- Shadows of the Burning Blade --------------------------------
[823] = { title = "Report to Orgnil",
  body = "Master Gadrin sent the word on to Orgnil Soulscar in Razor Hill." },
[806] = { title = "Dark Storms",
  body = "Orgnil Soulscar asked for Fizzle's Claw. It was brought to him in Razor Hill." },
[828] = { title = "Margoz",
  body = "Orgnil Soulscar named Margoz as the next person to speak with." },
[827] = { title = "Skull Rock",
  body = "Margoz asked for Searing Collars from the cultists in Skull Rock. They went to him at his camp." },
[829] = { title = "Neeru Fireblade",
  body = "Margoz gave out an Example Collar. It went to Neeru Fireblade in Orgrimmar." },
[809] = { title = "Ak'Zeloth",
  body = "Neeru Fireblade named Ak'Zeloth, in the Barrens, as the next person to speak with." },
[924] = { title = "The Demon Seed",
  body = "Ak'Zeloth asked for a Flawed Power Stone. It had to reach the Altar of Fire before it expired, and then the word went back to Ak'Zeloth." },
[926] = { title = "Flawed Power Stone",
  body = "The Flawed Power Stone in the Barrens started the quest and ended it. The quest has no objective text of its own." },
[832] = { title = "Burning Shadows",
  body = "The Eye of Burning Shadow started this quest. It went to Neeru Fireblade in Orgrimmar." },
[840] = { title = "Conscript of the Horde",
  body = "Takrin Pathseeker gave out a recruitment letter. The road ran west from Razor Hill over a bridge to the orc outpost in the Barrens, where Kargal Battlescar took the letter." },
}
for id, e in pairs(E) do ns.JournalEntries[id] = e end

local P = {
trials = { title = "Epilogue: The Valley of Trials",
  body = "The Valley of Trials ended with word for Master Gadrin in Sen'jin Village. Gornek, Galgar, Hana'zua, Foreman Thazz'ril and Zureetha Fargaze gave the tasks before it." },
kolkar = { title = "Epilogue: Thwarting Kolkar Aggression",
  body = "Lar Prowltusk outside Sen'jin Village and Gar'Thok at Razor Hill gave the two tasks of this chain." },
betrayers = { title = "Epilogue: Vanquish the Betrayers",
  body = "Gar'Thok in Razor Hill gave the tasks of this chain. The last one carried Admiral Proudmoore's Orders to Nazgrel in Orgrimmar." },
peons = { title = "Epilogue: Securing the Red Canyon",
  body = "Ukor, Rezlak, Furl Scornbrow and Misha Tor'kren gave the tasks of this chain around Razor Hill." },
skull_rock = { title = "Epilogue: Shadows of the Burning Blade",
  body = "The chain ran from Orgnil Soulscar in Razor Hill through Margoz, Neeru Fireblade and Ak'Zeloth. It ended with a recruitment letter for Kargal Battlescar at the orc outpost in the Barrens." },
}
for id, e in pairs(P) do ns.JournalEpilogues[id] = e end
