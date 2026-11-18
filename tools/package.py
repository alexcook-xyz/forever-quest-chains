#!/usr/bin/env python3
"""Build the addon zip for CurseForge, GitHub releases or a manual install.

The zip holds one top-level folder, ``MainStoryGuide/``, with the addon files
only (no tests, tools or docs). The file name carries the .toc version:

    dist/ForeverQuestChains-<version>.zip

Usage:
    python tools/package.py
    python tools/package.py --out some/dir
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = "MainStoryGuide"
PRODUCT = "ForeverQuestChains"


def toc_version(root: pathlib.Path = ROOT) -> str:
    toc = (root / ADDON / f"{ADDON}.toc").read_text(encoding="utf-8")
    m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not m:
        raise SystemExit("package: the .toc has no '## Version:' line")
    return m.group(1)


def build(out_dir: pathlib.Path, root: pathlib.Path = ROOT) -> pathlib.Path:
    src = root / ADDON
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"{PRODUCT}-{toc_version(root)}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(src.rglob("*")):
            if path.is_file():
                zf.write(path, f"{ADDON}/{path.relative_to(src).as_posix()}")
    return target


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", default=str(ROOT / "dist"), help="output directory")
    args = ap.parse_args(argv)
    print(build(pathlib.Path(args.out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
