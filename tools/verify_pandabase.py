#!/usr/bin/env python3
"""Verify extracted Questie quest facts against PandaBase (Forever).

PandaBase is the verification source: quest pages at
https://pd.zroot.it/forever/quests/<id>. This tool never writes data files; it
reports where the extractor's facts (tools/extract_questie.py output) agree
with PandaBase, disagree, or cannot be checked.

Per quest the status is one of:
  verified   every compared field agrees
  mismatch   a field disagrees; fix the extractor or investigate, do not hand-edit
  manual     PandaBase lacks data for a field (e.g. no recorded location);
             needs an in-game check, coordinates are never guessed
  not-found  PandaBase has no page for the quest; needs an in-game check
  accepted   only mismatches listed in the --accept file, each with a reason

Exit status: 1 if any mismatch (or, with --strict, any manual/not-found), else 0.
No request cap or throttle is imposed; --delay is available if the site asks.

Usage:
  python tools/extract_questie.py --ids 7,783 --out facts.json
  python tools/verify_pandabase.py --facts facts.json
"""
from __future__ import annotations

import argparse
import html
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

BASE_URL = "https://pd.zroot.it/forever/quests/{id}"
USER_AGENT = "wow-forever-saga-guide-tools"
DEFAULT_TOLERANCE = 0.25  # map units (0-100); PandaBase text rounds to 0.1


# --------------------------------------------------------------------- parsing
def page_text(page_html: str) -> str:
    body = page_html.split("<body", 1)[-1]
    body = re.sub(r"<script.*?</script>|<style.*?</style>", "", body, flags=re.S)
    text = re.sub(r"<[^>]+>", " | ", body)
    text = html.unescape(text).replace("\xa0", " ")
    text = re.sub(r"\s+", " ", text)
    return re.sub(r"(\| )+", "| ", text)


def _json_blob(page_html: str, blob_id: str):
    m = re.search(rf'<script[^>]*id="{re.escape(blob_id)}"[^>]*>(.*?)</script>', page_html, flags=re.S)
    return json.loads(m.group(1)) if m else None


def _between(text: str, start: str, end: str) -> str | None:
    i = text.find(start)
    if i < 0:
        return None
    i += len(start)
    j = text.find(end, i)
    return text[i:j if j >= 0 else None]


def _ids(segment: str | None) -> list[int]:
    return sorted({int(x) for x in re.findall(r"#(\d+)", segment or "")})


def _on_map(x: float, y: float) -> bool:
    """PandaBase writes an off-map point (e.g. -0.010) for an unknown place."""
    return 0.0 <= x <= 1.0 and 0.0 <= y <= 1.0


def _endpoint(text: str, label: str, next_label: str) -> dict:
    seg = _between(text, f"{label} |", next_label)
    out = {"name": None, "kind": None, "zone": None, "x": None, "y": None, "located": False}
    if not seg:
        return out
    m = re.match(r"\s*(?P<name>.+?) \| (?P<kind>\w+) · (?P<rest>.*)", seg)
    if not m:
        return out
    out["name"], out["kind"] = m.group("name"), m.group("kind")
    c = re.search(r"(?:(?P<zone>[^|]+?) )?at (?P<x>-?[\d.]+), (?P<y>-?[\d.]+)", m.group("rest"))
    if c:
        out["zone"] = (c.group("zone") or "").strip() or None
        x, y = float(c.group("x")), float(c.group("y"))
        if _on_map(x, y):
            out.update(x=round(x * 100, 2), y=round(y * 100, 2), located=True)
    return out


def _before(segment: str | None) -> tuple[list[int], list[int]]:
    """Split the 'Before this' IDs into (all of these, any one of these)."""
    every, anyone = set(), set()
    for m in re.finditer(r"#(\d+)(?:\s*·\s*(any one|all) of these)?", segment or ""):
        (anyone if m.group(2) == "any one" else every).add(int(m.group(1)))
    return sorted(every), sorted(anyone)


