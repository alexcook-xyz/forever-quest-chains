#!/usr/bin/env python3
"""Forever-exclusive audit (issue #21).

A Forever-only quest is a quest that the pinned QuestieDB lacks and that
PandaBase has (Forever). The guide must account for each one: it is in a MAIN
chain, in a zone side list (tools/sagas/side_zones.json), or listed under
"excluded" in tools/sagas/forever_audit.json with a written reason.

The audit file records, for each audited zone, the Forever-only quest IDs on
the PandaBase map page of that zone. `check` is offline and deterministic: it
fails when such an ID is on no list, when an excluded ID is also on a list
(a stale exclusion), when an exclusion has no reason, and when a Forever-only
quest in a facts snapshot of tools/sagas is on no list.

Usage:
  python tools/audit_forever.py check
  python tools/audit_forever.py fetch    # network: reread the map pages, keep "excluded"
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import time

import extract_questie as eq
import gen_saga
import verify_pandabase

SAGA_DIR = pathlib.Path(__file__).resolve().parent / "sagas"
AUDIT = SAGA_DIR / "forever_audit.json"
SIDE_SPEC = SAGA_DIR / "side_zones.json"
MAP_URL = "https://pd.zroot.it/forever/map/{page}"
QUEST_LINK = re.compile(r"forever/quests/(\d+)")
# A map page is <continent>/<zone> in lower case: the text goes into a URL path.
MAP_PAGE = re.compile(r"[a-z0-9-]+/[a-z0-9-]+")


def map_quest_ids(page_html: str) -> list[int]:
    """The quest IDs that a PandaBase zone map page links."""
    return sorted({int(m) for m in QUEST_LINK.findall(page_html)})


def fetch_map(page: str, sleep=time.sleep) -> str:
    """One PandaBase zone map page (same retry rule as a quest page)."""
    if not MAP_PAGE.fullmatch(page):
        raise SystemExit(f"audit_forever: bad map page name {page!r}")
    text = verify_pandabase.get_text(MAP_URL.format(page=page), sleep=sleep)
    if text is None:
        raise SystemExit(f"audit_forever: map page {page} not found")
    return text


def load_audit(path: pathlib.Path = AUDIT) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def side_ids(spec_path: pathlib.Path = SIDE_SPEC) -> set[int]:
    return set(gen_saga.side_ids(json.loads(spec_path.read_text(encoding="utf-8"))))


def snapshot_forever_ids(folder: pathlib.Path = SAGA_DIR) -> set[int]:
    """Forever-only quests (source "pandabase") in every facts snapshot."""
    ids: set[int] = set()
    for path in sorted(folder.glob("*.facts.json")):
        facts = json.loads(path.read_text(encoding="utf-8"))
        ids |= {q["id"] for q in facts["quests"] if q.get("source") == "pandabase"}
    return ids


def problems(audit: dict, main: set[int], side: set[int], snapshot: set[int]) -> list[str]:
    """Every way the audit is incomplete or stale, as readable lines."""
    out = []
    excluded = {}
    for entry in audit.get("excluded", []):
        if not str(entry.get("reason", "")).strip():
            out.append(f"excluded quest {entry.get('id')} has no reason")
        excluded[entry["id"]] = entry
    listed = main | side
    for qid in sorted(set(excluded) & listed):
        out.append(f"quest {qid} is excluded but a MAIN chain or a side list holds it")
    for zone, info in audit["zones"].items():
        for qid in info["foreverIds"]:
            if qid not in listed and qid not in excluded:
                out.append(f"Forever-only quest {qid} on the {zone} map is on no list and not excluded")
    for qid in sorted(snapshot - listed - set(excluded)):
        out.append(f"Forever-only quest {qid} of a facts snapshot is on no list and not excluded")
    return out


def fetch_zones(audit: dict, fetch=fetch_map, questie_ids=None) -> dict:
    """Reread the Forever-only IDs of each audited zone; keep "excluded"."""
    if questie_ids is None:
        quest_db = eq.EntityDB.from_path(eq.CACHE_DIR / eq.PINNED_REF / eq.QUEST_FILE)
        questie_ids = set(quest_db.ids())
    zones = {}
    for zone, info in audit["zones"].items():
        found = map_quest_ids(fetch(info["page"]))
        zones[zone] = {"page": info["page"], "foreverIds": [i for i in found if i not in questie_ids]}
    return dict(audit, zones=zones)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("command", choices=["check", "fetch"])
    args = ap.parse_args(argv)
    audit = load_audit()
    if args.command == "fetch":
        audit = fetch_zones(audit)
        AUDIT.write_text(json.dumps(audit, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        print(f"audit_forever: wrote {AUDIT.name}")
    found = problems(audit, gen_saga.main_ids(), side_ids(), snapshot_forever_ids())
    for line in found:
        print(f"audit_forever: {line}", file=sys.stderr)
    if not found:
        print("audit_forever: OK")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
