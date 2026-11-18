"""Story voice guard.

Narration is world-focused close third person: no first person, no second
person ("you"/"your"), and never "the traveler". Quest names, NPC names and
zone names are data and are not scanned.

Scanned narration:
  * every string in MainStoryGuide/Journal.lua, Journal_*.lua, WorldLore.lua and
    WorldLore_*.lua, except values of data keys (name, giver, zone, ...)
  * narration keys (summary, teaser, body, task, journal) in
    MainStoryGuide/Data_*.lua and ZoneSideQuests.lua. Quest names copied into
    those strings are removed first, so they are not flagged.

If no narration file is found at all, the guard fails: an empty tree must not
pass vacuously.
"""
from __future__ import annotations

import pathlib
import re
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MainStoryGuide"

NARRATION_FILES = ("Journal.lua", "Journal_*.lua", "WorldLore.lua", "WorldLore_*.lua")
SUMMARY_FILES = ("Data_*.lua", "ZoneSideQuests.lua")
NARRATION_KEYS = {"summary", "teaser", "body", "task", "journal"}
DATA_KEYS = {"name", "giver", "zone", "turnin", "npc", "race", "saga", "faction", "chain"}

# (label, compiled regex). Case-insensitive unless noted.
_FIRST_PERSON_PRONOUNS = r"(?:me|my|myself|we|us|our|ours|ourselves|we're|we've|we'll|we'd)"
_FIRST_PERSON_MINE = (
    r"(?:(?:\b(?:of|is|was|are|were|be|been|being|became|it's|that's)\s+mine\b)"
    r"|\bmine\s+own\b"
    r"|(?<!\w\s)\bmine\s+(?:is|was|are|were|will|would|shall|should|has|had)\b)"
)
BANNED = [
    ("the traveler", re.compile(r"\bthe\s+travell?er\b", re.I)),
    ("second person", re.compile(r"\b(?:you|your|yours|yourself|yourselves|you're|you've|you'll|you'd|thou|thee|thy)\b", re.I)),
    ("first person", re.compile(rf"\b{_FIRST_PERSON_PRONOUNS}\b|{_FIRST_PERSON_MINE}", re.I)),
    ("first person 'I'", re.compile(r"(?<![\w'])I(?:'m|'ve|'ll|'d)?(?![\w'])")),
]
# Apostrophes in the text may be straight or typographic.
_APOS = re.compile("[‘’]")


# ------------------------------------------------------------ Lua string scan
_LONG_COMMENT_OPEN = re.compile(r"--\[(=*)\[")
_LONG_STRING_OPEN = re.compile(r"\[(=*)\[")


