#!/usr/bin/env python3
"""Pick the Zul'Gurub and Ahn'Qiraj quests and write their gen_saga spec.

Issue #23 (E5 / 5.2). Reads the pinned QuestieDB cache (run
`python tools/extract_questie.py --download --ids 1 --out -` once) and writes
`tools/sagas/zg_aq.json`, a `chainsOnly` spec with the saga key `Neutral`. The result is
deterministic; the rules below are the whole selection. The spec has no route, as for the
dungeon codas (issue #20): both factions see the chains and no race route holds them.

A quest is kept when it has no class gate, is not repeatable (specialFlags bit 1), has no
level-1 placeholder, is open to a whole faction or to everyone, is in no other spec, and is not
in NO_GIVER, FOREVER_CONFLICT or CONFLICT. A quest that needs a dropped quest goes too (`cascade`).

Chains:
- `zul_gurub`: Questie `zoneOrSort` 1977 or 19 (Zul'Gurub), plus the quests they need.
- `zandalar_tribe`: a quest that rewards Zandalar Tribe reputation (faction 270).
- `ahn_qiraj`: `zoneOrSort` 3428 or 3429 (Temple and Ruins of Ahn'Qiraj), plus the quests that
  AQ_SEEDS need. The prerequisites of 8743, 8745 and 8756 stay in the chain. 8733 (issue #64) is in
  the chain, with 8734 to 8736 and 8741. The Narain line (8585 to 8587, issue #66) is a seed, so 8728
  and 8729 hold, and 8742, 8743 and 8745 return: 8742 needs 8729, 8730 and 8741 together.
8182 is also a seed of `zul_gurub`: it follows 8181 and ends that chain.
A quest that two chains claim stays in the first one, in this order. Each chain splits into one
chain for both factions, one for the Alliance and one for the Horde, as for the dungeons.

The Molten Core and Blackwing Lair quests are issue #22 (5.1, `select_raids.py`, spec `raids`); a quest
in that spec is never taken here, so it stays in its chain. The Plaguelands and Naxxramas quests are
issue #24 (5.3).
"""
from __future__ import annotations

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import extract_questie as eq  # noqa: E402
import select_codas as sc  # noqa: E402

ZUL_GURUB_ZONES = {1977, 19}
AHN_QIRAJ_ZONES = {3428, 3429}
ZANDALAR = 270  # Questie faction id of the Zandalar Tribe
AQ_SEEDS = (8743, 8745, 8756, 8587)  # 8587 Return to Narain: the Narain line (issue #66)
ZUL_GURUB_SEEDS = (8182,)  # The Hand of Rastakhan: the hand-in quest after 8181 (Confront Yeh'kinya)
# No giver name in Questie or PandaBase (gen_saga refuses them), found by the first build:
# 8183 The Heart of Hakkar and 8227 Nat's Measuring Tape.
NO_GIVER = {8183, 8227}
# Empty since issue #66: PandaBase adds 8578 and 8587 to 8728 (The Good News and The Bad News).
# 8578 is in the `raids` spec and the Narain line (8585 to 8587) is now a seed, so 8728 holds.
CONFLICT: set[int] = set()
CHAINS = (
    ("zul_gurub", "Zul'Gurub", "Zul'Gurub"),
    ("zandalar_tribe", "Zandalar Tribe", "Zul'Gurub"),
    ("ahn_qiraj", "Ahn'Qiraj", "Silithus"),
)


def taken_elsewhere() -> set[int]:
    """Quests of every other spec, the dungeon codas and the reputations included."""
    return sc.taken_elsewhere("zg_aq", NO_GIVER)


def eligible(f: dict) -> bool:
    return sc.eligible(f)


def seeds(quests) -> dict[str, list[int]]:
    """The quests that start each chain, before the prerequisite closure."""
    out: dict[str, list[int]] = {cid: [] for cid, _, _ in CHAINS}
    for qid in quests.ids():
        row = quests.get(qid)
        zone = eq._field(row, eq.QK["zoneOrSort"])
        if any(e[0] == ZANDALAR for e in sc.rep_rewards(row)):
            out["zandalar_tribe"].append(qid)
        elif zone in ZUL_GURUB_ZONES:
            out["zul_gurub"].append(qid)
        elif zone in AHN_QIRAJ_ZONES:
            out["ahn_qiraj"].append(qid)
    out["zul_gurub"] += list(ZUL_GURUB_SEEDS)
    out["ahn_qiraj"] += list(AQ_SEEDS)
    return out


def keep_set(facts: dict[int, dict], taken: set[int]) -> set[int]:
    """The quests the guide can hold: no conflict, and each prerequisite is held or in another spec."""
    return sc.keep_set(facts, taken, CONFLICT, NO_GIVER)


def raids(quests, npcs) -> dict:
    taken = taken_elsewhere()
    claimed, facts = sc.claim(CHAINS, seeds(quests), quests, npcs, taken)
    chains = sc.chain_docs(CHAINS, claimed, keep_set(facts, taken), facts, quests, npcs)
    return sc.spec_doc("Zul'Gurub and Ahn'Qiraj (issue #23): the quests of both raids, the Zandalar Tribe "
                       "reputation and the quests that open the Ahn'Qiraj gates. Chains only: no saga route "
                       "holds them. Selection rules: tools/select_zg_aq.py.", "ZGAQ", chains)


def main() -> int:
    quests, npcs = sc.load()
    doc = raids(quests, npcs)
    path = sc.SAGAS / "zg_aq.json"
    path.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    n = sum(len(c["quests"]) for c in doc["chains"])
    print(f"{path.name}: {len(doc['chains'])} chains, {n} quests")
    for c in doc["chains"]:
        print(" ", c["id"], [q["id"] for q in c["quests"]])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
