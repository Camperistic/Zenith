# Zenith

**The one addon a leveler runs from 1 to cap.** A unified leveling coach — curated
route + the full quest world + live talent/rotation/gear coaching + leveling stats —
in a single addon, built on one shared state model so every subsystem reacts together.

> ⚠️ **2.x is a ground-up rebuild in progress.** The shipped, playable v1.2.0 lives in
> git history (`main` before the 2.0 work). 2.0 follows the architecture below.

**License: GPL-3.0-only** — Zenith's quest data derives from open copyleft sources
(Questie ← CMaNGOS), so Zenith is copyleft too. See `CREDITS.md`.

## Why one addon

Today even RestedXP users also run Questie (RestedXP defers the quest database to it).
Zenith unifies the **curated route** *and* the **full quest world** behind one
filterable layer (route-only ⇄ full-world), by bundling its **own** transformed quest
dataset — so it's genuinely one addon, and the full-world layer works even without Questie.

## Pillars

1. **Quest-database map layer** (≥ Questie) — pooled world/minimap pins, tooltips, search,
   per-zone lists, journey log, smart density filtering. Lazy-loaded per zone.
2. **Route engine + native arrow** (≥ RestedXP) — data-driven steps with per-step
   applicability conditions (one route file → every class/race/faction), auto-advance,
   a `UIParent` directional arrow, optional safe auto accept/turn-in, importable strings.
3. **Class-coaching brain** — *live* talent next-point, a real-time rotation "next ability"
   helper (the clear net-new pillar), and a gear advisor that recommends the right
   quest-reward for your spec. **Display-only — no automation.**
4. **Leveling stats** (≥ RestedXP's tracker) — XP/hr, /played per level, ETA-to-cap,
   pace vs. route benchmark, per-zone efficiency, history.
5. **Unified, themeable UI** — multiple shipped themes, modern aesthetic, free & open.

## Architecture

```
Core/Compatibility.lua   cross-flavour API shim (loads first)
Core/Detect.lua          WOW_PROJECT_ID / build detection
Core/EventBus.lua        internal pub/sub
Core/StateModel.lua      single source of truth (spec/level/zone/quests/bags/gear)
Core/Registry.lua        module-enable registry
Core/DB.lua + Init.lua   AceDB + AceAddon lifecycle, friendly-fail if no data pack
Modules/                 QuestData · Route · Coach · Stats · UI (views over StateModel)
Data/packs/<flavor>/     compiled, ID-keyed, load-on-demand quest data
libs/                    Ace3, HereBeDragons(+Pins), LibDataBroker/DBIcon, LibSharedMedia …
```

Multi-flavour: one `Zenith_<Flavor>.toc` per client (TBC primary), shared body, friendly
fail with no data pack — never a Lua error.

## Status — functional spine of all 5 pillars is in (mock-tested; needs in-game verification)

- [x] **Phase 0** — skeleton: per-flavour TOCs, compat shim, lib stack, StateModel +
  EventBus + Registry, detection, AceDB, GPL + attribution. `/zenith status`.
- [x] **Phase 1** — quest data: lazy per-zone pack (62 zones / 3,906 quests, parsed on
  demand) + pooled world/minimap pins (HBD-Pins) with tooltips + route/full/off filter.
- [x] **Phase 2** — route engine (race/level-filtered, batch questing-loop) + native arrow.
- [x] **Phase 3** — coaching: live talent next-point, **live rotation widget**, gear stat
  priority (all 9 classes).
- [x] **Phase 4** — leveling stats: splits, played time, live ETA-to-ding.
- [x] **Phase 5 (core)** — themed window + tabs + 3 themes + launcher.

### Remaining depth / gates (the long tail)
Gear quest-reward picker · talent click-to-learn overlay · DB search + journey log +
party sync · options UI + first-run configurator · importable route strings · non-TBC
data packs · and the in-game **perf (Hellfire/STV) / taint / no-automation / smoke** gates
— these need a live client to verify.