def lua_strings(source: str):
    """Yield (line, key, text) for each string literal outside comments.

    ``key`` is the identifier the string is assigned to (``name = "..."``),
    or None for array items and concatenated pieces.
    """
    i, n, line = 0, len(source), 1
    last_key: str | None = None
    prefix = ""  # code since the last string/comma, used to find "key ="
    while i < n:
        c = source[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if source.startswith("--", i):
            m = _LONG_COMMENT_OPEN.match(source, i)
            if m:
                close = "]" + m.group(1) + "]"
                j = source.find(close, m.end())
                j = n if j < 0 else j + len(close)
            else:
                j = source.find("\n", i)
                j = n if j < 0 else j
            line += source.count("\n", i, j)
            i = j
            continue
        m = _LONG_STRING_OPEN.match(source, i)
        if c in "\"'" or m:
            start_line = line
            if m:
                close = "]" + m.group(1) + "]"
                j = source.find(close, m.end())
                j = n if j < 0 else j
                text, end = source[m.end():j], min(n, j + len(close))
            else:
                j = i + 1
                while j < n and source[j] != c:
                    j += 2 if source[j] == "\\" else 1
                text, end = source[i + 1:j], min(n, j + 1)
                text = re.sub(r"\\(.)", lambda mm: {"n": "\n", "t": "\t"}.get(mm.group(1), mm.group(1)), text)
            km = re.search(r"([A-Za-z_]\w*)\s*=\s*$", prefix)
            key = km.group(1) if km else (last_key if re.fullmatch(r"\s*\.\.\s*", prefix) else None)
            yield start_line, key, text
            last_key = key
            line += source.count("\n", i, end)
            i, prefix = end, ""
            continue
        prefix += c
        if c in ",{};":
            prefix = ""
            if c != ",":
                last_key = None
        i += 1


def violations_in(text: str) -> list[tuple[str, str]]:
    text = _APOS.sub("'", text)
    found = []
    for label, rx in BANNED:
        m = rx.search(text)
        if m:
            found.append((label, m.group(0)))
    return found


MIN_DATA_FRAGMENT = 4  # shorter data values could erase real words; do not strip them


def scan_source(source: str, only_keys: set[str] | None = None) -> list[tuple[int, str, str]]:
    """Return (line, label, match) violations in Lua ``source``.

    With ``only_keys`` only strings assigned to those keys are scanned, after
    removing every DATA_KEYS value in the same source (quest and NPC names
    copied into narration). Otherwise all strings except DATA_KEYS values are
    scanned.
    """
    strings = list(lua_strings(source))
    data_values: list[str] = []
    if only_keys is not None:
        data_values = sorted(
            {text for _line, key, text in strings
             if key in DATA_KEYS and len(text) >= MIN_DATA_FRAGMENT},
            key=len, reverse=True)
    out = []
    for line, key, text in strings:
        if only_keys is not None:
            if key not in only_keys:
                continue
            for value in data_values:
                text = text.replace(value, "")
        elif key in DATA_KEYS:
            continue
        out.extend((line, label, match) for label, match in violations_in(text))
    return out


def _narration_files() -> list[tuple[pathlib.Path, set[str] | None]]:
    """(path, keys) for every narration file. keys=None means all non-data keys."""
    files: list[tuple[pathlib.Path, set[str] | None]] = []
    if not ADDON.is_dir():
        return files
    for pattern in NARRATION_FILES:
        files.extend((path, None) for path in sorted(ADDON.glob(pattern)))
    for pattern in SUMMARY_FILES:
        files.extend((path, NARRATION_KEYS) for path in sorted(ADDON.glob(pattern)))
    return files


def _display(path: pathlib.Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.name


def _repo_violations() -> list[str]:
    files = _narration_files()
    if not files:
        return ["no narration files found under MainStoryGuide/ (expected Journal.lua, "
                "Journal_*.lua, WorldLore.lua, WorldLore_*.lua, Data_*.lua or ZoneSideQuests.lua)"]
    problems = []
    for path, keys in files:
        for line, label, match in scan_source(path.read_text(encoding="utf-8"), keys):
            problems.append(f"{_display(path)}:{line}: {label}: {match!r}")
    return problems


# ------------------------------------------------------------------- the guard
@pytest.mark.skipif(
    not _narration_files(),
    reason="no narration files under MainStoryGuide/ yet; runs once the Human baseline lands (BUILD-ORDER step 0.2)",
)
def test_repo_narration_has_no_banned_voice():
    problems = _repo_violations()
    assert not problems, "banned voice in narration:\n" + "\n".join(problems)


# ----------------------------------------------------------- self-tests (rules)
@pytest.mark.parametrize("text,label", [
    ("The traveler crossed the bridge.", "the traveler"),
    ("the Traveller rested.", "the traveler"),
    ("You step into Elwynn.", "second person"),
    ("Your first orders came from McBride.", "second person"),
    ("Follow yourself to the abbey.", "second person"),
    ("You’ll find kobolds.", "second person"),
    ("I saw the camp burn.", "first person 'I'"),
    ("I'm certain of it.", "first person 'I'"),
    ("My father fell at the bridge.", "first person"),
    ("We held the line.", "first person"),
    ("Help us, Stormwind.", "first person"),
    ("The victory is mine.", "first person"),
    ("A friend of mine fell.", "first person"),
])
def test_banned_voice_is_caught(text, label):
    assert label in [lbl for lbl, _ in violations_in(text)]


@pytest.mark.parametrize("text", [
    "Elwynn endured. The kobold camp fell silent, and the road stayed open.",
    "They say in Brill that the plague spread from the north.",
    "A traveler's cloak hung by the door.",   # only the phrase 'the traveler' is banned
    "The Defias thieves answered to Edwin VanCleef.",
    "Warcraft II ended with the Horde in internment camps.",
    "Words that merely contain pronouns pass: bus, focus, campus, mean, western, young.",
    "Echo Ridge Mine fell quiet after the kobolds were slain.",
    "The workers returned to the mine.",
])
def test_world_voice_passes(text):
    assert violations_in(text) == []


def test_data_keys_are_exempt_but_narration_is_not():
    src = '''
    -- you in a comment is ignored
    { id = 1, name = "Do You Know the Way?", giver = "Your Mother", summary = "Kobolds pressed the abbey." },
    { id = 2, name = "x", summary = "Your first orders came from McBride." },
    '''
    assert scan_source(src) == [(4, "second person", "Your")]
    assert scan_source(src, NARRATION_KEYS) == [(4, "second person", "Your")]


def test_lua_strings_handles_comments_long_strings_and_lines():
    src = '--[[ you\nyou ]]\nlocal a = [[We\nheld]] -- I said\nlocal b = "the traveler"\n'
    hits = [(line, text) for line, _k, text in lua_strings(src)]
    assert hits == [(3, "We\nheld"), (5, "the traveler")]


def test_embedded_quest_names_are_exempt_but_journal_narration_is_not():
    src = ('{ id = 1, name = "Shhh! We\'re Hunting Kobolds", '
           'journal = "A small page from Elwynn: Shhh! We\'re Hunting Kobolds, said the guard." }\n'
           '{ id = 2, name = "Side Work", body = "I did what Elmore asked." }\n')
    assert scan_source(src, NARRATION_KEYS) == [(2, "first person 'I'", "I")]


# ------------------------------------------------- regressions: vacuous pass, bare names
def test_empty_addon_fails_instead_of_passing(tmp_path, monkeypatch):
    monkeypatch.setattr(sys.modules[__name__], "ADDON", tmp_path)
    problems = _repo_violations()
    assert problems and "no narration files found" in problems[0]


def test_bare_journal_and_worldlore_are_scanned(tmp_path, monkeypatch):
    (tmp_path / "Journal.lua").write_text(
        '{ id = 1, text = "You step into Elwynn." }\n', encoding="utf-8")
    (tmp_path / "WorldLore.lua").write_text(
        '{ id = 1, text = "The traveler crossed the bridge." }\n', encoding="utf-8")
    monkeypatch.setattr(sys.modules[__name__], "ADDON", tmp_path)
    problems = _repo_violations()
    assert any("Journal.lua" in p and "second person" in p for p in problems)
    assert any("WorldLore.lua" in p and "the traveler" in p for p in problems)


# ------------------------------------------- WoW UI escapes in race journals
# A "|" starts a WoW UI escape (|c colour, |T texture, |H link). Generated
# Data_/Route_ files escape it in tools/gen_saga.py; the race journals are
# hand-written, so this guard stops one there (issue #14 security review).
# Journal.lua is UI code that uses escapes on purpose and is not scanned.
RACE_JOURNALS = "Journal_*.lua"


def ui_escapes_in(source: str) -> list[tuple[int, str]]:
    return [(line, text) for line, _k, text in lua_strings(source) if "|" in text]


def _race_journal_escapes() -> list[str]:
    files = sorted(ADDON.glob(RACE_JOURNALS))
    if not files:
        return [f"no {RACE_JOURNALS} files found under MainStoryGuide/"]
    return [f"{_display(path)}:{line}: UI escape in {text!r}"
            for path in files
            for line, text in ui_escapes_in(path.read_text(encoding="utf-8"))]


def test_race_journals_have_no_ui_escapes():
    assert _race_journal_escapes() == []


def test_ui_escape_in_a_journal_string_is_caught():
    src = ('-- a |comment| is not a string\n'
           '[1] = { title = "Plain", body = "A |cffff0000red|r word." },\n')
    assert ui_escapes_in(src) == [(2, "A |cffff0000red|r word.")]


def test_race_journal_guard_reads_the_real_files(tmp_path, monkeypatch):
    (tmp_path / "Journal_Test.lua").write_text('local E = { body = "Text |Hlink|h." }\n', encoding="utf-8")
    (tmp_path / "Journal.lua").write_text('local s = "|cff00ff00UI|r"\n', encoding="utf-8")
    monkeypatch.setattr(sys.modules[__name__], "ADDON", tmp_path)
    problems = _race_journal_escapes()
    assert len(problems) == 1 and "Journal_Test.lua:1" in problems[0]


def test_race_journal_guard_fails_without_files(tmp_path, monkeypatch):
    monkeypatch.setattr(sys.modules[__name__], "ADDON", tmp_path)
    assert _race_journal_escapes() != []
