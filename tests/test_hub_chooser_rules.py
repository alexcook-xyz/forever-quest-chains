"""Hub chooser rules (issue #59, issue #78).

These tests run the real MainStoryGuide/HubChooser.lua in a Lua 5.1 runtime
(lupa.lua51, the same Lua version as the WoW client). The file is pure: it
holds no UI call and no WoW API call. The rules come from the Components
section of DESIGN.md.
"""
from __future__ import annotations

import pathlib

import pytest

lua51 = pytest.importorskip("lupa.lua51")

ADDON = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide"
SRC = (ADDON / "HubChooser.lua").read_text(encoding="utf-8")

HARNESS = r"""
return function(src)
  local ns = {}
  assert(loadstring(src, "@HubChooser.lua"))("MainStoryGuide", ns)
  return ns
end
"""


@pytest.fixture(scope="module")
def lua():
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    return rt


@pytest.fixture(scope="module")
def ns(lua):
    return lua.execute(HARNESS)(SRC)


def entry(lua, **kw):
    base = dict(id="a", name="A", state="PICKUP", done=0, total=5,
                minLevel=1, maxLevel=11, skipped=False, optional=False)
    base.update(kw)
    return lua.table_from(base)


# --- icon (section 3 and section 4) -------------------------------------

def test_icon_new_progress_none_and_locked(lua, ns):
    assert ns.ChooserIcon(entry(lua), 1) == "new"
    assert ns.ChooserIcon(entry(lua, state="IN_PROGRESS"), 1) == "progress"
    assert ns.ChooserIcon(entry(lua, done=2), 1) == "progress"
    assert ns.ChooserIcon(entry(lua, state="DONE", done=5), 1) is None
    assert ns.ChooserIcon(entry(lua, skipped=True), 1) == "locked"


def test_icon_locked_only_when_more_than_four_levels_above(lua, ns):
    e = entry(lua, minLevel=10, maxLevel=20)
    assert ns.ChooserIcon(e, 6) == "new"      # 10 = 6 + 4, still new
    assert ns.ChooserIcon(e, 5) == "locked"   # 10 > 5 + 4


def test_skipped_beats_progress_and_done(lua, ns):
    assert ns.ChooserIcon(entry(lua, skipped=True, state="IN_PROGRESS"), 1) == "locked"
    assert ns.ChooserIcon(entry(lua, skipped=True, state="DONE", done=5), 1) == "locked"


def test_dimmed_follows_the_locked_icon(lua, ns):
    assert ns.ChooserDimmed(entry(lua, skipped=True), 1) is True
    assert ns.ChooserDimmed(entry(lua), 1) is False


def test_tag(lua, ns):
    assert ns.ChooserTag(entry(lua, minLevel=1, maxLevel=11)) == "Levels 1-11"
    assert ns.ChooserTag(entry(lua, skipped=True)) == "Skipped"


# --- sections (rule 5) ----------------------------------------------------

def _titles(ns, sections):
    return [sections[i].title for i in range(1, len(sections) + 1)]


def _ids(section):
    return [section.rows[i].id for i in range(1, len(section.rows) + 1)]


def test_sections_order_and_membership(lua, ns):
    entries = lua.table_from([
        entry(lua, id="done", state="DONE", done=5),
        entry(lua, id="skip", skipped=True),
        entry(lua, id="now", state="IN_PROGRESS"),
        entry(lua, id="prog", done=2),
        entry(lua, id="new"),
    ])
    sections = ns.ChooserSections(entries, "now")
    assert _titles(ns, sections) == ["Now", "Later", "Complete"]
    assert [_ids(sections[i]) for i in range(1, 4)] == [
        ["now"], ["skip", "prog", "new"], ["done"]]


def test_empty_sections_are_left_out(lua, ns):
    entries = lua.table_from([entry(lua, id="new")])
    sections = ns.ChooserSections(entries, None)
    assert _titles(ns, sections) == ["Later"]


