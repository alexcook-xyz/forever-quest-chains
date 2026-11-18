#!/usr/bin/env python3
"""Pick the Molten Core, Onyxia and Blackwing Lair quests and write their gen_saga spec.

Issue #22 (E5 / 5.1). Reads the pinned QuestieDB cache (run
`python tools/extract_questie.py --download --ids 1 --out -` once) and writes
`tools/sagas/raids.json`, a `chainsOnly` spec with the saga key `Neutral`. The result is
deterministic; the rules below are the whole selection.

A raid quest has a Questie `zoneOrSort` of Molten Core, Onyxia's Lair or Blackwing Lair, with no
class gate, not repeatable (specialFlags bit 1), no level-1 placeholder and not in another spec;
the quests it needs are added when they qualify. The Duke Hydraxis quests after Eye of the
Emberseer (6822, 6823, 6824, 7486) need Molten Core, so they join the Molten Core chain (issue #20
stopped the Hydraxian chain at 6821). A quest open to only some races of a faction is left out, as
in `select_codas.py`. A quest that Forever gates differently or has no giver name stays out
(`FOREVER_CONFLICT`, `NO_GIVER` in `select_codas.py`) with every quest that needs it.
Zul'Gurub, Ahn'Qiraj and Naxxramas are issue 5.2 and 5.3.
"""
from __future__ import annotations

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import extract_questie as eq  # noqa: E402
import select_codas as sc  # noqa: E402

# zoneOrSort -> (chain id, name, extra seed quests that need this raid). Onyxia's Lair (2159) has no
# entry: its one Questie quest (7509) is repeatable, and its attunement is in the spines.
RAIDS = {
    2717: ("raid_molten_core", "Molten Core", [6822, 6823, 6824, 7486]),
    2677: ("raid_blackwing_lair", "Blackwing Lair", []),
}


def raids(quests, npcs) -> dict:
    taken = sc.taken_elsewhere("raids")
    chains = []
    for zone, (cid, name, extra) in RAIDS.items():
        seed = [i for i in quests.ids() if eq._field(quests.get(i), eq.QK["zoneOrSort"]) == zone] + extra
        facts = {i: f for i, f in sc.closure(seed, quests, npcs, taken).items()
                 if not f["classes"] and not f["specialFlags"] & 1 and f["requiredLevel"] > 1
                 and f["questLevel"] > 1 and sc.faction_of(f) == "Neutral"}
        ids = sc.order(list(sc.reachable(facts, taken)), facts)
        if ids:
            chains.append({"id": cid, "name": name, "zone": name, "summary": sc.summary(name, ids, facts),
                           "quests": [{"id": i} for i in ids]})
    return sc.spec_doc("Raid quests (issue #22): Molten Core, Onyxia's Lair and Blackwing Lair quests that "
                       "both factions take, with the quests they need. Chains only. Rules: tools/select_raids.py.",
                       "Raids", chains)


def main() -> int:
    quests, npcs = sc.load()
    doc = raids(quests, npcs)
    path = sc.SAGAS / "raids.json"
    path.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    for c in doc["chains"]:
        print(c["id"], [q["id"] for q in c["quests"]])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
