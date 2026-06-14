--[[ Data/Routes/Detailed_Alliance.lua

     TURN-BY-TURN detailed leveling route (RestedXP-style) — Human start, 1–15:
     Northshire → Elwynn Forest (Goldshire) → Westfall (Sentinel Hill).

     This is the worked vertical slice that exercises the quest-granular engine
     (per-quest waypoints + accept/objective/turn-in auto-detection). Steps
     auto-advance when the quest's objectives complete or it's turned in (tracked
     by title); a `complete.level` fallback keeps the list moving if a title or
     locale doesn't match, and the Done button always works.

     Coordinates are approximate hub/objective locations (good guides, not survey
     points). Quest titles are enUS. Additional zones/races use the same schema —
     this slice is the template the rest of the route is filled in against.

     mapIDs: Elwynn Forest 37, Westfall 52.
]]
local ADDON_NAME, ns = ...

local function s(t) return t end

ns.data.detailed.Human = {
	coversTo = 15,
	steps = {
		-- ── Northshire Valley (1–6) — sub-zone is phased; text guidance, no arrow ──
		s{ kind="quest", zone="Northshire", band={1,2}, quest="A Threat Within",
			text="Talk to Marshal McBride, then take the quests he offers",
			detail="McBride is just outside the Abbey. Accept everything he gives." },
		s{ kind="quest", zone="Northshire", band={1,3}, quest="Beating Them Back!",
			text="Kill Kobold Vermin in the fields south/east of the Abbey",
			detail="Do this alongside the other early kobold quests." },
		s{ kind="quest", zone="Northshire", band={2,4}, quest="Kobold Camp Cleanup",
			text="Clear the kobolds at Echo Ridge Mine (north of the Abbey)" },
		s{ kind="quest", zone="Northshire", band={3,5}, quest="Brotherhood of Thieves",
			text="Kill Defias Thugs by the river (east of the Abbey)" },
		s{ kind="quest", zone="Northshire", band={4,6}, quest="Milly's Harvest",
			text="Help Milly Osworth, finish the remaining Northshire quests",
			detail="Turn everything in at the Abbey as you complete it." },
		s{ kind="quest", zone="Northshire", band={5,6}, quest="Join the Battle!",
			text="Take 'Join the Battle!' and ride/run to Goldshire",
			complete={ level=6 } },

		-- ── Goldshire & Elwynn Forest (6–10) ─────────────────────────────────────
		s{ kind="accept", zone="Elwynn Forest", mapID=37, x=42, y=65, band={6,7},
			text="Goldshire: pick up quests from Marshal Dughan & the inn",
			detail="Dughan (Fargodeep/Jasperlode/Garrick), William Pestle, Remy 'Two Times' in the Lion's Pride Inn." },
		s{ kind="quest", zone="Elwynn Forest", mapID=37, x=38, y=76, band={6,8}, quest="The Fargodeep Mine",
			text="Explore the Fargodeep Mine (far south of Goldshire)",
			detail="Kill kobolds here for Gold Dust Exchange at the same time." },
		s{ kind="quest", zone="Elwynn Forest", mapID=37, x=39, y=75, band={6,8}, quest="Gold Dust Exchange",
			text="Collect Gold Dust from kobolds around Fargodeep" },
		s{ kind="quest", zone="Elwynn Forest", mapID=37, x=33, y=66, band={7,9}, quest="Princess Must Die!",
			text="Stonefield Farm (west): kill the boar Princess",
			detail="Grab the Maclure/Stonefield 'Young Lovers' quests while here." },
		s{ kind="quest", zone="Elwynn Forest", mapID=37, x=63, y=78, band={7,9}, quest="Bounty on Garrick Padfoot",
			text="Brackwell Pumpkin Patch (southeast): kill Garrick Padfoot" },
		s{ kind="quest", zone="Elwynn Forest", mapID=37, x=50, y=62, band={7,9}, quest="The Jasperlode Mine",
			text="Explore the Jasperlode Mine (east-central)" },
		s{ kind="quest", zone="Elwynn Forest", mapID=37, x=64, y=56, band={8,10}, quest="Riverpaw Gnoll Bounty",
			text="Eastvale & Westbrook: kill Riverpaw gnolls, then quest east toward Eastvale Logging Camp",
			detail="Turn in completed quests back at Goldshire. Aim for ~10 before Westfall." },
		s{ kind="turnin", zone="Elwynn Forest", mapID=37, x=42, y=65, band={9,10},
			text="Turn in everything at Goldshire; set your Hearthstone here",
			detail="At 10, learn your level-10 abilities (Hunters: tame a pet).",
			complete={ level=10 } },

		-- ── Travel to Westfall ───────────────────────────────────────────────────
		s{ kind="travel", zone="Westfall", mapID=52, x=56, y=48, band={10,10},
			text="Run southwest through Elwynn to Westfall → Sentinel Hill" },

		-- ── Westfall (10–15) ─────────────────────────────────────────────────────
		s{ kind="accept", zone="Westfall", mapID=52, x=56, y=48, band={10,11},
			text="Sentinel Hill: take all quests (Gryan Stoutmantle, the tower, Saldean's Farm board)",
			detail="Stoutmantle starts the Defias Brotherhood chain." },
		s{ kind="quest", zone="Westfall", mapID=52, x=58, y=30, band={10,12}, quest="Westfall Stew",
			text="Saldean's Farm (north): make Westfall Stew (kill Coyotes/Gophers nearby)",
			detail="Grab 'Goretusk Liver Pie' and 'Poor Old Blanchy' from the Saldeans too." },
		s{ kind="quest", zone="Westfall", mapID=52, x=52, y=26, band={10,12}, quest="Goretusk Liver Pie",
			text="Collect Goretusk Livers from boars across the northern fields" },
		s{ kind="quest", zone="Westfall", mapID=52, x=50, y=40, band={11,13}, quest="The Killing Fields",
			text="Investigate the Harvest Golems in the central fields" },
		s{ kind="quest", zone="Westfall", mapID=52, x=37, y=68, band={11,13}, quest="Furlbrow's Deed",
			text="The Jansen Stead / Furlbrow's farm (west): loot the deed, turn in to Verna Furlbrow" },
		s{ kind="quest", zone="Westfall", mapID=52, x=28, y=55, band={12,14}, quest="The Coast Isn't Clear",
			text="Longshore (west coast): clear Murlocs along the beach" },
		s{ kind="quest", zone="Westfall", mapID=52, x=56, y=48, band={12,14}, quest="The Defias Brotherhood",
			text="Run the Defias Brotherhood chain from Sentinel Hill",
			detail="This chain (Defias Messenger ambush, etc.) leads into The Deadmines." },
		s{ kind="dungeon", zone="The Deadmines", mapID=52, x=42, y=72, band={15,18},
			text="At ~15–18, run The Deadmines (entrance in Moonbrook, SW)",
			detail="Great early gear: Cruel Barb, Cookie's drops. Then continue to Redridge.",
			complete={ level=15 } },
	},
}
