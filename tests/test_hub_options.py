"""Hub options guard (issue #59, PR 1).

No Lua runtime is available in CI, so these tests read the Lua files as text.
They check that settings and bulk resets live only in the Interface Options
panel (System.lua) and that every entry point opens that panel.
"""
from __future__ import annotations

import pathlib
import re

ADDON = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide"
HUB = (ADDON / "Hub.lua").read_text(encoding="utf-8")
SYSTEM = (ADDON / "System.lua").read_text(encoding="utf-8")
CORE = (ADDON / "Core.lua").read_text(encoding="utf-8")

CHECK_KEYS = ("Minimap", "Gossip", "Tooltip", "AutoWaypoint", "WaypointUI",
              "Sparkles", "KillMarks", "Hints")
BUTTON_LABELS = ("Open Story Guide", "Resume All Skipped", "Reset Manual Marks")


def _panel_body():
    m = re.search(r"function ns\.BuildOptionsPanel\(\).*?\nend\n", SYSTEM, re.S)
    assert m, "ns.BuildOptionsPanel not found in System.lua"
    return m.group(0)


def test_hub_has_no_options_pane():
    for token in ("BuildOptionsPane", "sel.options", "OpenHubOptions",
                  "btnOptions", "optChecks", 'TabFrame("options")'):
        assert token not in HUB, f"Hub.lua still holds the options pane: {token}"


def test_no_file_calls_the_removed_hub_options_entry():
    for path in ADDON.glob("*.lua"):
        assert "OpenHubOptions" not in path.read_text(encoding="utf-8"), path.name


def test_panel_has_eight_checkboxes():
    body = _panel_body()
    keys = re.findall(r'MakeOptionCheck\(panel, "(\w+)"', body)
    assert tuple(keys) == CHECK_KEYS


def test_panel_has_three_buttons_in_order():
    body = _panel_body()
    labels = re.findall(r'OptionButton\("([^"]+)"', body)
    assert tuple(labels) == BUTTON_LABELS


def test_panel_has_native_defaults_and_no_hub_reset_button():
    body = _panel_body()
    assert "panel.default = ApplyOptionsDefaults" in body
    assert "panel.OnDefault = ApplyOptionsDefaults" in body
    assert "Reset Defaults" not in HUB and "Reset Defaults" not in body


def test_entry_points_open_interface_options():
    # Slash command: options, config and settings.
    m = re.search(r'cmd == "options".*?\n(.*?)\n  elseif', CORE, re.S)
    assert m and "ns.OpenOptions()" in m.group(1), "/story options must open the panel"
    # Minimap, compartment and quest-log right clicks.
    assert SYSTEM.count('"RightButton"') >= 3
    right_blocks = re.findall(r'== "RightButton"(?: then)?(.*?)(?:else|end)', SYSTEM, re.S)
    assert len(right_blocks) >= 3
    for block in right_blocks:
        assert "ns.OpenOptions()" in block, block


def test_hint_option_is_off_by_default_and_gates_the_reader():
    core = (ADDON / "Core.lua").read_text(encoding="utf-8")
    story = (ADDON / "HubStory.lua").read_text(encoding="utf-8")
    assert "if db.showHints == nil then db.showHints = false end" in core
    assert "d.hint and ns.db and ns.db.showHints" in story
