# Changelog

All notable changes to Zenith are documented here.

## [1.1.0] — 2026-06-15

New features (toward "better than RestedXP + Questie"):

### Added
- **Leveling tracker + Stats tab**: per-level time splits, total active played time,
  and a live "ETA to next ding" from your current XP rate.
- **Live objective progress** in the Guide: while a quest is in your log, the current
  step shows its objectives with live x/y counts (green when finished), refreshing on
  quest-log changes.

## [1.0.2] — 2026-06-15

More in-game fixes.

### Fixed
- **Wrong race routing.** The race bitmask used incorrect bit values (Blizzard's
  `requiredRaces` are Human 1, Orc 2, Dwarf 4, NightElf 8, Undead 16, Tauren 32,
  Gnome 64, Troll 128, BloodElf 512, Draenei 1024), so quests carrying Questie's real
  race data were misfiltered — e.g. a Draenei could be routed through Dun Morogh.
  Corrected in both the importer and runtime, and the route was regenerated. Each race
  now starts in its own zone (Draenei→Azuremyst/Bloodmyst, Dwarf/Gnome→Dun Morogh, etc.),
  and cross-faction quests no longer leak between the Alliance/Horde routes.
- **Cursor stuck on a "Travel to X" header.** Zone headers now grey-skip by level like
  quests, so an out-leveled header no longer parks the cursor.

## [1.0.1] — 2026-06-15

Fixes from in-game testing on a modern client.

### Fixed
- **Cursor now tracks where you actually are.** It used to only move forward, so a
  stale/ahead position (or a high-level quest sorted into a low-level zone, e.g. the
  Dustwallow dragon quests) could leave you parked at 58–60 content while leveling at 40.
  The cursor now re-anchors on login, level-up, zone change, and turn-in — pulling back
  to the first quest you can actually do at your level. This also fixes the **missing
  arrow** (it was pointing at a far-away zone).
- **Skip now persists** so skipped quests don't reappear when the cursor re-anchors.
- **Version display** (and other metadata) now read via `C_AddOns.GetAddOnMetadata` on
  modern clients — fixes the title showing "v0.1.0".
- **Rotation helper** degrades gracefully (no per-frame errors) if the client's spell
  APIs aren't the expected globals.

## [1.0.0] — 2026-06-15

First public release. Uploads to Wago succeed; this fixes the release workflow's
GitHub-release step.

### Fixed
- Release workflow: grant the job `permissions: contents: write` so the BigWigs
  packager can create/attach the GitHub release for the tag (the default read-only
  `GITHUB_TOKEN` returned 403 "Resource not accessible by integration"). The Wago
  upload itself already succeeded.

## [0.8.0] — 2026-06-15

### Added
- **Batch "questing loop" waypoint**: the arrow now groups the nearby quests around
  your position into one hub batch and walks you through it the way you actually quest —
  **accept everything nearby → do all the objectives → loop back and turn them all in** —
  always heading to the nearest one in the current phase. Re-plans on quest-log changes
  and a few times a second so it tracks your movement. (`StepEngine:NextWaypoint`.)

## [0.7.0] — 2026-06-15

### Added
- **Three-stage waypoint progression** per quest: the arrow points at the **giver**
  until you accept, the **objective area** while you're working it, then the **turn-in
  NPC** once objectives are complete. Objective coordinates come from Questie's objective
  data (mob/object spawns and exploration triggers).

### Changed (packaging — now Wago-publishable)
- **Restructured the addon to the repo root** (`Zenith.toc` at root) so the BigWigs
  packager finds it — required for CurseForge/Wago/WoWInterface uploads. Updated
  `.pkgmeta`, the importer output path, and install docs accordingly.

## [0.6.0] — 2026-06-14

Ship-readiness sweep.