def parse_quest_page(page_html: str) -> dict:
    """Extract the verification fields from a PandaBase Forever quest page."""
    text = page_text(page_html)
    h1 = re.search(r"<h1>(.*?)</h1>", page_html, flags=re.S)
    qid = re.search(r"Quest #(\d+)", text)
    lvl = re.search(r"quest level (\d+), requires level (\d+)", text)
    race = _between(text, "Race |", "| Class")
    klass = _between(text, "Class |", "| Level")
    faction = _between(text, "Faction |", "| Race")
    starts = _endpoint(text, "Starts at", "Hand in to")
    ends = _endpoint(text, "Hand in to", "Where ")
    givers = _json_blob(page_html, "map-givers-data") or {}
    # The giver blob has 4-decimal precision; prefer it over the rounded text.
    # Its points are on one map (art.zone), so a hand-in in another zone
    # keeps the text value.
    art_zone = (givers.get("art") or {}).get("zone")
    for key, ep in (("pickup", starts), ("turnIn", ends)):
        pt = givers.get(key)
        same_map = not (art_zone and ep["zone"]) or art_zone == ep["zone"]
        if pt and same_map and _on_map(pt["x"], pt["y"]):
            ep.update(x=round(pt["x"] * 100, 2), y=round(pt["y"] * 100, 2), located=True)
    before_seg = _between(text, "Before this", "After this")
    before_all, before_any = _before(before_seg)
    return {
        "id": int(qid.group(1)) if qid else None,
        "name": html.unescape(h1.group(1)).strip() if h1 else None,
        "questLevel": int(lvl.group(1)) if lvl else None,
        "requiredLevel": int(lvl.group(2)) if lvl else None,
        "faction": faction.strip() if faction else None,
        "races": None if race is None else (
            [] if race.strip().lower() == "any race" else [r.strip() for r in race.split(",")]),
        "objective": (_between(text, "What to do |", "|") or "").strip() or None,
        "classes": None if klass is None else (
            [] if klass.strip().lower() == "any class" else [c.strip() for c in klass.split(",")]),
        "before": _ids(before_seg),
        "beforeAll": before_all,
        "beforeAny": before_any,
        "after": _ids(_between(text, "After this", "Where it starts and ends")),
        "startedBy": starts,
        "finishedBy": ends,
        # UiMapID and zone name of the map PandaBase draws the givers on.
        "mapId": givers.get("mapId"),
        "mapZone": art_zone,
    }


# ------------------------------------------------------------------- comparing
def _near(x: float, y: float, spawns: dict, tol: float) -> bool:
    return any(abs(px - x) <= tol and abs(py - y) <= tol
               for pts in spawns.values() for px, py in pts)


def _compare_endpoint(findings: list, field: str, fact_ep: dict, pb_ep: dict, tol: float) -> None:
    creatures = fact_ep["creatures"]
    if not creatures:
        return  # item/object start: nothing to compare against Questie spawns
    names = {c["name"] for c in creatures if c["name"]}
    if pb_ep["name"] and names and pb_ep["name"] not in names:
        findings.append(("mismatch", f"{field}.name", sorted(names), pb_ep["name"]))
    if not pb_ep["located"]:
        findings.append(("manual", f"{field}.coords", "PandaBase has no location", None))
        return
    spawns = {}
    for c in creatures:
        spawns.update({f"{c['id']}:{z}": pts for z, pts in c["spawns"].items()})
    if not spawns:
        findings.append(("manual", f"{field}.coords", "Questie has no spawn", [pb_ep["x"], pb_ep["y"]]))
    elif not _near(pb_ep["x"], pb_ep["y"], spawns, tol):
        findings.append(("mismatch", f"{field}.coords",
                         {k: v for k, v in sorted(spawns.items())}, [pb_ep["x"], pb_ep["y"]]))


_COUNT_WORDS = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12}


def objective_counts(text: str | None) -> set[int]:
    """The distinct numbers in an objective text, as digits or as words up to twelve."""
    words = re.findall(r"[a-z]+|\d+", (text or "").lower())
    return {int(w) if w.isdigit() else _COUNT_WORDS[w] for w in words if w.isdigit() or w in _COUNT_WORDS}


def compare(fact: dict, pb: dict, tol: float = DEFAULT_TOLERANCE) -> list[tuple]:
    """Return findings as (severity, field, questie_value, pandabase_value)."""
    findings: list[tuple] = []
    for field in ("name", "questLevel", "requiredLevel"):
        if pb[field] is None:
            findings.append(("manual", field, fact[field], None))
        elif pb[field] != fact[field]:
            findings.append(("mismatch", field, fact[field], pb[field]))
    if pb["races"] is not None and sorted(pb["races"]) != sorted(fact["races"]):
        findings.append(("mismatch", "races", sorted(fact["races"]), sorted(pb["races"])))
    # Class audit: a class-gated quest must never pass as open to all classes.
    if pb.get("classes") is not None and sorted(pb["classes"]) != sorted(fact.get("classes") or []):
        findings.append(("mismatch", "classes", sorted(fact.get("classes") or []), sorted(pb["classes"])))
    # Issue #53: the counts in the objective (Kill 5 ..., 11 Sigil Fragments) are
    # compared when both sources give an objective text with a number.
    q_counts = objective_counts(" ".join(fact.get("objectivesText") or []))
    pb_counts = objective_counts(pb.get("objective"))
    if q_counts and pb_counts and q_counts != pb_counts:
        findings.append(("mismatch", "counts", sorted(q_counts), sorted(pb_counts)))
    q_before = sorted(set(fact["preQuestGroup"]) | set(fact["preQuestSingle"]))
    if pb["before"] != q_before:
        findings.append(("mismatch", "before", q_before, pb["before"]))
    _compare_endpoint(findings, "startedBy", fact["startedBy"], pb["startedBy"], tol)
    _compare_endpoint(findings, "finishedBy", fact["finishedBy"], pb["finishedBy"], tol)
    return findings


def status_of(findings: list[tuple]) -> str:
    severities = {f[0] for f in findings}
    for status in ("mismatch", "manual", "accepted"):
        if status in severities:
            return status
    return "verified"