def test_no_now_section_when_everything_is_complete(lua, ns):
    entries = lua.table_from([
        entry(lua, id="a", state="DONE", done=5),
        entry(lua, id="b", state="DONE", done=5),
    ])
    sections = ns.ChooserSections(entries, None)
    assert _titles(ns, sections) == ["Complete"]
    assert _ids(sections[1]) == ["a", "b"]


def test_later_sorts_by_level_with_optional_last(lua, ns):
    entries = lua.table_from([
        entry(lua, id="forever", minLevel=1, optional=True),
        entry(lua, id="high", minLevel=30),
        entry(lua, id="low", minLevel=5),
        entry(lua, id="low2", minLevel=5),
        entry(lua, id="mid", minLevel=12),
    ])
    sections = ns.ChooserSections(entries, None)
    assert _ids(sections[1]) == ["low", "low2", "mid", "high", "forever"]


def test_now_is_not_repeated_in_another_section(lua, ns):
    entries = lua.table_from([entry(lua, id="now", done=3), entry(lua, id="x")])
    sections = ns.ChooserSections(entries, "now")
    seen = [i for s in range(1, len(sections) + 1) for i in _ids(sections[s])]
    assert sorted(seen) == ["now", "x"]


def test_a_skipped_storyline_stays_in_later(lua, ns):
    entries = lua.table_from([entry(lua, id="now", skipped=True)])
    sections = ns.ChooserSections(entries, "now")
    assert _titles(ns, sections) == ["Later"]


def test_a_complete_storyline_is_complete_even_when_it_is_the_now_id(lua, ns):
    entries = lua.table_from([entry(lua, id="a", state="DONE", done=5)])
    assert _titles(ns, ns.ChooserSections(entries, "a")) == ["Complete"]


# --- caption (rule 4) -------------------------------------------------

def test_caption(lua, ns):
    info = lua.table_from(dict(raceName="Human", sagaName="Human Saga",
                               level=12, done=3, total=20, readOnly=False))
    assert ns.ChooserCaption(info) == "Level 12 Human - 3 / 20 quests"


def test_caption_read_only(lua, ns):
    info = lua.table_from(dict(raceName="Human", sagaName="Orc Saga",
                               level=12, done=0, total=20, readOnly=True))
    assert ns.ChooserCaption(info) == "Orc Saga (read-only): 0 / 20 quests"


def test_caption_saga_complete(lua, ns):
    info = lua.table_from(dict(raceName="Human", sagaName="Human Saga",
                               level=60, done=20, total=20, readOnly=False))
    assert ns.ChooserCaption(info) == "Level 60 Human - 20 / 20 quests - Saga complete"


def test_caption_empty_saga_is_not_complete(lua, ns):
    info = lua.table_from(dict(raceName="Human", sagaName="Human Saga",
                               level=1, done=0, total=0, readOnly=False))
    assert "complete" not in ns.ChooserCaption(info)


# --- action label (section 11) ---------------------------------------------

def test_action_labels(lua, ns):
    assert ns.ChooserActionLabel(entry(lua), False) == "Begin"
    assert ns.ChooserActionLabel(entry(lua, done=1), False) == "Continue"
    assert ns.ChooserActionLabel(entry(lua, state="IN_PROGRESS"), False) == "Continue"
    assert ns.ChooserActionLabel(entry(lua, state="DONE", done=5), False) == "Read Again"
    assert ns.ChooserActionLabel(entry(lua, skipped=True), False) == "Resume"


def test_action_label_view_in_a_read_only_saga(lua, ns):
    for kw in ({}, {"done": 1}, {"skipped": True}, {"state": "DONE", "done": 5}):
        assert ns.ChooserActionLabel(entry(lua, **kw), True) == "View"


# --- soft follow release (open question 6) ------------------------------------

