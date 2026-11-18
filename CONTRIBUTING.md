# Contributing

Thanks for helping. Bug reports from real play are the most useful thing here.

## Report a problem

Open an [issue](https://github.com/alexcook-xyz/forever-quest-chains/issues/new/choose)
and include the character race and level, the zone, the quest ID if you know it,
and what the window showed. A screenshot of the list helps.

## Change the code

1. Fork the repo and create a branch: `feat/<short-name>` or `fix/<short-name>`.
2. Make one focused change. Keep the window itself simple; it is one list, not a
   multi-panel interface.
3. Run the checks:
   ```bash
   pip install -r requirements-dev.txt
   python -m pytest -q
   luacheck MainStoryGuide --config .luacheckrc   # if installed
   ```
4. Add a line under `## [Unreleased]` in `CHANGELOG.md`. CI fails a pull request
   that changes `MainStoryGuide/`, `tools/` or `tests/` without one.
5. Open a pull request. CI runs `luacheck`, `pytest`, `voice`, `generated-data`,
   `changelog` and `installer-smoke`.

## Data rules

- Quest data comes from Questie and is verified against PandaBase; see
  [docs/DATA-PIPELINE.md](docs/DATA-PIPELINE.md).
- **Never hand-edit generated Lua** (`Data_*.lua`, `Route_*.lua`). Fix the
  extractor or the saga spec in `tools/sagas/` and regenerate with
  `python tools/gen_saga.py build --all`.
- **Never guess coordinates.** A missing location means a manual in-game check.
- Story text is written in a close third-person, world-focused narrator voice
  (no "you", no first person), enforced by `tests/test_story_voice.py`.

## Licence

By contributing you agree that your work is released under the
[GPL-3.0-or-later](LICENSE) licence of this project.
