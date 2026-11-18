# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Side Quests view (`Side Quests` button, issue #2): each zone is a collapsible row
  with its level range and a `done / total` count. Side quests sit in chains that
  follow `requires`; a quest with no link is a single entry. Open a chain to see
  its quests in order with a check mark for done, an arrow for the current quest
  and a gold `Tracked` label. The right-click menu follows or unfollows the chain,
  sets or removes a waypoint, tracks or untracks, shows the zone and marks a quest
  done or undoes the mark. Quests of the other faction stay hidden.
- Elwynn Forest side quests (`tools/sagas/side_zones.json`), from Questie and
  PandaBase through the pipeline. Quest 91741 has no recorded giver point and is on
  the manual in-game check list. Quest 46 follows Questie, which lacks the prerequisite
  that PandaBase gives (accepted mismatch).

- Public repository set up: GPL-3.0 licence, README, contributing guide, release
  workflow, `tools/package.py` (builds the CurseForge and GitHub release zip) and
  the CurseForge project text in `CURSEFORGE.md`. Waypoint UI is an optional,
  separate download and is no longer bundled or installed by the installer.

## [0.1.0-alpha]

First alpha of the simple list window.

### Added

- One small window in the style of All The Things, opened with `/story`, the
  minimap book or the quest-log book button.
- Storyline list: each storyline shows its recommended level range and a
  `done / total` count, and opens into its quest chain with check marks for
  completed quests and an arrow on the current one.
- Zones view (`Zones` button): every zone with its story and side quests, level
  ranges, progress, and a menu per quest.
- Right-click menu on quests: follow or unfollow the storyline, set or remove a
  waypoint named after the quest (turn-in NPC while the quest is in the log,
  else the giver; no pin without recorded coordinates), track or untrack the
  quest, show the quest's zone, mark done or undo.
- Quests in the objective tracker show a gold `Tracked` label and a highlight.
- Saga picker for the race storylines that have data loaded.

### Changed

- Replaces the Map & Quest Log style window of the full Saga Guide with the
  list above. The quest data, route engine and generators are unchanged.
- Display name is **Forever Quest Chains**. The addon folder, `.toc` file and
  saved variables keep the name `MainStoryGuide`, so existing progress carries
  over.

Not tested yet: look and behaviour in game.
