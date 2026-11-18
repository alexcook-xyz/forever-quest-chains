# Data pipeline — Questie bulk, PandaBase verify

How `tools/` fits together. This page states the
source-trust order; this file gives the exact commands.

- **Questie = bulk source.** `tools/extract_questie.py` turns the pinned
  QuestieDB Forever data (`v1.0.16`, sha256-verified) into deterministic
  `facts.json`. Never hand-edit generated Lua — fix the extractor and
  regenerate.
- **PandaBase = Forever fallback.** The pinned QuestieDB has no Forever-only
  quests (IDs 9xxxx). `--pandabase-fallback` reads such an ID from its
  PandaBase quest page; the fact gets `"source": "pandabase"` and its points
  are PandaBase's recorded positions (issue #13).
- **PandaBase = verifier.** `tools/verify_pandabase.py` compares those
  facts to the Forever quest pages and reports
  `verified / mismatch / manual / not-found`. A `mismatch` means fix the
  extractor or investigate; `manual` means an in-game check is needed.
  Coordinates are never guessed; a missing NPC spawn yields an empty
  table, which is the manual-check signal.
- **RestedXP is cross-check only. Wowhead is advisory only.**

## The loop

```bash
pip install -r requirements-dev.txt
python -m pytest -q
python tools/extract_questie.py --download --ids 7,783 --out facts.json
python tools/verify_pandabase.py --facts facts.json
```

End-to-end shape for every race wave :
extract → verify → author Data/Route/Journal in world-focused third
person → playtest. For a race saga the extract and the Data/Route Lua go
through `tools/gen_saga.py` (below); only the journal is written by hand.

## `extract_questie.py`

```bash
# fetch + hash-verify the pinned DB into tools/.cache, then extract
python tools/extract_questie.py --download --ids 7,783 --out facts.json
# or: one race at a time (unrestricted "any race" quests are excluded)
python tools/extract_questie.py --race Human --out facts_human.json
# local files instead of the cache (tests use this path)
python tools/extract_questie.py --quest-db q.lua --npc-db n.lua --ids 7 --out -
```

Flags: `--ref` (default `v1.0.16`), `--download`, `--quest-db`,
`--npc-db`, `--ids`, `--race`, `--out` (`-` = stdout). Output is
byte-identical for identical input; missing IDs land in `missing`.
Tests: `tests/test_extract_questie.py`.

## `gen_saga.py` (race sagas)

```bash
python tools/gen_saga.py facts --all [--download]   # network: Questie cache + PandaBase pages
python tools/verify_pandabase.py --facts tools/sagas/dwarf.facts.json --accept tools/sagas/accepted_mismatches.json
python tools/gen_saga.py build --all                # offline and deterministic
python tools/genmanifest.py update
```

- `tools/sagas/<saga>.json` is the hand-written spec: chain IDs, names,
  summaries, quest order, kinds, notes, route order and route task text.
  It holds no names, levels or points; unknown keys fail the build.
- A quest with `"giverFrom": "pandabase"` takes its giver name and point
  from the PandaBase page instead of Questie. Use it only when Forever moved
  the start and the mismatch is in `accepted_mismatches.json` (issue #14:
  Teldrassil, 940, starts at the Oracle Tree Bark). The build fails when
  PandaBase has no located giver.
- `tools/sagas/<saga>.facts.json` is the facts snapshot (Questie facts,
  PandaBase fallback facts, and the parsed PandaBase page of every quest).
  `build` reads only the spec and the snapshot.
- `build` writes `MainStoryGuide/Data_<Saga>.lua` and `Route_<Saga>.lua`
  (with the generated marker) and `tools/sagas/<saga>.manual.json`: every
  giver or hand-in without a recorded point, for an in-game check. A run refuses
  to overwrite an existing file that lacks the generated marker.
