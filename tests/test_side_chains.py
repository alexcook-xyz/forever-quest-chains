"""Side Quests view (issue #2).

The pure helpers of HubChooser.lua group a zone side list into chains. A smoke
test then paints the real HubMap.lua in a Lua 5.1 runtime (lupa.lua51) with
stub frames, the real HubChooser.lua, and the real Elwynn Forest data.
"""
from __future__ import annotations

import pathlib

import pytest

lua51 = pytest.importorskip("lupa.lua51")

ADDON = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide"
CHOOSER = (ADDON / "HubChooser.lua").read_text(encoding="utf-8")
HUBMAP = (ADDON / "HubMap.lua").read_text(encoding="utf-8")
SIDE = (ADDON / "ZoneSideQuests.lua").read_text(encoding="utf-8")

LOAD = r"""
return function(src)
  local ns = {}
  assert(loadstring(src, "@HubChooser.lua"))("MainStoryGuide", ns)
  return ns
end
"""


@pytest.fixture(scope="module")
def lua():
    return lua51.LuaRuntime(unpack_returned_tuples=True)


@pytest.fixture(scope="module")
def ns(lua):
    return lua.execute(LOAD)(CHOOSER)


def recs(lua, *rows):
    """rows: (id, [requires], reqlevel) -> a Lua list of records."""
    out = []
    for qid, req, lvl in rows:
        rec = {"id": qid, "reqlevel": lvl}
        if req:
            rec["requires"] = lua.table_from(list(req))
        out.append(lua.table_from(rec))
    return lua.table_from(out)


def chains_of(lua, ns, *rows):
    result = ns.SideChains(recs(lua, *rows))
    return [[result[i]["quests"][j]["id"] for j in range(1, len(result[i]["quests"]) + 1)]
            for i in range(1, len(result) + 1)], result


# ------------------------------------------------------------ SideChains
def test_a_quest_with_no_link_is_a_chain_of_one(lua, ns):
    ids, result = chains_of(lua, ns, (1, [], 1), (2, [], 1))
    assert ids == [[1], [2]]
    assert result[1]["key"] == "1" and result[2]["key"] == "2"


def test_a_prerequisite_links_the_quests_in_order(lua, ns):
    ids, result = chains_of(lua, ns, (10, [], 1), (11, [10], 1), (12, [11], 1))
    assert ids == [[10, 11, 12]]
    assert result[1]["key"] == "10"


def test_chains_keep_the_order_of_their_first_quest(lua, ns):
    ids, _ = chains_of(lua, ns, (1, [], 1), (5, [], 1), (2, [1], 1), (6, [5], 1))
    assert ids == [[1, 2], [5, 6]]


def test_a_requirement_outside_the_list_is_not_a_link(lua, ns):
    # 99 is a MAIN quest or a hidden quest of the other faction.
    ids, _ = chains_of(lua, ns, (3, [99], 1), (4, [], 1))
    assert ids == [[3], [4]]


def test_a_branch_stays_one_chain_with_prerequisites_first(lua, ns):
    ids, _ = chains_of(lua, ns, (1, [], 1), (2, [1], 1), (3, [1], 1), (4, [2, 3], 1))
    assert ids == [[1, 2, 3, 4]]


def test_a_list_out_of_order_is_put_in_prerequisite_order(lua, ns):
    ids, _ = chains_of(lua, ns, (2, [1], 1), (1, [], 1))
    assert ids == [[1, 2]]


def test_a_cycle_in_the_data_ends(lua, ns):
    ids, _ = chains_of(lua, ns, (1, [2], 1), (2, [1], 1))
    assert sorted(ids[0]) == [1, 2]


def test_an_empty_list_has_no_chain(lua, ns):
    assert chains_of(lua, ns)[0] == []


# ------------------------------------------------------ SideChainCurrent
def current(lua, ns, rows, done):
    chain = ns.SideChains(recs(lua, *rows))[1]
    quest = ns.SideChainCurrent(chain, lambda qid: qid in done)
    return quest["id"] if quest else None


ROWS = ((1, [], 1), (2, [1], 1), (3, [2], 1))


def test_the_current_quest_is_the_first_one_not_done(lua, ns):
    assert current(lua, ns, ROWS, set()) == 1
    assert current(lua, ns, ROWS, {1}) == 2
    assert current(lua, ns, ROWS, {1, 2}) == 3


