# CurseForge project text

Copy these into the CurseForge project form. Nothing else in this file is shipped
in the addon zip.

## Project name

Forever Quest Chains

## Summary (one line)

A simple, selectable quest-chain and zone quest list for WoW Forever, with waypoints and quest tracking.

## Categories

Quests & Leveling; Map & Minimap

## Main file

Upload the zip built by `python tools/package.py` (or the zip attached to the
GitHub release). Its single top-level folder is `MainStoryGuide`. Mark the first
upload as **Alpha**.

## Description

**Forever Quest Chains** is a clean quest list for WoW Forever. It shows every
storyline as a collapsible chain of quests, so you can see what is done, what is
next, and finish a whole zone in one trip.

### Features

- **Storyline list** with a recommended level range and a `done / total` count
  for each storyline.
- **Quest chains** with a check mark for completed quests, an arrow for the
  current one, and a gold *Tracked* label for quests in your objective tracker.
- **Zones view**: press the **Zones** button to list every zone with its story
  quests and side quests, with levels and progress.
- **Right-click menu** on any quest: follow or unfollow the storyline, set or
  remove a waypoint on the quest giver (named after the quest), track or untrack
  the quest, jump to the quest's zone, mark done.
- **Saga picker** for the race storylines that have data loaded.
- Optional in-world waypoints through **Waypoint UI**; the native map pin is used
  when it is not installed.

### How to use

Type `/story`, or click the minimap book or the quest-log book button.
Click a storyline to open it. Right-click a quest for the menu.

### Notes

- This is an **alpha**. Quest data coverage differs by race and storyline.
- Quest data is derived from Questie and verified against PandaBase. Locations
  are never guessed: a quest without a recorded location has no waypoint.
- Your progress is stored in the `MainStoryGuide` saved variables.

### Links

- Source and issues: https://github.com/alexcook-xyz/forever-quest-chains
- Licence: GPL-3.0-or-later

## Release notes (0.1.0-alpha)

First alpha: storyline list with level ranges, quest chains, zones view, quest
menu with waypoints and tracking, saga picker.