def load_accepted(path: pathlib.Path | None) -> dict[tuple[int, str], dict]:
    """Investigated mismatches: {(quest id, field): entry}.

    Each entry gives a written reason and the exact `questie` and
    `pandabase` values that were investigated, e.g. a Forever change that
    PandaBase shows and the pinned QuestieDB does not. A later mismatch with
    other values in the same field is a new mismatch, not an accepted one.
    """
    if not path:
        return {}
    doc = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    out = {}
    for entry in doc.get("accepted", []):
        label = f"accepted mismatch {entry.get('id')} {entry.get('field')}"
        if not str(entry.get("reason", "")).strip():
            raise SystemExit(f"{label} has no reason")
        if "questie" not in entry or "pandabase" not in entry:
            raise SystemExit(f"{label} must give the investigated questie and pandabase values")
        out[(int(entry["id"]), entry["field"])] = entry
    return out


def is_accepted(accepted: dict, quest_id: int, field: str, questie, pandabase) -> bool:
    entry = accepted.get((quest_id, field))
    return bool(entry) and entry["questie"] == questie and entry["pandabase"] == pandabase


# --------------------------------------------------------------------- network
# A busy server answers these codes; a short wait and a new try usually works (issue #21).
RETRY_CODES = {429, 502, 503, 504}
RETRY_WAITS = (2, 5, 10)  # seconds before try 2, 3 and 4


def get_text(url: str, timeout: float = 30, sleep=time.sleep) -> str | None:
    """The body of a PandaBase page, None for a 404. Waits and retries when busy."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for wait in (*RETRY_WAITS, None):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 (fixed https host)
                return resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return None
            if exc.code not in RETRY_CODES or wait is None:
                raise
        sleep(wait)


def fetch_page(quest_id: int, timeout: float = 30, sleep=time.sleep) -> str | None:
    return get_text(BASE_URL.format(id=quest_id), timeout, sleep)


def verify(facts: dict, ids: list[int] | None = None, fetch=fetch_page,
           tol: float = DEFAULT_TOLERANCE, delay: float = 0.0,
           accepted: dict[tuple[int, str], dict] | None = None) -> list[dict]:
    accepted = accepted or {}
    results = []
    for fact in facts["quests"]:
        if ids is not None and fact["id"] not in ids:
            continue
        page = fetch(fact["id"])
        if page is None:
            results.append({"id": fact["id"], "name": fact["name"], "status": "not-found", "findings": []})
        else:
            findings = [("accepted" if s == "mismatch" and is_accepted(accepted, fact["id"], f, q, p) else s,
                         f, q, p)
                        for s, f, q, p in compare(fact, parse_quest_page(page), tol)]
            results.append({
                "id": fact["id"], "name": fact["name"], "status": status_of(findings),
                "findings": [{"severity": s, "field": f, "questie": q, "pandabase": p}
                             for s, f, q, p in findings],
            })
        if delay:
            time.sleep(delay)
    return results


def exit_code(results: list[dict], strict: bool = False) -> int:
    bad = {"mismatch", "manual", "not-found"} if strict else {"mismatch"}
    return 1 if any(r["status"] in bad for r in results) else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--facts", type=pathlib.Path, required=True, help="JSON from extract_questie.py")
    ap.add_argument("--ids", help="comma-separated subset of quest IDs")
    ap.add_argument("--tolerance", type=float, default=DEFAULT_TOLERANCE)
    ap.add_argument("--delay", type=float, default=0.0, help="seconds between requests (default: none)")
    ap.add_argument("--strict", action="store_true", help="also fail on manual/not-found")
    ap.add_argument("--out", help="write the JSON report here")
    ap.add_argument("--accept", type=pathlib.Path,
                    help="JSON list of investigated mismatches ({id, field, reason}) that do not fail")
    args = ap.parse_args(argv)

    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    ids = [int(x) for x in args.ids.split(",")] if args.ids else None
    accepted = load_accepted(args.accept)
    results = verify(facts, ids, tol=args.tolerance, delay=args.delay, accepted=accepted)
    for r in results:
        print(f"{r['status']:<9} {r['id']:>6}  {r['name']}")
        for f in r["findings"]:
            print(f"            {f['severity']}: {f['field']}  questie={f['questie']!r}  pandabase={f['pandabase']!r}")
    counts = {s: sum(r["status"] == s for r in results)
              for s in ("verified", "accepted", "mismatch", "manual", "not-found")}
    used = {(r["id"], f["field"]) for r in results for f in r["findings"] if f["severity"] == "accepted"}
    checked = {r["id"] for r in results}
    for key in sorted(set(accepted) - used):
        if key[0] in checked:
            print(f"stale accept: {key[0]} {key[1]} no longer matches the investigated values; "
                  "re-investigate, then update or remove it")
    print(", ".join(f"{n} {s}" for s, n in counts.items()))
    if args.out:
        pathlib.Path(args.out).write_text(
            json.dumps({"results": results}, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    return exit_code(results, args.strict)


if __name__ == "__main__":
    sys.exit(main())
