"""Selection rules for the raid quests (issue #22)."""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import select_raids as sr  # noqa: E402
import write_coda_journals as wj  # noqa: E402

SPEC = json.loads((ROOT / "tools" / "sagas" / "raids.json").read_text(encoding="utf-8"))


def test_the_spec_holds_the_hydraxis_tail_in_the_molten_core_chain():
    chains = {c["id"]: [q["id"] for q in c["quests"]] for c in SPEC["chains"]}
    assert set(chains) == {"raid_molten_core", "raid_blackwing_lair"}
    assert {6822, 6823, 6824, 7486} <= set(chains["raid_molten_core"])
    assert chains["raid_molten_core"].index(6822) < chains["raid_molten_core"].index(7486)


def test_raid_zones_are_the_issue_22_raids():
    assert set(sr.RAIDS) == {2717, 2677}  # Onyxia has no raid-only quest (7509 is repeatable)
    assert set(sr.RAIDS) <= sr.sc.RAID_ZONES


def test_the_raid_journal_is_up_to_date():
    assert "raids" in wj.KINDS
    assert wj.main(["--check"]) == 0
