#!/usr/bin/env python3
"""CI changelog guard.

Fails when a change touches the addon, the tooling or the tests but adds no
line under ``## [Unreleased]`` in CHANGELOG.md.

Usage (CI):  python tools/changelog_guard.py --base origin/main
"""
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GUARDED_PREFIXES = ("MainStoryGuide/", "tools/", "tests/")
CHANGELOG = "CHANGELOG.md"


def needs_entry(changed: list[str]) -> list[str]:
    """Changed paths that require a changelog entry."""
    return [p for p in changed if p.startswith(GUARDED_PREFIXES) and not p.endswith(".gitkeep")]


def unreleased_range(changelog_text: str) -> tuple[int, int] | None:
    """1-based inclusive (first, last) line numbers of the [Unreleased] body."""
    lines = changelog_text.splitlines()
    start = next((i for i, ln in enumerate(lines) if re.match(r"##\s*\[Unreleased\]", ln, re.I)), None)
    if start is None:
        return None
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return start + 2, end


def added_lines(diff: str) -> list[int]:
    """New-file line numbers of added lines in a ``git diff -U0`` for one file."""
    out: list[int] = []
    for m in re.finditer(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", diff, flags=re.M):
        start, count = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
        out.extend(range(start, start + count))
    return out


def check(changed: list[str], changelog_text: str, changelog_added: list[int]) -> list[str]:
    """Return a list of problems (empty means pass)."""
    guarded = needs_entry(changed)
    if not guarded:
        return []
    rng = unreleased_range(changelog_text)
    if rng is None:
        return [f"{CHANGELOG} has no '## [Unreleased]' section"]
    lines = changelog_text.splitlines()
    first, last = rng
    entries = [n for n in changelog_added if first <= n <= last and lines[n - 1].strip()]
    if entries:
        return []
    shown = ", ".join(guarded[:5]) + (" ..." if len(guarded) > 5 else "")
    return [f"{shown} changed but {CHANGELOG} has no new line under '## [Unreleased]'"]


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True,
                          text=True, encoding="utf-8").stdout


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--base", default="origin/main", help="ref to diff against (merge-base)")
    args = ap.parse_args(argv)
    changed = [p for p in _git("diff", "--name-only", f"{args.base}...HEAD").splitlines() if p]
    text = (ROOT / CHANGELOG).read_text(encoding="utf-8")
    added = added_lines(_git("diff", "-U0", f"{args.base}...HEAD", "--", CHANGELOG))
    problems = check(changed, text, added)
    for p in problems:
        print(f"changelog guard: {p}", file=sys.stderr)
    if not problems:
        print("changelog guard: ok")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