def test_follow_applies_to_the_followed_chain(ns):
    assert ns.IsFollowActive("a", "a", "IN_PROGRESS") is True
    assert ns.IsFollowActive("a", "b", "IN_PROGRESS") is False
    assert ns.IsFollowActive(None, "a", "PICKUP") is False


def test_follow_releases_when_the_chain_is_complete(ns):
    assert ns.IsFollowActive("a", "a", "DONE") is False


# --- the next storyline and the story action -----------------------------------

def test_next_is_the_storyline_that_plays_now(lua, ns):
    entries = lua.table_from([entry(lua, id="a", state="DONE", done=5),
                              entry(lua, id="b"), entry(lua, id="c")])
    assert ns.ChooserNext(entries, "a", "c").id == "c"


def test_next_falls_back_to_the_first_open_storyline(lua, ns):
    entries = lua.table_from([entry(lua, id="a", state="DONE", done=5),
                              entry(lua, id="s", skipped=True),
                              entry(lua, id="b"), entry(lua, id="c")])
    assert ns.ChooserNext(entries, "a", None).id == "b"
    assert ns.ChooserNext(entries, "a", "a").id == "b"


def test_next_is_nil_at_the_end_of_the_saga(lua, ns):
    entries = lua.table_from([entry(lua, id="a", state="DONE", done=5),
                              entry(lua, id="s", skipped=True)])
    assert ns.ChooserNext(entries, "a", None) is None


def _info(lua, **kw):
    base = dict(readOnly=False, state="PICKUP", followed=False, started=False,
                nextName=None)
    base.update(kw)
    return lua.table_from(base)


def test_story_action_labels(lua, ns):
    assert ns.StoryActionLabel(_info(lua)) == "Begin"
    assert ns.StoryActionLabel(_info(lua, started=True)) == "Continue"
    assert ns.StoryActionLabel(_info(lua, state="DONE", nextName="Bravo")) == "Continue: Bravo"


def test_story_action_is_hidden_when_there_is_nothing_to_do(lua, ns):
    assert ns.StoryActionLabel(_info(lua, followed=True, started=True)) is None
    assert ns.StoryActionLabel(_info(lua, state="DONE")) is None
    assert ns.StoryActionLabel(_info(lua, readOnly=True)) is None
    assert ns.StoryActionLabel(_info(lua, readOnly=True, state="DONE", nextName="B")) is None


def test_menu_labels(lua, ns):
    assert ns.ChooserMenuLabel(entry(lua), False) == "Skip Storyline"
    assert ns.ChooserMenuLabel(entry(lua, skipped=True), False) == "Resume Storyline"
    assert ns.ChooserMenuLabel(entry(lua, state="DONE", done=5), False) is None
    assert ns.ChooserMenuLabel(entry(lua), True) is None
# --- saga picker -----------------------------------------------------

def test_saga_picker_lists_sagas_with_data_and_marks_own_and_active(lua, ns):
    order = lua.table_from(["Human", "Gnome", "Orc"])
    sagas = lua.table_from({
        "Human": lua.table_from(dict(name="Human Saga", faction="Alliance")),
        "Gnome": lua.table_from(dict(name="Gnome Saga", faction="Alliance")),
        "Orc": lua.table_from(dict(name="Orc Saga", faction="Horde")),
    })
    has = lua.eval("function(k) return k ~= 'Orc' end")
    out = ns.SagaPickerEntries(order, sagas, has, "Human", "Gnome")
    rows = list(out.values())
    assert [r["key"] for r in rows] == ["Human", "Gnome"]
    assert rows[0]["active"] and not rows[0]["own"]
    assert rows[1]["own"] and not rows[1]["active"]
    assert ns.SagaPickerLabel(rows[0]) == "Human Saga (Alliance)"
    assert ns.SagaPickerLabel(rows[1]) == "Gnome Saga (home race)"
    assert ns.SagaPickerButtonText("Human Saga") == "Saga: Human Saga"