def test_a_finished_chain_has_no_current_quest(lua, ns):
    assert current(lua, ns, ROWS, {1, 2, 3}) is None


def test_a_later_quest_done_first_does_not_hide_the_open_one(lua, ns):
    # The player did quest 3 out of order; quest 1 is still the one to do.
    assert current(lua, ns, ROWS, {3}) == 1


def test_a_quest_whose_prerequisite_is_open_is_not_current(lua, ns):
    rows = ((1, [], 1), (2, [1], 1), (3, [], 1))
    assert current(lua, ns, rows, {1}) == 2


# ----------------------------------------------------------- SideSummary
def test_summary_counts_done_and_level_range(lua, ns):
    done, total, lo, hi = ns.SideSummary(recs(lua, (1, [], 4), (2, [], 9), (3, [], 0)),
                                         lambda qid: qid == 2)
    assert (done, total, lo, hi) == (1, 3, 4, 9)


def test_summary_without_levels_has_no_range(lua, ns):
    done, total, lo, hi = ns.SideSummary(recs(lua, (1, [], 0)), lambda qid: False)
    assert (done, total, lo, hi) == (0, 1, None, None)


# --------------------------------------------------- Elwynn Forest chains
def elwynn(lua, ns):
    runtime = lua.execute(r"""
      return function(src)
        local ns = {}
        assert(loadstring(src, "@ZoneSideQuests.lua"))("MainStoryGuide", ns)
        return ns.ZoneSideQuests["Elwynn Forest"]
      end""")
    return runtime(SIDE)


def test_elwynn_chains_are_grouped_in_prerequisite_order(lua, ns):
    result = ns.SideChains(elwynn(lua, ns))
    chains = [[result[i]["quests"][j]["id"] for j in range(1, len(result[i]["quests"]) + 1)]
              for i in range(1, len(result) + 1)]
    multi = [c for c in chains if len(c) > 1]
    assert [60, 61] in multi
    assert [85, 86, 84, 87] in multi
    assert [106, 111, 107, 112, 114] in multi
    assert [91741, 92124, 91743, 91745, 91752, 91758, 91772, 91775, 91777] in multi
    assert [91723, 91724] in multi
    assert [99127, 99128, 99129, 99130, 99131] in multi
    # No quest is in two chains and none is lost.
    flat = [q for c in chains for q in c]
    assert len(flat) == len(set(flat)) == len(elwynn(lua, ns))
    standalone = {c[0] for c in chains if len(c) == 1}
    assert {16, 40, 47, 83, 88, 2158, 5545} <= standalone




