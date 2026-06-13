# TalentMate

**Class-aware talent build library and auto-applier for World of Warcraft: Burning Crusade Classic (2.5.x "Anniversary").**

TalentMate detects your class and gives you a one-click library of recommended **PvE**, **PvP**, and **leveling** talent builds — then spends the points for you, one at a time, respecting every tier gate and prerequisite. No more squinting at a calculator and hand-placing 61 points.

```
/tm
```

---

## Features

- **57 validated builds** — 6–7 per class across all nine TBC classes, covering raid DPS / tank / healer, Heroic dungeons, arena, battlegrounds, and leveling. Every build is checked against authoritative TBC 2.4.3 talent data: tier-legal (no stranded points), within max-ranks, and exactly 61 points.
- **Spends the points for you.** Pick a build and confirm; TalentMate places each point in a legal order and stops cleanly if anything's off.
- **Guided leveling.** Each class has a level-by-level leveling build. Run it again after every ding and it places exactly the points you've earned so far, in the optimal order.
- **Level-aware & dual-spec-aware.** Works before level 40 (single spec) and after (dual spec) — it always targets the talent group you currently have open.
- **Self-healing.** If a build's pick order ever reaches a talent before its prerequisite, TalentMate defers that pick and circles back once it's legal, instead of dead-stopping.
- **Built into the talent UI.** A **TalentMate** button appears on the talent frame, plus a class-aware settings window with a dropdown of every build and a description of when to use it.
- **Safe by design.** A confirmation prompt (talent changes cost gold to undo), a combat check, a point budget so it never spends a point you earned mid-apply, and it only ever spends *unspent* points.

## Installation

**Option 1 — Download:**
1. Click **Code → Download ZIP** above.
2. Extract it, and **rename the folder to `TalentMate`** (GitHub names it `TalentMate-main`; WoW requires the folder name to match).
3. Move that `TalentMate` folder into:
   `World of Warcraft\_anniversary_\Interface\AddOns\`

**Option 2 — Git:**
```sh
cd "World of Warcraft/_anniversary_/Interface/AddOns"
git clone https://github.com/Camperistic/TalentMate.git
```

Then `/reload` (or restart) and make sure **TalentMate** is enabled in the AddOns list at character select.

## Usage

| Command | What it does |
| --- | --- |
| `/tm` | Open the build picker (class-detected dropdown + descriptions) |
| `/tm pve` | Quick-apply your class's first PvE build |
| `/tm pvp` | Quick-apply your class's first PvP build |
| `/tm level` | Apply the guided leveling build up to your current points |
| `/tm list` | List every build available for your class |
| `/tm show` | Print the currently selected build |
| `/tm stop` | Cancel an in-progress apply |

You can also click the **TalentMate** button on the talent frame to open the settings window.

> **Note:** TalentMate only spends *unspent* talent points. To switch from a fully-spent spec to a different one, reset your talents at a class trainer first (this costs gold), then apply the new build. Talent changes are not reversible without a trainer reset, so apply is always gated behind a confirmation prompt. English client only (it matches talents by name and will warn on any it can't find).

## Privacy & analytics

TalentMate ships the optional [Wago Analytics](https://addons.wago.io/docs/analytics) shim. It only does anything if you have the **Wago App** installed and have opted into analytics there — in which case it reports **anonymous, aggregate** counts (e.g. which class/spec gets applied, how often). It never collects personal data, and with no Wago App every analytics call is a no-op. If you installed via this repo (not the Wago App), nothing is reported at all.

## Compatibility

- **Game:** Burning Crusade Classic 2.5.x (Interface `20505`).
- Built and tested on the modern-engine "Anniversary" TBC client.

## License

Released to the public for personal use. Author: **Camperistic**. Embeds Wago's `WagoAnalyticsShim` (AGPL-3.0) and the public-domain `LibStub`.
