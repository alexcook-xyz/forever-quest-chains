"""Hub chooser guard (E1 / 1.3).

These tests parse Sagas.lua as text. They check the structure the chooser
depends on: the saga registry, the faction order and the group names. They
also scan every Hub file for banned voice. The chooser rules (sections, icons,
verbs) are tested in test_hub_chooser_rules.py.
"""
from __future__ import annotations

import pathlib
import re

import test_story_voice as voice

ADDON = pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide"
SAGAS = (ADDON / "Sagas.lua").read_text(encoding="utf-8")

DEF_RE = re.compile(r'^Def\("(\w+)",\s*"([^"]+)",\s*"(\w+)",\s*"([^"]+)"\)', re.M)
FACTIONS = {"Alliance", "Horde"}


def _defs():
    return DEF_RE.findall(SAGAS)


def test_registry_has_unique_races_with_valid_factions():
    defs = _defs()
    assert defs, "no Def(...) saga entries found in Sagas.lua"
    keys = [d[0] for d in defs]
    assert len(keys) == len(set(keys)), "duplicate saga key"
    for key, name, faction, icon in defs:
        assert faction in FACTIONS, f"{key}: bad faction {faction}"
        assert name.endswith("Saga"), f"{key}: name should end with 'Saga'"
        assert icon, f"{key}: missing icon"


def test_alliance_races_come_before_horde_races():
    factions = [d[2] for d in _defs()]
    assert factions == sorted(factions, key=["Alliance", "Horde"].index), \
        "SagaOrder must list every Alliance race before any Horde race"


def test_chain_group_matches_chooser_groups():
    m = re.search(r"function ns\.ChainGroup\(.*?\nend\n", SAGAS, re.S)
    assert m, "ChainGroup not found"
    body = m.group(0)
    for group in ("race", "shared", "neutral", "forever"):
        assert f'"{group}"' in body, f"ChainGroup never returns {group}"
    # Neutral chains reach both factions unless authored with a faction.
    assert "chain.faction and chain.faction ~= ns.SagaFaction(sagaKey)" in body


def test_hub_and_sagas_ui_text_has_no_banned_voice():
    problems = []
    for name in ("Hub.lua", "HubChooser.lua", "HubStory.lua", "HubMap.lua", "Sagas.lua"):
        src = (ADDON / name).read_text(encoding="utf-8")
        for line, label, match in voice.scan_source(src):
            problems.append(f"{name}:{line}: {label}: {match!r}")
    assert not problems, "banned voice in Hub/Sagas UI text:\n" + "\n".join(problems)
