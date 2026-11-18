"""The release zip holds the addon folder and nothing else."""
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import package  # noqa: E402


def test_zip_has_one_top_level_folder_and_the_toc(tmp_path):
    target = package.build(tmp_path)
    assert target.name == f"ForeverQuestChains-{package.toc_version()}.zip"
    names = zipfile.ZipFile(target).namelist()
    assert "MainStoryGuide/MainStoryGuide.toc" in names
    assert all(n.startswith("MainStoryGuide/") for n in names)


def test_zip_holds_no_dev_files(tmp_path):
    names = zipfile.ZipFile(package.build(tmp_path)).namelist()
    for bad in ("tests/", "tools/", "docs/", ".github/", "CLAUDE.md"):
        assert not any(bad in n for n in names)
