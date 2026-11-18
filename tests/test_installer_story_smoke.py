"""Installer + /story smoke test (Issue #9, E0 / 0.3).

Fresh-install smoke test via Install-Or-Update-MainStoryGuide.ps1 on
Windows; /story opens; next-step is one of NEXT: PICK UP /
IN PROGRESS / STORY GAP / CHAIN COMPLETE.

The live installer run is Windows-only (PLAN.md section 8: the
installer suite skips off Windows). Cross-platform source checks
verify the /story wiring and the four next-step literals so the
ubuntu CI still exercises the state mapping.
"""
from __future__ import annotations

import os
import pathlib
import re
import subprocess
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MainStoryGuide"
INSTALLER = ROOT / "Install-Or-Update-MainStoryGuide.ps1"
CORE = ADDON / "Core.lua"
HUB = ADDON / "Hub.lua"
TOC = ADDON / "MainStoryGuide.toc"

NEXT_LABELS = [
    ("PICKUP", "NEXT: PICK UP"),
    ("IN_PROGRESS", "NEXT: IN PROGRESS"),
    ("GAP", "NEXT: STORY GAP"),
    ("DONE", "NEXT: CHAIN COMPLETE"),
]


def _read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


# ------------------------------------------------------- /story opens wiring
def test_story_slash_opens_hub():
    core = _read(CORE)
    assert 'SLASH_MAINSTORYGUIDE1 = "/story"' in core
    assert 'SlashCmdList["MAINSTORYGUIDE"]' in core
    assert "ns.ToggleHub(true)" in core
    hub = _read(HUB)
    assert "function ns.ToggleHub" in hub
    assert "ns.BuildHub" in hub
    assert "ns.RefreshHub" in hub


def test_resolve_chain_four_states_in_source():
    core = _read(CORE)
    assert "function ns.ResolveChain" in core
    for state in ("PICKUP", "IN_PROGRESS", "GAP", "DONE"):
        assert state in core, f"ResolveChain state {state} missing in Core.lua"


# --------------------------------------------------- next-step: exactly one
def test_next_step_labels_map_all_four_states():
    hub = _read(HUB)
    assert "function ns.NextStepLabel" in hub
    for state, label in NEXT_LABELS:
        assert re.search(rf"{state}\s*=\s*\"{re.escape(label)}\"", hub), (
            f"mapping {state} -> {label} missing in Hub.lua"
        )
    # Exactly the four acceptance literals, each appearing once as a
    # quoted display string (comments may mention the literals too).
    for _state, label in NEXT_LABELS:
        assert hub.count(f'"{label}"') == 1, f"label {label} must appear exactly once"
    assert hub.count('"NEXT: ') == 4


def test_next_step_label_rendered_once_in_the_story_reader():
    story = _read(ADDON / "HubStory.lua")
    route = story[story.find("function ns.StoryView"):]
    # One NEXT: line per quest reader: set from the state of the open
    # storyline, or from DONE when every step is complete.
    assert route.count("reader.nextLine =") == 2
    assert "ns.NextStepLabel(state)" in route
    assert 'ns.NextStepLabel("DONE")' in route


def test_next_step_labels_have_no_banned_voice():
    for _state, label in NEXT_LABELS:
        assert "you" not in label.lower()
        assert "traveler" not in label.lower()


def test_installer_script_contract_textual():
    assert INSTALLER.is_file(), "Install-Or-Update-MainStoryGuide.ps1 missing"
    script = _read(INSTALLER)
    assert "-TargetDir" in script
    assert "MainStoryGuide.toc" in script
    assert "Copy-Item" in script
    assert "exit 1" in script or "Write-Error" in script
    assert "SavedVariables" in script
    assert "MainStoryGuideDB" in script


def test_no_guessed_coordinates_in_installer():
    script = _read(INSTALLER)
    assert not re.search(r"\bmap\s*=\s*\d+", script)
    assert not re.search(r"\bx\s*=\s*\d+\.\d+", script)


# ------------------------------------------------- Windows fresh-install run
@pytest.mark.skipif(sys.platform != "win32", reason="Windows fresh-install smoke test")
def test_installer_fresh_install(tmp_path):
    target = tmp_path / "AddOns"
    cmd = [
        "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", str(INSTALLER), "-TargetDir", str(target),
    ]
    first = subprocess.run(cmd, capture_output=True, text=True)
    assert first.returncode == 0, first.stderr
    installed = target / "MainStoryGuide"
    assert (installed / "MainStoryGuide.toc").is_file()
    assert (installed / "Core.lua").is_file()
    assert (installed / "Hub.lua").is_file()
    toc = (installed / "MainStoryGuide.toc").read_text(encoding="utf-8")
    assert "## Version: 0.1.0-alpha" in toc
    assert "## SavedVariables: MainStoryGuideDB" in toc
    assert "## SavedVariablesPerCharacter: MainStoryGuideCharDB" in toc
    # Copied verbatim.
    assert (installed / "Core.lua").read_text(encoding="utf-8") == _read(CORE)
    assert (installed / "Hub.lua").read_text(encoding="utf-8") == _read(HUB)
    # Idempotent: a second run exits cleanly with the same tree.
    second = subprocess.run(cmd, capture_output=True, text=True)
    assert second.returncode == 0, second.stderr
    assert (installed / "MainStoryGuide.toc").is_file()


@pytest.mark.skipif(sys.platform != "win32", reason="Windows fresh-install smoke test")
def test_installer_preserves_savedvariables(tmp_path):
    target = tmp_path / "WoW"
    saved = target / "WTF" / "Account" / "MainStoryGuide" / "SavedVariables"
    saved.mkdir(parents=True)
    sentinel = saved / "MainStoryGuideDB.lua"
    sentinel.write_text("-- progress sentinel\n", encoding="utf-8")
    cmd = [
        "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", str(INSTALLER), "-TargetDir", str(target / "AddOns"),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert sentinel.read_text(encoding="utf-8") == "-- progress sentinel\n"


def test_toc_identity_matches_installer_expectation():
    toc = _read(TOC)
    assert "## Version: 0.1.0-alpha" in toc
    assert "## SavedVariables: MainStoryGuideDB" in toc
    assert "## SavedVariablesPerCharacter: MainStoryGuideCharDB" in toc
