# Zenith

**Guided ascent to 70 — optimized every step.**

Zenith is a leveling + min-max companion for **WoW: The Burning Crusade Classic (2.5.x)**.
It guides you from level 1 to 70 RestedXP-style, but goes further: it coaches your
**talents, gear, pets, and rotation** as you go, so you're not just leveling fast —
you're leveling *well*.

> **Flagship class: Beast Mastery Hunter** (fully implemented). The engine and UI are
> class-agnostic and data-driven — every other class/spec plugs in as data files
> (see *Roadmap*).

---

## Features

- **Live leveling route** — a step-by-step zone progression for Alliance & Horde
  (Azeroth 1–60 → the shared Outland 58–70 spine), with quest hubs, recommended
  level bands, and dungeon stops. Steps **auto-complete** by quest turn-in, level,
  or arrival, and you can `Done / Skip / Back` manually.
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
| `/zen reset` | Restart route progress |

Minimap button: **left-click** opens the guide, **right-click** toggles the arrow.

## Architecture

```
Zenith/
  Core/     Init.lua (namespace, lifecycle, message bus, saved vars), Util.lua
  Engine/   StepEngine, Waypoint, TalentCoach, RotationHelper, GearAdvisor
  UI/       MainFrame (window+tabs), Panes (tab content), MiniButton
  Data/     Routes/  Talents/  Rotations/  Pets/  Gear/   ← all the per-class content
```

Engines and UI read from `ns.data.*` registries; **adding a class = adding data files**,
no engine changes. Saved variables: `ZenithDB` (account) + `ZenithCharDB` (per-character
route progress).

## Data sources

All Beast Mastery Hunter data was researched from the top TBC Classic references:

- [Wowhead — TBC Classic](https://www.wowhead.com/tbc) (class guides, item & pet DB)
- [Icy Veins — TBC Classic](https://www.icy-veins.com/tbc-classic/) (BM leveling, rotation, pre-raid gear)
- [Warcraft Tavern — TBC](https://www.warcrafttavern.com/tbc/) (leveling routes, pet & weapon guides)
- [wowtbc.gg](https://wowtbc.gg/) (BM rotation & BiS)

Talent path: **41 BM / 20 MM / 0 SV** ("leveling = endgame", no respec at 70).

## Roadmap

- [x] **Beast Mastery Hunter** — route, talents, gear, pets, rotation (flagship template)
- [ ] Remaining Hunter specs (MM/SV) + per-faction quest-level route granularity
- [ ] Warrior, Mage, Priest, Paladin/Shaman, Rogue, Warlock, Druid
- [ ] PvP talent/spec paths and battleground gear targets
- [ ] Turn-by-turn quest steps (true RestedXP granularity) with quest IDs

Contributions are data files — copy `Data/*/Hunter_*.lua` and fill in your class.

## Disclaimer

Fan-made; not affiliated with Blizzard Entertainment. Route/level bands reflect the
efficient-questing consensus and have natural variance.
