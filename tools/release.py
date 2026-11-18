#!/usr/bin/env python3
"""Release-readiness check.

Minimal pre-release gate. It does not tag or publish anything; the release
process is in docs/RELEASING.md. Checks:

* the .toc declares Interface, Version (semver) and the MainStoryGuideDB
  SavedVariables identity,
* every file the .toc lists exists and every addon .lua is listed,
* CHANGELOG.md has an ``## [Unreleased]`` section,
* the generated-data guard (``genmanifest.py check``) is clean.

Usage:
    python tools/release.py check
    python tools/release.py check --public

``--public`` also fails while third-party art is in the repo:
docs/ui/reference/, docs/ui/mockup/img/ and the embedded art block in
docs/ui/mockup/hub.html. The art is allowed while the repo is private.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import genmanifest  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = "MainStoryGuide"
SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")


def toc_files(toc_text: str) -> list[str]:
    return [
        ln.strip().replace("\\", "/")
        for ln in toc_text.splitlines()
        if ln.strip() and not ln.startswith("#")
    ]


def check(root: pathlib.Path = ROOT) -> list[str]:
    problems: list[str] = []
    addon = root / ADDON
    toc_path = addon / f"{ADDON}.toc"
    if not toc_path.exists():
        return [f"{ADDON}/{ADDON}.toc is missing"]
    toc = toc_path.read_text(encoding="utf-8")

    if not re.search(r"^## Interface:\s*\d+", toc, re.M):
        problems.append(".toc has no '## Interface:' line")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not version:
        problems.append(".toc has no '## Version:' line")
    elif not SEMVER.match(version.group(1)):
        problems.append(f".toc Version '{version.group(1)}' is not semver")
    if not re.search(r"^## SavedVariables:\s*MainStoryGuideDB\b", toc, re.M):
        problems.append(".toc must declare SavedVariables: MainStoryGuideDB")

    listed = toc_files(toc)
    for rel in listed:
        if not (addon / rel).exists():
            problems.append(f".toc lists '{rel}' but the file is missing")
    for path in sorted(addon.rglob("*.lua")):
        rel = path.relative_to(addon).as_posix()
        if rel not in listed:
            problems.append(f"{ADDON}/{rel} is not listed in the .toc")

    changelog = root / "CHANGELOG.md"
    if not changelog.exists() or not re.search(
        r"^##\s*\[Unreleased\]", changelog.read_text(encoding="utf-8"), re.M | re.I
    ):
        problems.append("CHANGELOG.md has no '## [Unreleased]' section")

    problems += [f"generated data: {p}" for p in genmanifest.check(root)]
    return problems


ART_FOLDERS = ("docs/ui/reference", "docs/ui/mockup/img")
ART_HTML = "docs/ui/mockup/hub.html"
ART_BLOCK = re.compile(r"/\*ASSETS-START\*/(.*?)/\*ASSETS-END\*/", re.S)


def check_public(root: pathlib.Path = ROOT) -> list[str]:
    """Problems that stop the public flip: third-party art in the repo."""
    problems: list[str] = []
    for rel in ART_FOLDERS:
        if (root / rel).exists():
            problems.append(f"{rel}/ holds third-party art; delete it before the repo is public")
    html = root / ART_HTML
    if html.exists():
        text = html.read_text(encoding="utf-8")
        for block in ART_BLOCK.finditer(text):
            if "const IMG=" in block.group(1):
                problems.append(
                    f"{ART_HTML} has embedded art (const IMG=) between "
                    "ASSETS-START and ASSETS-END; remove it before the repo is public"
                )
                break
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("command", choices=["check"])
    ap.add_argument(
        "--public",
        action="store_true",
        help="also fail while third-party art is in the repo (run before the public flip)",
    )
    args = ap.parse_args(argv)
    problems = check(ROOT)
    if args.public:
        problems += check_public(ROOT)
    if problems:
        for p in problems:
            print(f"release: FAIL {p}", file=sys.stderr)
        return 1
    print("release: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
