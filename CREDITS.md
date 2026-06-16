# Credits & data provenance

Zenith is licensed **GPL-3.0-only** (see `LICENSE`). It is copyleft because the
quest dataset it builds on is copyleft — see below.

## Quest data

Zenith's quest/NPC/object data is **transformed from open, reuse-licensed community
databases** into Zenith's own compact, ID-keyed, load-on-demand format. It bundles
no proprietary or commercial addon files, and scrapes no aggregator sites.

- **Questie** (`Database/*`) — the open community quest database, used as a source.
  https://github.com/Questie/Questie
- **CMaNGOS** — the open server-emulator database that the community quest data is
  ultimately derived from (GPL-2.0). Questie's TBC quest data credits CMaNGOS in-file.
  https://github.com/cmangos

Because that chain is **GPL**, Zenith is distributed under **GPL-3.0-only** (compatible
with GPL-2.0-or-later sources). Quest *facts* (IDs, coordinates, levels) are not
themselves copyrightable, but Zenith is GPL to keep provenance unambiguous and clean.

The transform pipeline lives in `tools/` and regenerates Zenith's data packs from the
upstream source, so updates can be pulled cleanly.

## Embedded libraries (in `libs/`)

All under their own permissive open licenses (compatible with GPL):

- **Ace3** (AceAddon, AceEvent, AceTimer, AceComm, AceSerializer, AceDB, AceDBOptions,
  AceConsole, AceGUI, AceConfig) — WowAce
- **CallbackHandler-1.0**, **LibStub**
- **HereBeDragons-2.0** + **HereBeDragons-Pins-2.0** — map coordinates & pins
- **LibDataBroker-1.1**, **LibDBIcon-1.0** — launcher/minimap
- **LibSharedMedia-3.0** — fonts/textures
- **LibUIDropDownMenu** — cross-version dropdown compatibility

## Not used

No code or compiled data from any paid/proprietary addon. No content scraped from
Wowhead, WoWDB, or other commercial aggregators. No runtime network access (the addon
sandbox has none) — all data ships as local Lua, loaded on demand.