### Added
- **Turn-in waypointing**: each quest step now also stores the turn-in location
  (from Questie's `finishedBy`); the arrow points at the giver while you work the
  quest and **flips to the turn-in NPC** the moment its objectives are complete.
- First-login **welcome line** with the next zone + a `/zen help` command listing.
- Neutral minimap map icon (was a Hunter-specific icon).
- Install note for the "Load out of date AddOns" toggle.

### Changed / Fixed
- `SetTarget` no-ops when the destination is unchanged, so the new per-quest-update
  arrow refresh doesn't churn TomTom pins.

## [0.5.0] — 2026-06-14

Reliability & polish pass (informed by a full code review).

### Added
- **Reliable, locale-independent completion**: quest steps carry the Blizzard quest id
  and use `IsQuestFlaggedCompleted`, so the route correctly auto-skips quests you finished
  *before* installing — no more getting stuck on already-done quests.
- **Grey-quest auto-skip**: quests far below your level are skipped automatically
  (toggleable in options) so a mid-level character isn't sent backwards.
- **Travel headers** auto-clear on zone arrival; the **arrow looks ahead** to the next
  objective when the current step is a coordinate-less header.
- "Route complete" end state.

### Fixed
- **End-of-route infinite loop**: the 1-second poll no longer re-fires completion events
  forever after the last step; the cursor parks in a terminal state.
- **Completion keys** are now keyed by quest id (not array position), so they survive
  route-data updates instead of pointing at the wrong quest.
- Color codes round RGB to integers (Lua 5.1 `%x` wants integers).
- Login-timing **resync** so the first auto-skip pass runs once quest data is available.
- Defensive nil-guards across the gear/pets/rotation panes.
- Importer: escape control chars in emitted strings; validate spawn coordinate pairs.

## [0.4.1] — 2026-06-14

### Changed
- **Hub-cluster route ordering**: within each zone, quests are grouped into hubs by
  giver proximity and visited via a level-banded nearest-neighbour tour, so you do
  nearby quests together instead of criss-crossing by quest level. Average step-to-step
  in-zone hop dropped to ~7.5 map-units. (Importer: `clusterOrder`.)

## [0.4.0] — 2026-06-14

### Added
- **Comprehensive quest route, all zones 1–70** — generated from the open **Questie**
  TBC database via `tools/import_questie.lua`: ~3,600 quest steps per faction with real
  quest names, objective text, **correct Classic uiMapIDs**, real giver coordinates, and
  per-quest race masks. Ordered Elwynn → … → Shadowmoon Valley.
- **Per-race routing**: each character sees its own starting chain (racial start zones are
  owner-tagged) plus the shared faction path; quests are race-filtered at runtime.
- Wago project id wired in (`X-Wago-ID`).

### Changed
- The generated quest route is now the primary route. Retired the hand-authored
  fallback files (`Leveling.lua`, `Detailed_Alliance.lua`) — they used *retail* map IDs,
  which are wrong on TBC Classic; the generated data uses the correct Classic IDs.

### Credits
- Quest/coordinate data derived from the **[Questie](https://github.com/Questie/Questie)**
  project's open database (community-maintained game data). See README.

## [0.3.0] — 2026-06-14

### Added
- **Quest-by-quest engine**: steps can be individual quests with per-quest waypoints
  and automatic accept / objective / turn-in detection (tracked by quest title, so no
  hard-coded IDs). `complete.level` fallbacks keep the list moving if a title/locale
  doesn't match.
- **Turn-by-turn route for Human 1–15** (Northshire → Elwynn → Westfall) as the worked
  vertical slice on the new engine — the template other zones/races fill in against.
- **TomTom integration**: if TomTom is installed, Zenith drives its world/minimap pins
  (toggle via `useTomTom`). Built-in arrow still works without it.

### Fixed
- Race detection (`UnitRace`) was truncated by an `and`, so race-specific starts never
  loaded. Now every race's intro (and detailed route) loads correctly.

## [0.2.0] — 2026-06-14

### Added
- **All 9 classes** now have a leveling talent path + rotation helper:
  Warrior (Arms), Paladin (Retribution), Hunter (Beast Mastery), Rogue (Combat),
  Priest (Shadow), Shaman (Enhancement), Mage (Frost), Warlock (Demonology/Felguard),
  Druid (Feral). Each researched from Wowhead / Icy-Veins / Warcraft Tavern / wowtbc.gg.
- **Class-agnostic route** that works for **every race and both factions** — accurate
  per-race starting zones (Human, Dwarf, Gnome, Night Elf, Draenei, Orc, Troll, Tauren,
  Undead, Blood Elf) stitched onto the shared Alliance/Horde leveling spine.
- Generic per-class **gear stat-priority + armor-type** guidance (Plate-at-40, Mail-at-40,
  stack-Agility, etc.) so the Gear tab is useful for every class.
- Execute-aware rotation suggestions (uses target health) and graceful rendering for
  classes without aspects/pets.
- Release infrastructure: MIT license, this changelog, `.pkgmeta`, and a BigWigs-packager
  GitHub Actions workflow for CurseForge / Wago / WoWInterface releases.

### Changed
- Talent paths are now authored compactly via `U.TalentPath` (grouped → per-point).
- Route data moved from class-keyed to faction-keyed + race intros.

## [0.1.0] — 2026-06-14

### Added
- Initial release: step engine, waypoint arrow, talent coach, gear advisor, rotation
  helper, tabbed UI, and minimap button. Flagship class: Beast Mastery Hunter
  (full route, talents, gear milestones, pre-raid BiS, pets, rotation).

[0.2.0]: https://github.com/Camperistic/Zenith/releases/tag/v0.2.0
[0.1.0]: https://github.com/Camperistic/Zenith/releases/tag/v0.1.0
