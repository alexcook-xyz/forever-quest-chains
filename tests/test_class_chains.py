"""Class chains (issue #41): a chain with classSpecific = true shows to a player of that class only.

Loads the real Sagas.lua, the real Dwarf, Human and Gnome data, and the inclusion gate cut out of the
real Core.lua (from IsClassSpecificQuest to Classify) in Lua 5.1 (lupa.lua51). No saga data holds a
class quest yet, so a test chain is registered on top of the real data.
"""
from __future__ import annotations

import pathlib

import pytest

lua51 = pytest.importorskip("lupa.lua51")

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MainStoryGuide"
CORE = (ADDON / "Core.lua").read_text(encoding="utf-8")
GATE = CORE[CORE.index("function ns.IsClassSpecificQuest"):CORE.index("-- Classify(questID)")]
FILES = ["Sagas.lua", "Shared_Alliance.lua", "Data_Human.lua", "Data_HumanDiplomat.lua", "Route_Human.lua",
         "Data_Dwarf.lua", "Route_Dwarf.lua", "Data_Gnome.lua", "Route_Gnome.lua"]
CLASSES = ["WARRIOR", "PALADIN", "MAGE"]

# One chain of three class quests, plus two chains that must never show a class quest.
CLASS_CHAIN = """
return {
  { id = "test_sigils", name = "Test Sigils", race = "Dwarf", classSpecific = true,
    zone = "Dun Morogh", minLevel = 10, maxLevel = 20, summary = "A test.",
    quests = {
      { id = 990001, name = "Warrior Sigil", giver = "A", zone = "Dun Morogh", class = "WARRIOR" },
      { id = 990002, name = "Shared Sigil", giver = "A", zone = "Dun Morogh", class = "paladin, WARRIOR" },
      { id = 990003, name = "No Class Row", giver = "A", zone = "Dun Morogh" },
    } },
  { id = "test_elf_sigils", name = "Elf Sigils", race = "NightElf", classSpecific = true,
    zone = "Teldrassil", minLevel = 10, maxLevel = 20, summary = "A test.",
    quests = { { id = 990011, name = "Elf Sigil", giver = "A", zone = "Teldrassil", class = "WARRIOR" } } },
  { id = "test_plain", name = "Plain", race = "Dwarf",
    zone = "Dun Morogh", minLevel = 10, maxLevel = 20, summary = "A test.",
    quests = { { id = 990021, name = "Hidden Class Row", giver = "A", zone = "Dun Morogh", class = "WARRIOR" },
               { id = 990022, name = "Open Row", giver = "A", zone = "Dun Morogh" } } },
  { id = "skyborne_class", name = "Skyborne", race = "Dwarf", classSpecific = true,
    zone = "Dun Morogh", minLevel = 10, maxLevel = 20, summary = "A test.",
    quests = { { id = 990031, name = "Sky Sigil", giver = "A", zone = "Dun Morogh", class = "WARRIOR" } } },
}
"""

HARNESS = r"""
return function(files, core, extra, race, classMode)
  UnitRace = function() return race, race end
  UnitFactionGroup = function() return "Alliance", "Alliance" end
  if classMode == "absent" then UnitClass = nil
  elseif classMode == "empty" then UnitClass = function() return nil end
  else UnitClass = function() return classMode, classMode end end
  local ns = {}
  for _, f in ipairs(files) do
    assert(loadstring(f[2], "@" .. f[1]))("MainStoryGuide", ns)
  end
  assert(loadstring("local _, ns = ...\n" .. core, "@Core"))("MainStoryGuide", ns)
  if extra then ns.RegisterChains(assert(loadstring(extra))()) end
  return ns
end
"""


def lua_list(t) -> list:
    return [t[i] for i in range(1, len(t) + 1)] if t else []


def load(race: str, class_mode, extra: bool):
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    files = rt.table(*[rt.table(n, (ADDON / n).read_text(encoding="utf-8")) for n in FILES])
    return rt.execute(HARNESS)(files, GATE, CLASS_CHAIN if extra else None, race, class_mode)


def effective(ns, chain_id: str) -> list[int]:
    chain = next(c for c in lua_list(ns.Chains) if c.id == chain_id)
    return [q.id for q in lua_list(ns.EffectiveQuests(chain))]


def main_shape(ns) -> dict:
    """Chains (not the test chains), their quest counts and the route: what a class must not change."""
    skip = {"test_sigils", "test_elf_sigils", "test_plain", "skyborne_class"}
    chains = [(c.id, len(effective(ns, c.id))) for c in lua_list(ns.Chains) if c.id not in skip]
    return {"chains": chains, "route": lua_list(ns.StoryRoute)}


@pytest.mark.parametrize("klass,expect", [("WARRIOR", [990001, 990002]), ("PALADIN", [990002]), ("MAGE", [])])
def test_a_class_chain_shows_only_the_quests_of_the_class(klass, expect):
    ns = load("Dwarf", klass, True)
    assert effective(ns, "test_sigils") == expect
    chain = next(c for c in lua_list(ns.Chains) if c.id == "test_sigils")
    assert ns.IsChainIncluded(chain) == bool(expect)


