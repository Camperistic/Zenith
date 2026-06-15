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

- **Comprehensive quest guide + waypoints (all zones 1–70)** — ~3,600 quest steps per
  faction generated from the open [Questie](https://github.com/Questie/Questie) database:
  real quest names, objective text, a **waypoint per quest** (correct Classic map IDs +
  real coordinates), ordered Elwynn → … → Shadowmoon Valley. Steps **auto-advance** on
  accepting / completing objectives / turning in (tracked by quest title — no hard-coded
  IDs); `Done / Skip / Back` manually. Optional **TomTom** integration drives world/minimap pins.
- **Per-race, both factions** — each character sees its own starting chain plus the shared
  faction path; quests are race-filtered at runtime. Regenerate anytime with
  `tools/import_questie.lua`.
- **All 9 classes coached** — Warrior (Arms), Paladin (Ret), Hunter (BM), Rogue (Combat),
  Priest (Shadow), Shaman (Enh), Mage (Frost), Warlock (Demo/Felguard), Druid (Feral):
  full 61-point leveling talent path + an in-combat rotation helper for each.
- **Batch "questing loop" waypoint** — groups nearby quests into a hub and walks you
  through them the way you actually quest: **accept everything nearby → do all the
  objectives → loop back and turn them all in**, always heading to the nearest one in the
  current phase. Shows distance; drag to reposition. (Optional TomTom pins follow the same target.)
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

**Recommended:** download a packaged release zip (CurseForge / Wago / WoWInterface) and
extract it into `Interface/AddOns/` — it already contains a `Zenith/` folder.

**From source:** this repo *is* the addon (the `.toc` is at the root). Create a folder named
`Zenith` in your AddOns directory and copy the repo's contents into it:

```
World of Warcraft/_classic_/Interface/AddOns/Zenith/
    Zenith.toc   Core/   Engine/   UI/   Data/   libs/
```

If Zenith shows as **out of date** on the character-select AddOns list, tick
**"Load out of date AddOns"** — the `## Interface` number just trails the live
TBC Classic patch; nothing else is required. (Tagged releases auto-stamp the
current interface via the packager.)

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
Zenith.toc      (at the repo root)
Core/     Init.lua (namespace, lifecycle, message bus, saved vars), Util.lua
Engine/   StepEngine, Waypoint, TalentCoach, RotationHelper, GearAdvisor
UI/       MainFrame (window+tabs), Panes (tab content), MiniButton, Options
Data/     Routes/Generated/ (Questie-imported quest route)  Classes/ (talents+rotation)
          Talents/ Rotations/ Pets/ (Hunter detail)  Gear/ (Hunter detail + generic)
tools/    import_questie.lua (regenerates the quest route; not shipped)
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

## Credits

- **Quest route data** is generated from the **[Questie](https://github.com/Questie/Questie)**
  project's open TBC database (community-maintained quest/NPC coordinates — factual game data).
  Zenith extracts quest names, levels, race availability, and giver coordinates and re-emits
  them in its own format via `tools/import_questie.lua`; no Questie code is bundled. Huge thanks
  to the Questie maintainers and contributors. Run the importer yourself to regenerate/update.
- **TomTom** (optional) for enhanced world/minimap waypoint pins.

## Roadmap

- [x] **All 9 classes** — leveling talent path + rotation helper
- [x] **All races / both factions** — race starts + shared faction spine
- [x] **Beast Mastery Hunter** — full gear milestones, pre-raid BiS, pets (deepest slice)
- [x] Release packaging (MIT, `.pkgmeta`, BigWigs packager → CurseForge / Wago / WoWInterface)
- [x] **Quest-granular engine** (per-quest waypoints, accept/objective/turn-in auto-detect, TomTom)
- [x] **Comprehensive quest route, all zones 1–70, both factions, per-race** (Questie import)
- [x] **Hub-cluster ordering** within zones (nearby quests grouped, level-banded nearest-neighbour)
- [x] **Batch questing-loop waypoint** (accept nearby → do all → mass turn-in, nearest-first)
- [x] **Wago/CurseForge-publishable layout** (addon at repo root, `.pkgmeta`, packager workflow)
- [ ] Mirror the batch phase in the Guide window's step list (arrow already does it)
- [ ] Cross-zone routing polish (when to bounce between adjacent zones at overlapping levels)
- [ ] Flight-path / hearthstone hints alongside quests
- [ ] Detailed gear milestone + pre-raid BiS item lists for the other 8 classes
- [ ] Secondary specs (MM/SV Hunter, Fire/Arcane Mage, Ele Shaman, etc.) and PvP paths

Contributions are data files — copy `Data/Classes/<Class>.lua` and fill in your spec.

## Disclaimer

Fan-made; not affiliated with Blizzard Entertainment. Route/level bands reflect the
efficient-questing consensus and have natural variance.