# ----------------------------------------------- Side Quests view (smoke)
HARNESS = r"""
return function(chooser, hubmap, side, faction, doneIds)
  local created = {}
  local function new(kind, template)
    local o = { kind = kind, template = template, scripts = {}, shown = true }
    created[#created + 1] = o
    return setmetatable(o, { __index = function(t, k)
      if k == "CloseButton" or k == "TitleText" or k == "template" or k == "value"
         or k == "tex" or k == "title" then return nil end
      if k:match("^Create") then return function(_, kind2) return new(kind2) end end
      if k == "SetText" then return function(self, v) self.value = v end end
      if k == "SetTitle" then return function(self, v) self.title = v end end
      if k == "SetTexture" then return function(self, v) self.tex = v end end
      if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
      if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
      if k == "Show" then return function(self) self.shown = true end end
      if k == "Hide" then return function(self) self.shown = false end end
      if k == "IsShown" then return function(self) return self.shown end end
      return function() end
    end })
  end
  _G.CreateFrame = function(kind, name, parent, template) return new(kind, template) end
  _G.UIParent = {}
  _G.UISpecialFrames = {}
  _G.tinsert = table.insert
  _G.UnitLevel = function() return 5 end
  _G.GameTooltip = nil

  local ns = { cdb = { routeManual = {} }, Sagas = { human = { name = "Human Saga" } },
               StoryRoute = {} }
  assert(loadstring(chooser, "@HubChooser.lua"))("MainStoryGuide", ns)
  assert(loadstring(side, "@ZoneSideQuests.lua"))("MainStoryGuide", ns)
  local done, inLog = {}, {}
  for _, id in ipairs(doneIds) do done[id] = true end
  ns.GetActiveSaga = function() return "human" end
  ns.QuestCounts = function() return 0, 0 end
  ns.IsSagaReadOnly = function() return false end
  ns.NowChainId = function() return nil end
  ns.ZonesOnRoute = function() return {} end
  ns.SetForcedChainSoft = function(id) ns.cdb.forcedChain = id end
  ns.TurnTarget = function(q, info)
    local t = info and info.turn
    return { name = q.name, giver = t.name or q.giver, zone = t.zone or q.zone,
             map = t.map or q.map, x = t.x, y = t.y }
  end
  ns.FollowedChain = function() return nil end
  ns.ChooserEntries = function() return {} end
  ns.IsCompleted = function(id) return done[id] or false end
  ns.IsInLog = function(id) return inLog[id] or false end
  ns.ZoneCatalog = function(zone)
    local side = {}
    for _, rec in ipairs(ns.ZoneSideQuests[zone] or {}) do
      if rec.faction == nil or rec.faction == faction then side[#side + 1] = rec end
    end
    return { main = {}, side = side }
  end
  ns.RefreshHub = function() ns.MapHubRefresh() end
  ns.ToggleHub = function() end
  local cleared, waypoints, givers, menus = 0, {}, {}, {}
  ns.ClearWaypoint = function() cleared = cleared + 1 end
  ns.SetWaypoint = function(t, o) waypoints[#waypoints + 1] = t.name; givers[#givers + 1] = t.giver end
  ns.RouteToggleStep = function(step)
    local m = ns.cdb.routeManual
    if m[step.key] then m[step.key] = nil else m[step.key] = true end
  end
  assert(loadstring(hubmap, "@HubMap.lua"))("MainStoryGuide", ns)
  ns.MapHubMenu = function(owner, items) menus[#menus + 1] = items end
  local frame = ns.MapHubBuild()
  frame.shown = true

  local api = {}
  local function rows()
    local out = {}
    for _, o in ipairs(created) do
      if o.kind == "Button" and not o.template and o.shown then out[#out + 1] = o end
    end
    return out
  end
  local function buttons()
    local out = {}
    for _, o in ipairs(created) do
      if o.kind == "Button" and o.template then out[#out + 1] = o end
    end
    return out
  end
  function api.paint() ns.MapHubRefresh() end
  function api.title() return frame.title end
  function api.buttonTexts()
    local t = {}
    for _, b in ipairs(buttons()) do t[#t + 1] = b.value or "" end
    return table.concat(t, "|")
  end
  function api.press(text)
    for _, b in ipairs(buttons()) do
      if b.value == text then b.scripts.OnClick(b); return true end
    end
    return false
  end
  function api.dump()
    local out = {}
    for _, r in ipairs(rows()) do
      out[#out + 1] = table.concat({ r.text.value or "", r.meta.value or "", r.level.value or "",
        r.icon.shown and (r.icon.tex or "") or "", r.arrow.shown and "A" or "" }, "\t")
    end
    return table.concat(out, "\n")
  end
  function api.click(index, button)
    local r = rows()[index]
    r.scripts.OnClick(r, button or "LeftButton")
  end
  function api.menu()
    local last = menus[#menus]
    local t = {}
    for _, item in ipairs(last or {}) do t[#t + 1] = item.text end
    return table.concat(t, "|")
  end
  function api.runMenu(text)
    for _, item in ipairs(menus[#menus]) do
      if item.text == text then item.func(); return true end
    end
    return false
  end
  function api.follow() return ns.cdb.sideFollow end
  function api.setFollow(v) ns.cdb.sideFollow = v end
  function api.manual(key) return ns.cdb.routeManual[key] end
  function api.setDone(id, v) done[id] = v end
  function api.setInLog(id, v) inLog[id] = v end
  function api.waypoints() return table.concat(waypoints, "|") end
  function api.givers() return table.concat(givers, "|") end
  function api.followStoryline()
    local items = ns.MapHubQuestMenu({ questID = 1, key = "1:ACCEPT" }, "some-chain")
    for _, item in ipairs(items) do
      if item.text == "Follow this storyline" then item.func(); return true end
    end
    return false
  end
  function api.cleared() return cleared end
  return api
end
"""