@pytest.mark.parametrize("mode", ["absent", "empty"])
def test_without_a_class_every_class_chain_is_hidden(mode):
    ns = load("Dwarf", mode, True)
    assert ns.PlayerClass() is None
    assert effective(ns, "test_sigils") == []
    assert not ns.IsChainIncluded(next(c for c in lua_list(ns.Chains) if c.id == "test_sigils"))


def test_class_rows_outside_a_class_chain_stay_hidden_for_every_class():
    for klass in CLASSES:
        ns = load("Dwarf", klass, True)
        assert effective(ns, "test_plain") == [990022]


def test_the_quest_gate_checks_the_class_argument():
    ns = load("Dwarf", "MAGE", True)
    chain = next(c for c in lua_list(ns.Chains) if c.id == "test_sigils")
    row = chain.quests[2]  # Lua index: "Shared Sigil"
    assert ns.QuestEligible(row, None, "WARRIOR") is True
    assert ns.QuestEligible(row, None, "PALADIN") is True
    assert ns.QuestEligible(row, None, "MAGE") is False
    assert ns.QuestEligible(row) is False  # the player is a Mage
    assert ns.QuestEligible(row, None, "") is False


def test_a_class_row_with_no_class_field_is_hidden():
    ns = load("Dwarf", "WARRIOR", True)
    assert 990003 not in effective(ns, "test_sigils")


def test_a_class_chain_follows_the_race_of_its_chain():
    ns = load("Dwarf", "WARRIOR", True)
    ids = [c.id for c in lua_list(ns.Chains)]
    assert "test_sigils" in ids
    assert "test_elf_sigils" not in ids  # a Night Elf class chain is not in a Dwarf view
    # The Night Elf data is not loaded here, so only the Dwarf view is checked.


def test_a_class_chain_is_a_side_group_after_the_main_chains():
    ns = load("Dwarf", "WARRIOR", True)
    ids = [c.id for c in lua_list(ns.Chains)]
    assert ids.index("test_sigils") > max(ids.index(c) for c in ("coldridge", "frostmane"))
    assert ns.IsSideChain(next(c for c in lua_list(ns.Chains) if c.id == "test_sigils"))
    assert ns.ChainGroup(next(c for c in lua_list(ns.Chains) if c.id == "test_sigils"), "Dwarf") == "forever"


def test_skyborne_class_stays_blocked():
    ns = load("Dwarf", "WARRIOR", True)
    assert effective(ns, "skyborne_class") == []


@pytest.mark.parametrize("race", ["Human", "Dwarf", "Gnome"])
@pytest.mark.parametrize("klass", CLASSES + ["empty"])
def test_the_main_route_does_not_change_with_the_class_or_a_class_chain(race, klass):
    base = main_shape(load(race, klass, False))
    assert main_shape(load(race, klass, True)) == base
    assert main_shape(load(race, "WARRIOR", False)) == base  # the class alone changes nothing


# ---------------------------------------------------- active chain, chooser, journal heading
def cut(src: str, start: str, end: str) -> str:
    a = src.index(start)
    return src[a:src.index(end, a)]


HUB = (ADDON / "Hub.lua").read_text(encoding="utf-8")
JOURNAL = (ADDON / "Journal.lua").read_text(encoding="utf-8")
GET_ACTIVE = cut(CORE, "function ns.GetActive()", "\nend\n") + "\nend\n"
STORY_CHOICES = cut(HUB, "function ns.StoryChoices", "-- Old callers")
HEADING = cut(JOURNAL, "function ns.JournalChapterHeading", "-- Total unread")

UI_HARNESS = """
local ROMAN = { "I", "II", "III" }
local ns = { cdb = { skipped = {} }, Chains = {} }
UnitLevel = function() return 20 end
ns.IsSideChain = function(c) return c.optional == true or c.classSpecific == true end
ns.IsChainIncluded = function() return true end
ns.ResolveChain = function(c) return { chain = c, state = "PICKUP", done = 0, total = 2 } end
ns.JournalChapterProgress = function() return 1, 3 end
""" + "\n".join([GET_ACTIVE, STORY_CHOICES, HEADING]) + """
return function(chains)
  ns.Chains = chains
  return ns
end
"""


def ui_ns(chains):
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    return rt.execute(UI_HARNESS)(rt.table_from([rt.table_from(c) for c in chains]))


MAIN = {"id": "main1", "name": "Main One", "minLevel": 40}
CLASS = {"id": "sigils", "name": "Sigils", "minLevel": 1, "classSpecific": True}


def test_get_active_never_picks_a_class_chain():
    # The class chain comes first and is the only one at the player level (20).
    ns = ui_ns([CLASS, MAIN])
    assert ns.GetActive()[0].chain.id == "main1"


def test_the_chooser_lists_a_class_chain_as_a_side_entry():
    ns = ui_ns([MAIN, CLASS])
    entries = {e.id: e for e in (ns.StoryChoices()[i] for i in (2, 3))}
    assert entries["main1"].optional is False
    assert entries["sigils"].optional is True


def test_the_journal_heading_names_a_class_chain_a_class_chapter():
    ns = ui_ns([MAIN, CLASS])
    assert ns.JournalChapterHeading(ns.Chains[1], 1) == "Chapter I - Main One (1/3 pages written)"
    assert ns.JournalChapterHeading(ns.Chains[2], 2) == "Class Chapter - Sigils (1/3 pages written)"
