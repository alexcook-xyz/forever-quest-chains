-- MainStoryGuide: Troll saga journal.
--
-- Hand-written prose, one page per chain quest and one epilogue per chain.
-- Close third person, world-focused; every name, number and place comes from
-- the Questie/PandaBase facts in tools/sagas/troll.facts.json and states no
-- motive or event that the facts do not give (tests/test_story_voice.py).

local _, ns = ...
ns.JournalEntries = ns.JournalEntries or {}
ns.JournalEpilogues = ns.JournalEpilogues or {}

local E = {
-- The Echo Isles -----------------------------------------------
[818] = { title = "A Solvent Spirit",
  body = "Master Vornal in Sen'jin Village asked for 4 Intact Makrura Eyes and 8 vials of Crawler Mucus. They were brought to him." },
[817] = { title = "Practical Prey",
  body = "Vel'rin Fang in Sen'jin Village asked for 4 Durotar Tiger Furs. They were brought to him." },
[815] = { title = "Break a Few Eggs",
  body = "Cook Torka in Razor Hill asked for 3 Taillasher Eggs. They were brought to her." },
[808] = { title = "Minshina's Skull",
  body = "Master Gadrin asked for Minshina's skull, from the circle of power on the Echo Isles. It went to him in Sen'jin Village." },
[826] = { title = "Zalazane",
  body = "Master Gadrin asked for the defeat of Zalazane and the death of 8 Voodoo Trolls and 8 Hexed Trolls. Zalazane's Head went to Gadrin." },
}
for id, e in pairs(E) do ns.JournalEntries[id] = e end

local P = {
echo_isles = { title = "Epilogue: The Echo Isles",
  body = "Master Vornal, Vel'rin Fang and Master Gadrin in Sen'jin Village and Cook Torka in Razor Hill gave the tasks of this chain. It ended with Zalazane's Head for Master Gadrin." },
}
for id, e in pairs(P) do ns.JournalEpilogues[id] = e end