DONE_ICON = "Interface\\Buttons\\UI-CheckBox-Check"
NOW_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"


def build(lua, faction="Alliance", done=()):
    api = lua.execute(HARNESS)(CHOOSER, HUBMAP, SIDE, faction, lua.table_from(list(done)))
    api.paint()
    return api


def rows_of(api):
    out = []
    for line in api.dump().split("\n"):
        if line:
            name, meta, level, icon, arrow = line.split("\t")
            out.append({"name": name, "meta": meta, "level": level, "icon": icon, "arrow": arrow})
    return out


def index_of(api, name, nth=0):
    hits = [i + 1 for i, r in enumerate(rows_of(api)) if r["name"] == name]
    assert len(hits) > nth, f"no row {name!r} in {[r['name'] for r in rows_of(api)]}"
    return hits[nth]


def click(api, name, button="LeftButton", nth=0):
    api.click(index_of(api, name, nth), button)


def open_elwynn(api, chain=None):
    assert api.press("Side Quests")
    click(api, "Elwynn Forest")
    if chain:
        click(api, chain)


def test_the_tab_opens_and_returns_to_the_other_views(lua):
    api = build(lua)
    assert api.title() == "Human Saga"
    assert api.buttonTexts().split("|")[1:] == ["Zones", "Side Quests"]
    assert api.press("Side Quests")
    assert api.title() == "Human Saga - Side Quests"
    assert api.buttonTexts().split("|")[1:] == ["Zones", "Storylines"]
    # The same button goes back to the storyline list.
    assert api.press("Storylines")
    assert api.title() == "Human Saga"
    # The Zones button opens the zone list from the side view.
    assert api.press("Side Quests")
    assert api.press("Zones")
    assert api.title() == "Human Saga - Zones"


def test_a_zone_is_a_collapsible_row_with_level_range_and_count(lua):
    api = build(lua)
    api.press("Side Quests")
    rows = rows_of(api)
    # Lowest level first: Elwynn Forest opens the list.
    assert rows[0]["name"] == "Elwynn Forest"
    assert rows[0]["meta"] == "0 / 53"
    assert rows[0]["level"] == "1-40"
    assert rows[0]["arrow"] == "A"
    closed = len(rows)
    click(api, "Elwynn Forest")
    assert len(rows_of(api)) > closed
    click(api, "Elwynn Forest")
    assert len(rows_of(api)) == closed


def test_done_zone_quests_count(lua):
    api = build(lua, done=[16, 40])
    api.press("Side Quests")
    assert rows_of(api)[index_of(api, "Elwynn Forest") - 1]["meta"] == "2 / 53"


def test_a_chain_row_shows_progress_and_opens_to_ordered_quests(lua):
    api = build(lua, done=[85])
    api.setInLog(86, True)
    api.press("Side Quests")
    click(api, "Elwynn Forest")
    chain = rows_of(api)[index_of(api, "Lost Necklace") - 1]
    assert chain["meta"] == "1 / 4" and chain["arrow"] == "A"
    click(api, "Lost Necklace")
    names = [r["name"] for r in rows_of(api)]
    start = names.index("Lost Necklace") + 1
    assert names[start:start + 4] == ["Lost Necklace", "Pie for Billy", "Back to Billy", "Goldtooth"]
    quests = rows_of(api)[start:start + 4]
    assert quests[0]["icon"] == DONE_ICON  # done
    assert quests[1]["icon"] == NOW_ICON  # current
    assert quests[2]["icon"] == "" and quests[3]["icon"] == ""  # ahead


def test_a_standalone_quest_has_no_chain_arrow(lua):
    api = build(lua)
    open_elwynn(api)
    row = rows_of(api)[index_of(api, "Give Gerard a Drink") - 1]
    assert row["arrow"] == "" and row["level"] == "1"


def test_the_right_click_menu_has_the_storyline_actions(lua):
    api = build(lua, done=[85])
    open_elwynn(api, "Lost Necklace")
    click(api, "Pie for Billy", "RightButton")
    items = api.menu().split("|")
    assert "Follow this chain" in items
    assert any(t.startswith("Set waypoint: ") for t in items)
    assert "Show zone quests: Elwynn Forest" in items
    assert "Mark Done / Undo Mark" in items


