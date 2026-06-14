# Zenith

**Guided ascent to 70 — optimized every step.**

Zenith is a leveling + min-max companion for **WoW: The Burning Crusade Classic (2.5.x)**.
It guides you from level 1 to 70 RestedXP-style, but goes further: it coaches your
**talents, gear, pets, and rotation** as you go, so you're not just leveling fast —
you're leveling *well*.

> **All 9 classes** have a researched leveling talent path + rotation helper. The route
> works for **every race and both factions**. Beast Mastery Hunter is the deepest slice
> (full gear milestones, pre-raid BiS, and pet guidance); the other classes have stat-priority
> gear guidance with detailed item lists on the roadmap.

---

## Features

- **Quest-by-quest guide + waypoints** — the engine supports true turn-by-turn steps
  (accept → objective → turn-in) with a waypoint per quest and **automatic detection**
  of accepting, completing objectives, and turning in (tracked by quest title — no
  hard-coded IDs). Optional **TomTom** integration drives world/minimap pins.
  *Worked slice shipped: Human 1–15 (Northshire → Elwynn → Westfall).*
- **Full 1–70 coverage (all races, both factions)** — per-race starting zones stitched
  onto a shared Alliance/Horde spine (Azeroth 1–60 → Outland 58–70). Currently a mix of
  turn-by-turn (the early slice) and zone-level for the rest; both auto-advance.
  `Done / Skip / Back` manually.
- **All 9 classes coached** — Warrior (Arms), Paladin (Ret), Hunter (BM), Rogue (Combat),
  Priest (Shadow), Shaman (Enh), Mage (Frost), Warlock (Demo/Felguard), Druid (Feral):
  full 61-point leveling talent path + an in-combat rotation helper for each.
- **Waypoint arrow** — a lightweight directional arrow points to the current step's
  coordinates and shows distance. Drag to reposition.
- **Real-time talent coach** — counts the points you've actually spent and tells you
  **exactly where to put your next point**, highlighting **power spikes** (Intimidation,
  Bestial Wrath, Serpent's Swiftness, The Beast Within). Pops a reminder on level-up.
- **Gear advisor** — the right **gear to chase right now** for your level milestone,
  the famous twink/BoE upgrades, *"train Mail at 40"*, and the full **fresh-70 pre-raid
  BiS** list once you ding 70.
- **Pet guidance** — best leveling pets by phase (Cat/Boar early → **Ravager (Gore)** at 61+),
  where to tame them, and the TBC happiness/ability tips that matter.
- **Rotation helper** — an on-screen "next best shot" suggestion in combat, built from
  the BM shot priority (Kill Command after crits, Bestial Wrath, Multi-Shot, Serpent
  Sting, the Steady-weave at 62+), plus aspect/mana guidance.
- **Polished, movable UI** — a tabbed window (Guide / Talents / Gear / Help), a minimap
  button, and a fel-green TBC theme. Lock/unlock and drag every piece.

## Install

Copy the `Zenith` folder into:

```
World of Warcraft/_classic_/Interface/AddOns/Zenith
```

(`Zenith.toc`, `Core/`, `Engine/`, `UI/`, `Data/`, `libs/` should sit directly inside.)

## Commands

| Command | Action |
|---|---|
| `/zenith` or `/zen` | Toggle the main window |
| `/zen next` · `/zen prev` | Move the route forward/back |
| `/zen arrow` | Toggle the waypoint arrow |
| `/zen rotation` | Toggle the DPS helper |
| `/zen lock` · `/zen unlock` | Lock/unlock frame dragging |
| `/zen config` | Open the options panel |
| `/zen reset` | Restart route progress |

Minimap button: **left-click** opens the guide, **right-click** toggles the arrow.

## Architecture

```
Zenith/
  Core/     Init.lua (namespace, lifecycle, message bus, saved vars), Util.lua
  Engine/   StepEngine, Waypoint, TalentCoach, RotationHelper, GearAdvisor
  UI/       MainFrame (window+tabs), Panes (tab content), MiniButton, Options
  Data/     Routes/ (faction spine + race starts)  Classes/ (talents+rotation per class)
            Talents/ Rotations/ Pets/ (Hunter detail)  Gear/ (Hunter detail + generic)
```

Engines and UI read from `ns.data.*` registries; **adding a class = adding one data file**
(`U.TalentPath` expands a compact grouped plan into the per-level path). Saved variables:
`ZenithDB` (account) + `ZenithCharDB` (per-character route progress).

## Data sources

All Beast Mastery Hunter data was researched from the top TBC Classic references:

- [Wowhead — TBC Classic](https://www.wowhead.com/tbc) (class guides, item & pet DB)
- [Icy Veins — TBC Classic](https://www.icy-veins.com/tbc-classic/) (BM leveling, rotation, pre-raid gear)
- [Warcraft Tavern — TBC](https://www.warcrafttavern.com/tbc/) (leveling routes, pet & weapon guides)
- [wowtbc.gg](https://wowtbc.gg/) (BM rotation & BiS)

Talent path: **41 BM / 20 MM / 0 SV** ("leveling = endgame", no respec at 70).

## Roadmap

- [x] **All 9 classes** — leveling talent path + rotation helper
- [x] **All races / both factions** — race starts + shared faction spine
- [x] **Beast Mastery Hunter** — full gear milestones, pre-raid BiS, pets (deepest slice)
- [x] Release packaging (MIT, `.pkgmeta`, BigWigs packager → CurseForge / Wago / WoWInterface)
- [x] **Quest-granular engine** (per-quest waypoints, accept/objective/turn-in auto-detect, TomTom)
- [x] Turn-by-turn worked slice (Human 1–15)
- [ ] **Fill turn-by-turn data for the rest of 1–70, all races** — the remaining content
      effort. Hand-authoring matches RestedXP quality but is slow; importing an open quest
      dataset (e.g. Questie's, with attribution) is the faster path. Same engine either way.
- [ ] Detailed gear milestone + pre-raid BiS item lists for the other 8 classes
- [ ] Secondary specs (MM/SV Hunter, Fire/Arcane Mage, Ele Shaman, etc.) and PvP paths

Contributions are data files — copy `Data/Classes/<Class>.lua` and fill in your spec.

## Disclaimer

Fan-made; not affiliated with Blizzard Entertainment. Route/level bands reflect the
efficient-questing consensus and have natural variance.
