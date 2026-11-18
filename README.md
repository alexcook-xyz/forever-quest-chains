# Forever Quest Chains

[![CI](https://github.com/alexcook-xyz/forever-quest-chains/actions/workflows/ci.yml/badge.svg)](https://github.com/alexcook-xyz/forever-quest-chains/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
![Status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)

A simple, selectable quest-chain list for **WoW Forever**. One small window shows
every storyline as a collapsible list of its quests, so you can see what is done,
what is next, and work through a whole zone at a time.

> **Alpha.** The addon is usable but still being tested in game. Quest data
> coverage differs by race and storyline. Please report anything that looks wrong.

## Features

- **Storyline list.** Each storyline is a row with its recommended level range and
  a `done / total` count. Click a row to open its quest chain.
- **Quest chains.** A check mark for completed quests, an arrow for the current
  one, and a gold *Tracked* label for quests in your objective tracker.
- **Zones view.** The **Zones** button lists every zone with its story quests and
  side quests, so you can finish a whole zone in one trip. Quest rows show the
  required level and your progress.
- **Right-click menu** on any quest:
  - Follow or unfollow the storyline
  - Set or remove a waypoint on the quest giver (or the turn-in NPC once the quest
    is in your log), named after the quest
  - Track or untrack the quest
  - Jump to the quest's zone
  - Mark a quest done or undo the mark
- **Saga picker.** Switch between the race storylines that have data loaded.
- **Waypoints.** Uses [Waypoint UI](https://www.curseforge.com/wow/addons/waypoint-ui)
  for an in-world pin when it is installed, and the native map pin otherwise.

Open the window with `/story`, the minimap book, or the quest-log book button.
Settings are in the game's Interface Options.

## Install

### CurseForge or an addon manager

Search for **Forever Quest Chains** and install it as usual. *(Listing coming soon.)*

### Manual

1. Download the latest zip from the
   [Releases](https://github.com/alexcook-xyz/forever-quest-chains/releases) page.
2. Extract it so that the folder `MainStoryGuide` sits in
   `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game and type `/story`.

The folder is called `MainStoryGuide` on purpose: that is the name your saved
progress is stored under, so updates keep it.

### From source (Windows)

```powershell
git clone https://github.com/alexcook-xyz/forever-quest-chains
cd forever-quest-chains
powershell -ExecutionPolicy Bypass -File .\Install-Or-Update-MainStoryGuide.ps1 `
  -TargetDir "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
```

The installer copies the addon folder only and never touches your saved variables.

## Where the data comes from

Quest data is extracted by the scripts in [`tools/`](tools/) and checked against
a second source. See [docs/DATA-PIPELINE.md](docs/DATA-PIPELINE.md) for the exact
pipeline.

- [Questie](https://github.com/Questie/Questie) is the bulk source for quest data.
- PandaBase verifies facts and supplies Forever-only quests that Questie lacks.
- Coordinates are never guessed: a missing location means no waypoint until it is
  checked in game.

## Development

```bash
pip install -r requirements-dev.txt
python -m pytest -q
luacheck MainStoryGuide --config .luacheckrc   # if luacheck is installed
python tools/package.py                         # builds dist/ForeverQuestChains-<version>.zip
```

Generated Lua (`Data_*.lua`, `Route_*.lua`) is never edited by hand; fix the
extractor and regenerate. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

- [Questie](https://github.com/Questie/Questie) for the quest database.
- [Waypoint UI](https://github.com/Adaptvx/Waypoint-UI) by Adaptvx for in-world
  waypoints (optional, separate download).
- Blizzard Entertainment for World of Warcraft. This project is not affiliated
  with or endorsed by Blizzard Entertainment.

## License

[GPL-3.0-or-later](LICENSE). The quest data is derived from Questie, which is
GPL-3.0 licensed, so this project is released under the same licence.