def test_track_shows_for_a_quest_in_the_log(lua):
    api = build(lua, done=[85])
    api.setInLog(86, True)
    open_elwynn(api, "Lost Necklace")
    click(api, "Pie for Billy", "RightButton")
    assert "Track quest" in api.menu().split("|")


def test_a_standalone_quest_menu_has_no_follow_item(lua):
    api = build(lua)
    open_elwynn(api)
    click(api, "Give Gerard a Drink", "RightButton")
    items = api.menu().split("|")
    assert "Follow this chain" not in items and "Unfollow chain" not in items
    assert "Mark Done / Undo Mark" in items


def test_follow_pins_the_current_quest_and_unfollow_clears_it(lua):
    api = build(lua, done=[85])
    open_elwynn(api, "Lost Necklace")
    click(api, "Pie for Billy")  # a left click on a chain quest follows the chain
    assert api.follow() == "85"
    assert api.waypoints() == "Pie for Billy"
    click(api, "Pie for Billy", "RightButton")
    assert "Unfollow chain" in api.menu().split("|")
    assert api.runMenu("Unfollow chain")
    assert api.follow() is None
    assert api.cleared() == 1


def test_the_pin_moves_when_the_chain_advances(lua):
    api = build(lua, done=[85])
    open_elwynn(api, "Lost Necklace")
    click(api, "Pie for Billy")
    api.setDone(86, True)
    api.paint()
    assert api.waypoints() == "Pie for Billy|Back to Billy"


def test_a_finished_chain_releases_the_follow(lua):
    api = build(lua, done=[85, 86, 84])
    api.setFollow("85")
    api.paint()
    assert api.follow() == "85"
    api.setDone(87, True)
    api.paint()
    assert api.follow() is None


def test_mark_done_sets_and_clears_the_manual_mark(lua):
    api = build(lua)
    open_elwynn(api)
    click(api, "Give Gerard a Drink", "RightButton")
    assert api.runMenu("Mark Done / Undo Mark")
    assert api.manual("16:TURN IN") is True
    row = rows_of(api)[index_of(api, "Give Gerard a Drink") - 1]
    assert row["icon"] == DONE_ICON
    click(api, "Give Gerard a Drink", "RightButton")
    assert api.runMenu("Mark Done / Undo Mark")
    assert api.manual("16:TURN IN") is None


def test_jump_to_zone_opens_the_zone_view(lua):
    api = build(lua)
    open_elwynn(api)
    click(api, "Give Gerard a Drink", "RightButton")
    assert api.runMenu("Show zone quests: Elwynn Forest")
    assert api.title() == "Human Saga - Zones"


def test_other_faction_quests_are_hidden(lua):
    api = build(lua, faction="Horde")
    api.press("Side Quests")
    names = [r["name"] for r in rows_of(api)]
    assert names and "Elwynn Forest" not in names  # the zones of the other faction stay


def test_the_pin_moves_to_the_turn_in_npc_once_the_quest_is_accepted(lua):
    api = build(lua)
    open_elwynn(api, "Lost Necklace")
    click(api, "Lost Necklace", nth=1)  # the quest row follows the chain
    assert api.givers() == '"Auntie" Bernice Stonefield'
    api.setInLog(85, True)
    api.paint()
    assert api.givers() == '"Auntie" Bernice Stonefield|Billy Maclure'
    api.paint()
    assert api.waypoints() == "Lost Necklace|Lost Necklace"  # no repeat while nothing changes


def test_a_current_quest_without_a_location_clears_the_old_pin(lua):
    api = build(lua)
    open_elwynn(api, "Lost Necklace")
    click(api, "Lost Necklace", nth=1)
    assert api.cleared() == 0
    api.setFollow("91741")  # Nibbled-On Book: no giver point until it is in the log
    api.paint()
    assert api.cleared() == 1
    api.setInLog(91741, True)
    api.paint()
    assert api.givers().endswith("Brother Paxton")


def test_following_a_storyline_releases_the_side_chain(lua):
    api = build(lua)
    open_elwynn(api, "Lost Necklace")
    click(api, "Lost Necklace", nth=1)
    assert api.follow() == "85"
    assert api.followStoryline()
    assert api.follow() is None
