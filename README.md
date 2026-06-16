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

## Status

- [x] **Phase 0** — skeleton: per-flavour TOCs, compat shim, lib stack, StateModel +
  EventBus + Registry, detection, AceDB, GPL license + attribution. Loads clean; `/zenith status`.
- [ ] Phase 1 — quest-DB map layer (transform a reuse-licensed TBC pack → Zenith format)
- [ ] Phase 2 — route engine + native arrow
- [ ] Phase 3 — class-coaching brain (talents / **live rotation** / gear)
- [ ] Phase 4 — leveling stats
- [ ] Phase 5 — themes, configurator, polish, gate pass
