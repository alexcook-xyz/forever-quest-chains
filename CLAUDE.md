# Forever Quest Chains — working rules

This repo has one UI only: the simple list in `MainStoryGuide/HubMap.lua`. Do not
restore the Map & Quest Log reader, Journal tabs or navigation bar.
The addon folder, `.toc` and SavedVariables stay `MainStoryGuide`.

## Workflow

- Branch per change (`feat/<name>`, `fix/<name>`), pull request, CI green,
  CHANGELOG `[Unreleased]` entry.
- CI jobs: `luacheck`, `pytest`, `voice`, `generated-data`, `changelog`,
  `installer-smoke`.
- Local checks: `python -m pytest -q`; `luacheck MainStoryGuide --config .luacheckrc`
  if installed.
- Release steps: `docs/RELEASING.md`.

## Data

- Questie (QuestieDB, pinned) is the bulk source: `python tools/extract_questie.py --download --ids ...`.
- PandaBase is the verifier: `python tools/verify_pandabase.py --facts facts.json`.
  It is also the source for Forever-only quest IDs that Questie lacks (`--pandabase-fallback`).
- Race sagas: `python tools/gen_saga.py build --all` generates Data_/Route_ Lua from `tools/sagas/`.
- Never hand-edit generated Lua; fix the extractor and regenerate.
- Never guess coordinates. Missing data means a manual in-game check.
- Facts only from Questie/PandaBase; no invented events or motives.
- Pipeline, guard commands and exit codes: `docs/DATA-PIPELINE.md`.

## Voice (enforced by `tests/test_story_voice.py`)

Close third-person, world-focused narrator. No "you"/"your", no first person,
no "the traveler". Past tense for completed deeds, present for standing facts.
Quest, NPC and zone names are data and are not scanned.
