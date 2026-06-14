# Changelog

All notable changes to Zenith are documented here.

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
