"""Verification tests for the Human baseline (Issue #8 / Step 0.2).

Ensures:
  - The Human chain files define exactly 10 chains and 112 story quests (103 at
    the E0 baseline; 125, the Morbent Fel road and quest 1324 were added later).
  - Journal_Human.lua defines one journal entry per story quest.
  - Journal_Human.lua defines 10 epilogues matching those chain IDs.
  - Route_Human.lua covers all 112 quests.
  - No duplicate quest IDs exist across the Human chain files.
"""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MainStoryGuide"

EXPECTED_CHAINS = [
    "northshire", "elwynn", "peoples_militia", "defias_brotherhood",
    "redridge", "stockade", "stalvan", "duskwood_darkness",
    "missing_diplomat", "onyxia"
]
# The Missing Diplomat is generated (issue #38), so its chain lives in its own file.
DATA_FILES = ["Data_Human.lua", "Data_HumanDiplomat.lua"]


def _human_data() -> str:
    return "\n".join((ADDON / name).read_text(encoding="utf-8") for name in DATA_FILES)


def test_human_baseline_chains_and_quests_count():
    data = _human_data()

    chains = re.findall(r'id\s*=\s*"([^"]+)"', data)
    # Chain order in the view is asserted in tests/test_race_sagas.py::test_human_view_is_unchanged.
    assert sorted(chains) == sorted(EXPECTED_CHAINS), f"Expected 10 chains {EXPECTED_CHAINS}, found {chains}"
    assert len(chains) == 10

    quests = [int(qid) for qid in re.findall(r'\{\s*id\s*=\s*(\d+)', data)]
    assert len(quests) == 112, f"Expected 112 story quests, found {len(quests)}"
    assert len(set(quests)) == 112, "Duplicate quest IDs detected in the Human chain files"


def test_human_journal_integrity():
    data = _human_data()
    journal_human = (ADDON / "Journal_Human.lua").read_text(encoding="utf-8")

    expected_quest_ids = {int(qid) for qid in re.findall(r'\{\s*id\s*=\s*(\d+)', data)}
    expected_chain_ids = set(re.findall(r'id\s*=\s*"([^"]+)"', data))

    journal_quest_ids = {int(qid) for qid in re.findall(r'\[(\d+)\]\s*=\s*\{\s*title\s*=', journal_human)}
    assert journal_quest_ids == expected_quest_ids, "Journal entries do not match Human chain quest IDs 1:1"

    journal_epilogue_ids = set(re.findall(r'(\w+)\s*=\s*\{\s*title\s*=\s*"Epilogue:', journal_human))
    assert journal_epilogue_ids == expected_chain_ids, "Journal epilogues do not match Human chain IDs 1:1"


def test_human_route_covers_all_quests():
    data = _human_data()
    route_human = (ADDON / "Route_Human.lua").read_text(encoding="utf-8")

    expected_quest_ids = {int(qid) for qid in re.findall(r'\{\s*id\s*=\s*(\d+)', data)}

    route_match = re.search(r'local HUMAN_ROUTE = \{([^}]+)\}', route_human)
    assert route_match is not None, "Could not find local HUMAN_ROUTE in Route_Human.lua"

    route_ids = set(int(qid) for qid in re.findall(r'\b(\d+)\b', route_match.group(1)))
    missing = expected_quest_ids - route_ids
    assert not missing, f"Quests missing from Route_Human.lua: {missing}"


def test_human_route_keeps_chain_order():
    route_human = (ADDON / "Route_Human.lua").read_text(encoding="utf-8")
    route_match = re.search(r'local HUMAN_ROUTE = \{([^}]+)\}', route_human)
    assert route_match is not None, "Could not find local HUMAN_ROUTE in Route_Human.lua"
    clean_route = re.sub(r'--[^\n]*', '', route_match.group(1))
    route_ids = [int(qid) for qid in re.findall(r'\b(\d+)\b', clean_route)]
    assert len(route_ids) == 112

    for name in DATA_FILES:
        text = (ADDON / name).read_text(encoding="utf-8")
        for m in re.finditer(r'\{\s*id\s*=\s*"(\w+)".*?quests\s*=\s*\{(.*?)\}\s*\}', text, re.DOTALL):
            cid = m.group(1)
            qids = [int(q) for q in re.findall(r'\{\s*id\s*=\s*(\d+)', m.group(2))]
            pos = [route_ids.index(q) for q in qids if q in route_ids]
            assert len(pos) == len(qids), f"Chain {cid} has quests missing from Route_Human.lua"
            assert pos == sorted(pos), f"Chain {cid} quests do not appear in route in chain order"
