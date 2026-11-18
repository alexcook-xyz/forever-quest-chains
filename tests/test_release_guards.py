"""Tests for tools/genmanifest.py and tools/release.py (issue #28)."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import genmanifest  # noqa: E402
import release  # noqa: E402


def _addon(tmp_path: pathlib.Path) -> pathlib.Path:
    addon = tmp_path / "MainStoryGuide"
    addon.mkdir()
    return addon


def test_repo_is_clean():
    assert genmanifest.check() == []
    assert release.check() == []
    assert genmanifest.main(["check"]) == 0
    assert release.main(["check"]) == 0


def test_hand_edit_of_generated_lua_fails(tmp_path):
    addon = _addon(tmp_path)
    gen = addon / "Gen.lua"
    gen.write_text(genmanifest.MARKER + "extract_questie.py\nreturn {1}\n", encoding="utf-8")
    manifest = tmp_path / "m.json"
    genmanifest.update(tmp_path, manifest)
    assert genmanifest.check(tmp_path, manifest) == []
    gen.write_text(genmanifest.MARKER + "extract_questie.py\nreturn {2}\n", encoding="utf-8")
    problems = genmanifest.check(tmp_path, manifest)
    assert len(problems) == 1 and "Gen.lua" in problems[0]


def test_line_endings_do_not_count_as_drift(tmp_path):
    addon = _addon(tmp_path)
    gen = addon / "Gen.lua"
    gen.write_bytes((genmanifest.MARKER + "x\nreturn 1\n").encode())
    manifest = tmp_path / "m.json"
    genmanifest.update(tmp_path, manifest)
    gen.write_bytes((genmanifest.MARKER + "x\r\nreturn 1\r\n").encode())
    assert genmanifest.check(tmp_path, manifest) == []


def test_unregistered_and_missing_files_fail(tmp_path):
    addon = _addon(tmp_path)
    manifest = tmp_path / "m.json"
    (addon / "New.lua").write_text(genmanifest.MARKER + "x\n", encoding="utf-8")
    assert any("not in the manifest" in p for p in genmanifest.check(tmp_path, manifest))
    genmanifest.update(tmp_path, manifest)
    (addon / "New.lua").unlink()
    assert any("missing" in p for p in genmanifest.check(tmp_path, manifest))


def test_hand_authored_lua_is_not_treated_as_generated(tmp_path):
    addon = _addon(tmp_path)
    (addon / "Hand.lua").write_text("-- hand written\nreturn 1\n", encoding="utf-8")
    assert genmanifest.find_generated(tmp_path) == []


def test_release_flags_bad_toc(tmp_path):
    addon = _addon(tmp_path)
    (addon / "MainStoryGuide.toc").write_text(
        "## Interface: 16001\n## Version: nope\nMissing.lua\n", encoding="utf-8"
    )
    (addon / "Extra.lua").write_text("return 1\n", encoding="utf-8")
    (tmp_path / "CHANGELOG.md").write_text("# Changelog\n", encoding="utf-8")
    problems = " | ".join(release.check(tmp_path))
    for needle in ("not semver", "MainStoryGuideDB", "Missing.lua", "Extra.lua", "Unreleased"):
        assert needle in problems


def _art(tmp_path: pathlib.Path) -> None:
    (tmp_path / "docs/ui/reference").mkdir(parents=True)
    (tmp_path / "docs/ui/mockup/img").mkdir(parents=True)
    (tmp_path / "docs/ui/mockup/hub.html").write_text(
        "<script>/*ASSETS-START*/const IMG={a:'data:x'};/*ASSETS-END*/</script>",
        encoding="utf-8",
    )


def test_public_check_flags_art(tmp_path):
    _art(tmp_path)
    problems = " | ".join(release.check_public(tmp_path))
    for needle in ("docs/ui/reference", "docs/ui/mockup/img", "const IMG="):
        assert needle in problems


def test_public_check_clean_without_art(tmp_path):
    (tmp_path / "docs/ui/mockup").mkdir(parents=True)
    (tmp_path / "docs/ui/mockup/hub.html").write_text(
        "<script>/*ASSETS-START*//*ASSETS-END*/</script>", encoding="utf-8"
    )
    assert release.check_public(tmp_path) == []
    assert release.check_public(tmp_path / "missing") == []


def test_normal_check_ignores_art(tmp_path):
    _art(tmp_path)
    assert not any("art" in p for p in release.check(tmp_path))


def test_public_flag_fails_main_while_art_exists(monkeypatch, tmp_path):
    _art(tmp_path)
    monkeypatch.setattr(release, "check", lambda root=None: [])
    monkeypatch.setattr(release, "ROOT", tmp_path)
    assert release.main(["check", "--public"]) == 1
    assert release.main(["check"]) == 0