- `chainsOnly` (issue #38): writes only `Data_<file>.lua` and needs `file`,
  taking no `route`, `routeExternal` or `routeTasks`. The route stays
  hand-written in `Route_<Saga>.lua`. `tools/sagas/human_diplomat.json`
  generates the Human chain `missing_diplomat` into
  `MainStoryGuide/Data_HumanDiplomat.lua`.
- `Sagas.lua` `RebuildView` orders every saga that has a route by route position,
  so own and shared chains appear in the order the route walks them (the Human
  order is northshire, elwynn, peoples_militia, defias_brotherhood, redridge,
  stockade, stalvan, duskwood_darkness, missing_diplomat, onyxia).
- `build` fails when a quest is not open to a race that walks the chain,
  when the route breaks a chain's order or skips a quest, when a
  class-gated quest is on the route, or when `extract_questie.ZONES` gives
  a zone another UiMapID than PandaBase.
- `Shared_Alliance.lua`, `Shared_Durotar.lua` and `Shared_Horde.lua` (hand-written) list the chains other sagas walk.
  The Alliance spine (issue #15) shares the Human chains from The Defias
  Brotherhood to Onyxia. `Shared_Durotar.lua` (issue #16) shares the Orc-owned
  Valley of Trials and Razor Hill chains with Troll. A race spec puts those quests in `routeExternal`
  and in `route`, in the owner's route order, so `facts` also snapshots them.
  `Shared_Horde.lua` (issue #18) shares the Orc-owned Horde spine
  (`tools/sagas/horde_spine.json`, a `chainsOnly` spec that writes
  `Data_HordeSpine.lua`: 53 chains from the Barrens to the Eastern Plaguelands, levels 17 to 60) with Troll,
  Tauren and Forsaken. Every Horde route ends its own quests with its anchor
  (Conscript of the Horde 840 for Orc and Troll, Journey to the Crossroads 854 for
  Tauren, Sample for Helbrim 1358 for Forsaken), then walks the same spine from
  Disrupt the Attacks (871). The spine specs list the spine in `routeExternal` and in `route`.
- Neutral chains (issue #19): `tools/sagas/neutral.json` is a `chainsOnly` spec with the saga key `Neutral`.
  The generator writes `race = "Neutral"` for each chain, so both factions see it (`Sagas.lua`
  `ChainGroup` returns neutral) and no race route holds it. It writes `Data_Neutral.lua`;
  `Journal_Neutral.lua` is hand-written. A neutral quest must have no race or class gate
  (`test_neutral_quests_are_open_to_both_factions`).
- Dungeon codas and reputations (issue #20): `tools/select_codas.py` reads the pinned QuestieDB cache and writes
  `tools/sagas/dungeons.json` and `reputations.json`, two `chainsOnly` specs with the saga key `Neutral`. Run it, then
  `gen_saga.py facts --workers 2 --spec ...` (repeat both until the quest set stops changing, because `order` reads the PandaBase
  prerequisites from the facts snapshot), then `build`, then `python tools/write_coda_journals.py` (the journals are generated; `--check` fails when one is out of date). Rules are in the script header: a dungeon quest has a leveling-dungeon
  `zoneOrSort`, no class gate, is not repeatable and is in no other spec; quests it needs are added when they qualify. A chain
  key `faction` (`Alliance` or `Horde`) limits a chain to one faction; `walkers` then names that faction's saga keys for the
  open-to-race check. A quest that Forever gates differently (`FOREVER_CONFLICT`) or has no giver name (`NO_GIVER`) stays out,
  with every quest that needs it. A PandaBase placeholder zone (`Referenced ...`, `Synthetic ...`) is never a zone.
  PandaBase returns HTTP 503 under 8 parallel requests; run a large `facts` run with `--workers 2`.
- Chain order by prerequisite (issue #74): a chain key `after` is a list of chain IDs that must come before this chain
  in a saga view, because a quest of this chain needs a quest of each of them (Questie or PandaBase). Set it in the spec
  chain, for example `"after": ["raid_blackwing_lair"]`. `gen_saga.py` checks the form (a list of other chain IDs, each
  once) and writes `after = { ... }` into `Data_<file>.lua`. For the coda specs (`dungeons`, `raids`, `zg_aq`) the selector
  sets it: add the chain to `AFTER` in `tools/select_codas.py`, run the selector and `build`. `tests/test_select_codas.py` fails when a committed spec differs from `AFTER`.
  `ns.RebuildView` orders the other neutral chains (dungeons, reputations, raids, Naxxramas) with it: each chain waits for the
  chains of its list that the view holds and ignores the others (an Alliance-only chain in a Horde view). A chain that no
  list touches keeps its registration order. A cycle never hangs the view: the first chain left goes next. The route
  chains and the three neutral main chains keep the level order of issue #57, and `after` does not move them.
  `tests/test_race_sagas.py` checks that each entry names a chain and a quest that needs it, and that
  `KNOWN_ORDER_CONFLICTS` is empty. `after` cannot solve a story line that crosses two chains in both directions.
  The Ras Frostwhisper line did this (5384 Scholomance, 5461 to 5463 Stratholme, 5464 to 5466 Scholomance), so
  `MOVED_TO_ZONE` in `select_codas.py` holds 5461 to 5463 in the Scholomance chain.
- Class chains (issue #41): a chain key `classSpecific: true` marks a class chain, for example the Sigil quests of one class.
  `gen_saga.py` writes `classSpecific = true` into the chain in `Data_<file>.lua`. Each quest of such a chain needs a class
  gate in the facts (Questie `requiredClasses` or PandaBase): the generator writes it as `class = "WARRIOR"` (a list reads
  `class = "PALADIN, WARRIOR"`) and stops with a `SpecError` when a quest has none. No class quest may be on the `route`;
  `check_route()` stops it. In the game, `ns.IsChainIncluded` and `ns.IsQuestIncluded` show the chain only to a player of
  that class (`ns.PlayerClass()`, the `UnitClass` token). A player of another class, or a client where `UnitClass` gives no
  value, sees neither the chain nor its quests. The chain follows the race rules of a main chain (`race`, `faction`, a
  shared entry) and is a side group: it sits after the main chains, `ns.GetActive` never picks it, and the journal heading
  reads `Class Chapter`. A class quest outside a class chain stays hidden for every class, and the chain ID `skyborne_class`
  stays blocked. Tests: `tests/test_class_chains.py`, `tests/test_gen_saga.py`.
- Raid quests (issue #22): `tools/select_raids.py` writes `tools/sagas/raids.json`, a `chainsOnly` Neutral spec with one chain for Molten Core (plus the Duke Hydraxis quests after 6821) and one for Blackwing Lair. Onyxia's Lair has no chain: its attunement is in the spines and its other quest is repeatable. Run it, then `gen_saga.py facts --workers 2 --spec tools/sagas/raids.json`, run it again, then `verify_pandabase.py`, `build`, `write_coda_journals.py` and `genmanifest.py update`. Zul'Gurub, Ahn'Qiraj and Naxxramas are issues 5.2 and 5.3.
- Zul'Gurub and Ahn'Qiraj (issue #23): `tools/select_zg_aq.py` writes `tools/sagas/zg_aq.json`, a `chainsOnly` Neutral spec with the chains `zul_gurub`,
  `zandalar_tribe` and `ahn_qiraj` (rules in the script header; split by faction like the dungeons). Run it, then
  `gen_saga.py facts --workers 2 --spec tools/sagas/zg_aq.json` (repeat both until the quest set stops changing), `verify_pandabase.py`, `build`,
  `write_coda_journals.py` (writes `Journal_ZGAQ.lua`) and `genmanifest.py update`. A quest in the `raids` spec (issue #22) is never taken here.
- Naxxramas and Plaguelands (issue #24): `tools/select_naxx.py` writes `tools/sagas/naxx.json`, a `chainsOnly` Neutral spec with the chains `naxxramas` and
  `plaguelands_endgame` (Questie zone 3456, and zones 28 and 139 at a required level of 55 or more; split by faction like the dungeons; rules in the script header).
  Run it, then `gen_saga.py facts --workers 2 --spec tools/sagas/naxx.json` (repeat both until the quest set stops changing), `verify_pandabase.py`, `build`,
  `write_coda_journals.py` (writes `Journal_Naxx.lua`, whose `naxxramas` epilogue closes the endgame spine) and `genmanifest.py update`.
  A quest that an earlier spec holds is never taken here; a side list that holds a taken quest loses it (MAIN wins).
  The spec key `pandabaseFacts` (issue #69) lists quest IDs whose facts `gen_saga.py facts` takes from the PandaBase page, because Questie gives no class gate. `naxx.json` lists the 12 armor-token quests 9234 to 9246 there. The selector reads their pages from `naxx.facts.json` and does no network call.
- The Forsaken saga key is `Scourge`, the `UnitRace` token, so its files are
  `Data_Scourge.lua`, `Route_Scourge.lua` and `Journal_Scourge.lua`, and its spec is
  `tools/sagas/scourge.json`. `gen_saga.RACE_LABELS` maps the saga key to the race name in
  the data (`Scourge` to `Undead`, `NightElf` to `Night Elf`) for the open-to-race check.
- `routeTasks` (issue #43) gives a saga its own task text for a
  `routeExternal` quest: `{"65": "Leave Menethil Harbor ..."}`. `build`
  writes it to `ns.RouteInfoBySaga[saga]` in `Route_<Saga>.lua`, and
  `ns.RouteInfoOf` (`Sagas.lua`) puts it over the owner's `ns.RouteInfo`
  entry for that saga only. A key that is not a `routeExternal` quest on the
  route fails the build, and so does an unknown top-level spec key.
- Tests: `tests/test_gen_saga.py` (also rebuilds the committed sagas and
  compares), `tests/test_race_sagas.py` (Dwarf, Gnome, Night Elf, Orc, Troll, Tauren and Forsaken:
  route prerequisites from both sources, class audit, race, isolation, journal
  coverage).
- Forever-only quests: the PandaBase zone map pages
  (`https://pd.zroot.it/forever/map/kalimdor/<zone>`) list them; the quest
  list filter ignores the zone. Issue #14 took the Night Elf ones from the
  Teldrassil, Darnassus, Darkshore and Ashenvale pages. Issue #17 took the
  Tauren ones from the Mulgore page. Issue #18 took the Forsaken ones from the
  Tirisfal Glades and Silverpine Forest pages (`eastern-kingdoms/<zone>`); there is no
  Deathknell page.

## Zone side catalogues and the Forever audit (issue #21)

`MainStoryGuide/ZoneSideQuests.lua` is generated from `tools/sagas/side_zones.json`
(key `sideZones`, no saga) and its snapshot `tools/sagas/side_zones.facts.json`:

```bash
python tools/gen_saga.py facts --spec tools/sagas/side_zones.json    # network
python tools/verify_pandabase.py --facts tools/sagas/side_zones.facts.json --accept tools/sagas/accepted_mismatches.json
python tools/gen_saga.py build --spec tools/sagas/side_zones.json    # offline
python tools/genmanifest.py update
python tools/audit_forever.py check                                  # offline
```

- A list holds the quests of one zone that no MAIN chain holds and no class gates: the Questie
  quests of the zone plus the quest givers of the PandaBase zone map page (the Forever-only
  quests). The spec lists them in order. `build` fails for a MAIN quest, a class quest (in
  Questie or PandaBase), a quest in two lists, and a prerequisite that comes after its quest.
  When a MAIN chain takes a side quest later, remove it from the spec and rebuild.
- `requires` follows Questie: all of a group and the single prerequisite, when a list or a MAIN
  chain holds it. A prerequisite outside every list and an "any one of these" set go to
  `outsidePrereqs` and `anyOfPrereqs` in `side_zones.manual.json`, not into the Lua.
  `faction` is set when every race of the quest is on one side (Questie, else PandaBase).
  Core.lua shows a row with a faction only to that faction (`ns.ZoneCatalog`).
- A giver or hand-in without a recorded point has no x/y and is in the manual list. Nothing is guessed.
- A side row never blocks a MAIN quest: the catalogue is a separate list, and a MAIN quest wins a tie.
- Zones are added by editing the spec (and `extract_questie.ZONES` when a zone is new); the first
  wave is Burning Steppes, Dustwallow Marsh and Winterspring.
- `tools/audit_forever.py` checks `tools/sagas/forever_audit.json`: each Forever-only quest on the
  PandaBase map page of an audited zone, and each Forever-only quest in a facts snapshot, is in a
  MAIN chain, in a side list, or excluded with a reason. `fetch` rereads the map pages (network);
  `check` is offline and runs in `tests/test_side_zones.py`.
- `verify_pandabase.fetch_page` waits and retries on HTTP 429, 502, 503 and 504 (2, 5 and 10 seconds).

## `verify_pandabase.py`

```bash
python tools/verify_pandabase.py --facts facts.json
python tools/verify_pandabase.py --facts facts.json --strict --out report.json
```

Flags: `--facts` (required), `--ids`, `--tolerance` (default 0.25 map
units), `--delay`, `--strict` (also fail on `manual` / `not-found`),
`--out`, `--accept` (JSON list of investigated mismatches, each
`{id, field, reason, questie, pandabase}`; a mismatch with exactly those
values shows as `accepted` and does not fail, and any other value in that
field is a new mismatch). Exit 1 on
any `mismatch` (or any unverifiable result with `--strict`). Compared
fields: name, levels, races, classes (class audit), prerequisites, and
the numbers in the objective text (`counts`, issue #53), and giver/hand-in names and points. PandaBase's off-map point (-0.010) means
"unknown", never a coordinate. No project-imposed request cap or throttle.
Tests: `tests/test_verify_pandabase.py`.

## Guards (CI)

- **Changelog guard** — `tools/changelog_guard.py` fails when a change
  touches `MainStoryGuide/`, `tools/` or `tests/` without a new line
  under `## [Unreleased]` in `CHANGELOG.md`:
  `python tools/changelog_guard.py --base origin/main`.
  Tests: `tests/test_changelog_guard.py`.
- **Generated data** — `tools/genmanifest.py check` fails when a Lua
  file marked `-- GENERATED by tools/...` is unregistered, missing or
  differs from `tools/generated.manifest.json`. After changing the
  extractor and regenerating, run `python tools/genmanifest.py update`.
  The Dwarf, Gnome, Night Elf, Orc, Troll, Tauren and Forsaken Data/Route files, the Human Diplomat Data file (`Data_HumanDiplomat.lua`) and the Horde spine Data file (`Data_HordeSpine.lua`) are generated Lua. CI job `generated-data`; tests in
  `tests/test_release_guards.py`. `python tools/release.py check` runs it too.
- **Public art guard** — `python tools/release.py check --public` exits 1
  while third-party art is in the repo. This repo carries none. Tests:
  `tests/test_release_guards.py`.
- **Story voice** — `tests/test_story_voice.py` bans first person,
  second person and "the traveler" in narration (quest/NPC/zone names
  are data and are not scanned). Run with the suite:
  `python -m pytest -q` or `python -m pytest -q tests/test_story_voice.py`.
- **Lua** — `luacheck MainStoryGuide --config .luacheckrc` (CI job
  `luacheck`).

Full CI matrix lives in `.github/workflows/ci.yml`
(`luacheck`, `pytest`, `voice`, `generated-data`, `changelog`, `installer-smoke`).
