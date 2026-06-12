# TalentMate

A class-aware **talent build library and auto-applier** for WoW **Burning Crusade Classic (2.5.x / Anniversary)**.

Open the picker, choose the spec for what you're doing — raiding, dungeons, arena, or leveling — and TalentMate **spends your talent points for you**, one at a time, in a valid order.

## Features

- **57 curated builds** across all 9 classes (6–7 each), covering PvE (raid DPS / tank / healer / dungeon) and PvP (arena / BG), each with a use-case description so you know when to pick it. Every build is verified to a legal 61-point spec.
- **Guided leveling (10–70):** each class has an optimized, level-by-level pick order. It's level-aware — it only spends the points you currently have, so just re-apply each time you ding.
- **Settings window:** a dropdown of your class's builds with use-case blurbs, plus Apply / Preview. Open it with `/tm` or the **TalentMate** button beneath the talent frame.
- **Dual-spec aware:** targets the spec shown in your talent window (works the same sub-40 with a single spec).
- **Safe:** every apply asks for confirmation (talent spending is irreversible without a gold respec), is blocked in combat, and only ever spends your *unspent* points.

## Install

1. Download this folder (`TalentMate`) and place it in your AddOns directory:
   `World of Warcraft\_anniversary_\Interface\AddOns\TalentMate\`
   (the folder must contain `TalentMate.toc` and `TalentMate.lua`)
2. Restart WoW or `/reload`.

## Usage

| Command | What it does |
|---|---|
| `/tm` | open the build picker window |
| `/tm list` | list every build for your class in chat |
| `/tm pve` / `/tm pvp` / `/tm level` | quick-apply the first build of that type |
| `/tm show pve` / `/tm show pvp` | preview a build without spending |
| `/tm stop` | cancel an in-progress apply |

You can also click the **TalentMate** button under Blizzard's talent window.

## Notes

- Spending talents is irreversible without a gold respec — TalentMate always confirms first.
- It spends **unspent** points only. To set up your other dual-spec, switch to it (so it's the active spec) first.
- Assumes an English client (talents are matched by name; it warns if a name doesn't match).

*Built with [Claude Code](https://claude.com/claude-code).*
