"""Core.lua voice guard.

Every string in Core.lua is player-facing chat or tooltip text, so the whole
file is scanned with the story voice rules (no "you"/"your", no first person,
no "the traveler").
"""
from __future__ import annotations

import pathlib

import test_story_voice as voice

CORE = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide" / "Core.lua"


def test_core_lua_has_no_banned_voice():
    source = CORE.read_text(encoding="utf-8")
    problems = [
        f"Core.lua:{line}: {label}: {match!r}"
        for line, label, match in voice.scan_source(source)
    ]
    assert not problems, "banned voice in Core.lua:\n" + "\n".join(problems)
