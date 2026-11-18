import changelog_guard as cg

CHANGELOG = """# Changelog

## [Unreleased]

- Existing entry.
- New entry.

## [0.1.0]

- Old release note.
"""


def test_unreleased_range():
    assert cg.unreleased_range(CHANGELOG) == (4, 7)
    assert cg.unreleased_range("# Changelog\n") is None


def test_added_lines_parses_hunks():
    diff = "@@ -5,0 +6 @@\n+- New entry.\n@@ -9 +10,2 @@\n+a\n+b\n@@ -12,2 +13,0 @@\n-x\n-y\n"
    assert cg.added_lines(diff) == [6, 10, 11]


def test_unguarded_paths_need_no_entry():
    assert cg.check(["docs/PLAN.md", "README.md", "MainStoryGuide/.gitkeep"], CHANGELOG, []) == []


def test_guarded_change_without_entry_fails():
    assert cg.check(["tools/x.py"], CHANGELOG, [])
    assert cg.check(["MainStoryGuide/Core.lua"], CHANGELOG, [])


def test_entry_must_be_under_unreleased():
    assert cg.check(["tests/test_x.py"], CHANGELOG, [6]) == []
    assert cg.check(["tests/test_x.py"], CHANGELOG, [10])  # old release section
    assert cg.check(["tests/test_x.py"], CHANGELOG, [4])   # blank line only


def test_missing_unreleased_section_fails():
    assert cg.check(["tools/x.py"], "# Changelog\n", [1])
