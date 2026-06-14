--[[ Data/Routes/Hunter_Route.lua

     TBC Classic 1–70 leveling route (zone-progression granularity), RestedXP-style.
     Faction-specific 1–60 Azeroth spine + the shared Outland 58–70 spine.

     STEP SCHEMA (see Engine/StepEngine.lua):
       id       string   (auto-assigned if omitted)
       kind     "travel"|"quest"|"grind"|"dungeon"|"train"|"gear"|"note"
       zone     string   display zone name
       mapID    number   uiMapID for the waypoint arrow (optional)
       x, y     number   waypoint coords 0–100 (optional)
       band     {lo, hi} recommended level band
       text     string   short instruction
       detail   string   longer tip (optional)
       complete { level=, quest=, coord={mapID,x,y,radius} }  auto-complete trigger

     Coords are approximate hub locations — good enough for a directional arrow.
     Level bands reflect the efficient-questing consensus across Wowhead / Icy-Veins
     / Warcraft Tavern (see README for sources).
]]
local ADDON_NAME, ns = ...

local function step(t) return t end

-- ── Shared Outland spine (58–70). Hub names/coords differ by faction. ──────────
local function outlandSteps(faction)
	local A = (faction == "Alliance")
	return {
		step{ kind="travel", zone="Outland", band={58,58}, text="Take the Dark Portal in the Blasted Lands to Outland",
			detail="At 58 you out-level Azeroth. Hellfire questing dings 60 within the first hour." },
		step{ kind="quest", zone="Hellfire Peninsula", mapID=100, band={58,62},
			x = A and 56 or 56, y = A and 65 or 36,
			text = "Quest Hellfire Peninsula from "..(A and "Honor Hold" or "Thrallmar"),
			detail="Grab Falcon Watch / Temple of Telhamat side hubs. Fel Reaver patrols — watch your back.",
			complete={ level=62 } },
		step{ kind="dungeon", zone="Hellfire Ramparts", mapID=100, band={60,62},
			text="Optional: Hellfire Ramparts (60–62) then The Blood Furnace (61–63)",
			detail="Earliest TBC dungeons; strong agility/AP gear for Hunters." },
		step{ kind="quest", zone="Zangarmarsh", mapID=102, band={60,64},
			x = A and 69 or 33, y = A and 50 or 52,
			text="Quest Zangarmarsh from "..(A and "Telredor" or "Zabra'jin"),
			detail="Do the Cenarion Refuge & Orebor Harborage hubs. Get the flight points.",
			complete={ level=64 } },
		step{ kind="dungeon", zone="Coilfang: Slave Pens / Underbog", mapID=102, band={62,65},
			text="Optional: Slave Pens (62–64) & Underbog (63–65)",
			detail="Underbog drops the iconic leveling pet upgrades and good mail." },
		step{ kind="quest", zone="Terokkar Forest", mapID=108, band={62,65},
			x = A and 53 or 49, y = A and 60 or 50,
			text="Quest Terokkar from "..(A and "Allerian Stronghold" or "Stonebreaker Hold"),
			detail="Set Shattrath as your hearth hub — it's the central city for both factions.",
			complete={ level=65 } },
		step{ kind="note", zone="Shattrath City", mapID=111, band={62,70}, x=55, y=47,
			text="Pick a faction: Aldor or Scryer (reputation rewards)",
			detail="Hunters: either works; pick by the rep gear/enchants you want at 70." },
		step{ kind="quest", zone="Nagrand", mapID=107, band={64,67},
			x = A and 53 or 54, y = A and 70 or 38,
			text="Quest Nagrand from "..(A and "Telaar" or "Garadar").." — best XP zone in TBC",
			detail="Nesingwary kill-chains + Throne of the Elements + the Ring of Blood quest line (huge XP & a blue weapon).",
			complete={ level=67 } },
		step{ kind="quest", zone="Blade's Edge Mountains", mapID=105, band={65,68},
			x = A and 36 or 55, y = A and 61 or 57,
			text="Quest Blade's Edge from "..(A and "Sylvanaar" or "Thunderlord Stronghold"),
			detail="Evergrove (Skettis/dragon hubs) and Mok'Nathal Village fill out the zone.",
			complete={ level=68 } },
		step{ kind="quest", zone="Netherstorm", mapID=109, band={67,70}, x=32, y=65,
			text="Quest Netherstorm from Area 52",
			detail="Area 52 is neutral. Great gold & gear; Tempest Keep dungeons (Mechanar/Botanica/Arcatraz) at 69–70.",
			complete={ level=70 } },
		step{ kind="quest", zone="Shadowmoon Valley", mapID=104, band={67,70},
			x = A and 36 or 30, y = A and 56 or 28,
			text="Finish to 70 in Shadowmoon Valley from "..(A and "Wildhammer Stronghold" or "Shadowmoon Village"),
			detail="Run in parallel with Netherstorm. Netherwing/Black Temple attunement hubs live here.",
			complete={ level=70 } },
		step{ kind="note", zone="Outland", band={70,70}, text="Dinged 70! Switch to the Gear tab for pre-raid BiS targets.",
			detail="Now chase heroic dungeon gear, Kara attunement, and your pre-raid ranged weapon." },
	}
end

-- ── Alliance 1–60 spine ───────────────────────────────────────────────────────
local function allianceSteps()
	return {
		step{ kind="quest", zone="Elwynn Forest", mapID=37, x=41.7, y=65.5, band={1,10},
			text="Starting zone: clear Elwynn (Goldshire) — or Dun Morogh / Teldrassil for your race",
			detail="Hunters get pets at 10 — head to a trainer and tame a Cat for damage.", complete={ level=10 } },
		step{ kind="train", zone="Stormwind", band={10,10}, text="Tame your first pet (Cat) and learn Beast Training",
			detail="Cats have the highest pet DPS for solo leveling." },
		step{ kind="quest", zone="Westfall", mapID=52, x=56, y=48, band={10,15}, text="Quest Westfall from Sentinel Hill",
			detail="The Defias chain feeds straight into Deadmines.", complete={ level=15 } },
		step{ kind="dungeon", zone="The Deadmines", mapID=52, band={17,21}, text="Optional: The Deadmines (17–21)",
			detail="Cookie's drops + Cruel Barb are great leveling items." },
		step{ kind="quest", zone="Redridge Mountains", mapID=49, x=24, y=42, band={15,18}, text="Quest Redridge from Lakeshire", complete={ level=18 } },
		step{ kind="quest", zone="Duskwood", mapID=47, x=75, y=44, band={18,24}, text="Quest Duskwood from Darkshire", complete={ level=24 } },
		step{ kind="quest", zone="Stranglethorn Vale", mapID=50, x=27, y=77, band={24,35}, text="Quest STV: Rebel Camp → Nesingwary → Booty Bay",
			detail="Set Booty Bay as hearth. Nesingwary beast-kill chains are excellent Hunter XP.", complete={ level=35 } },
		step{ kind="quest", zone="Arathi Highlands", mapID=14, x=45, y=46, band={30,36}, text="Weave in Arathi Highlands from Refuge Pointe" },
		step{ kind="quest", zone="Tanaris", mapID=71, x=51, y=29, band={40,47}, text="Quest Tanaris from Gadgetzan",
			detail="Zul'Farrak (44–50) gives a huge XP burst and good weapons.", complete={ level=47 } },
		step{ kind="quest", zone="Feralas", mapID=69, x=30, y=45, band={40,47}, text="Quest Feralas from Feathermoon Stronghold" },
		step{ kind="quest", zone="Un'Goro Crater", mapID=78, x=44, y=10, band={48,53}, text="Quest Un'Goro from Marshal's Refuge", complete={ level=53 } },
		step{ kind="quest", zone="Western Plaguelands", mapID=28, x=43, y=83, band={51,56}, text="Quest Western Plaguelands from Chillwind Camp" },
		step{ kind="quest", zone="Winterspring", mapID=83, x=60, y=50, band={53,58}, text="Quest Winterspring from Everlook", complete={ level=58 } },
		step{ kind="quest", zone="Eastern Plaguelands", mapID=23, x=80, y=58, band={54,60}, text="Finish to 58 in Eastern Plaguelands (Light's Hope) if needed",
			detail="At 58, head to the Blasted Lands and the Dark Portal.", complete={ level=58 } },
	}
end

-- ── Horde 1–60 spine ──────────────────────────────────────────────────────────
local function hordeSteps()
	return {
		step{ kind="quest", zone="Durotar / Mulgore / Tirisfal", band={1,10},
			text="Starting zone for your race (Orc/Troll, Tauren, Undead, Blood Elf)",
			detail="Hunters get pets at 10 — tame a Cat for damage.", complete={ level=10 } },
		step{ kind="train", zone="Capital", band={10,10}, text="Tame your first pet (Cat) and learn Beast Training" },
		step{ kind="quest", zone="The Barrens", mapID=10, x=52, y=30, band={10,22}, text="Quest The Barrens (Crossroads → Camp Taurajo → Ratchet)",
			detail="The universal Horde backbone. Wailing Caverns (17–24) is right here.", complete={ level=22 } },
		step{ kind="dungeon", zone="Wailing Caverns", mapID=10, band={17,24}, text="Optional: Wailing Caverns (17–24)" },
		step{ kind="quest", zone="Stonetalon Mountains", mapID=65, x=44, y=60, band={18,25}, text="Quest Stonetalon from Sun Rock Retreat" },
		step{ kind="quest", zone="Ashenvale", mapID=63, x=73, y=60, band={20,29}, text="Quest Ashenvale from Splintertree Post", complete={ level=29 } },
		step{ kind="quest", zone="Thousand Needles", mapID=64, x=46, y=51, band={27,34}, text="Quest Thousand Needles from Freewind Post", complete={ level=34 } },
		step{ kind="quest", zone="Stranglethorn Vale", mapID=50, x=31, y=30, band={30,40}, text="Quest STV: Grom'gol → Nesingwary → Booty Bay",
			detail="Set Booty Bay as hearth. Nesingwary beast chains = great Hunter XP.", complete={ level=40 } },
		step{ kind="quest", zone="Tanaris", mapID=71, x=51, y=29, band={40,47}, text="Quest Tanaris from Gadgetzan",
			detail="Zul'Farrak (44–50) gives huge XP and good weapons.", complete={ level=47 } },
		step{ kind="quest", zone="Feralas", mapID=69, x=75, y=45, band={40,47}, text="Quest Feralas from Camp Mojache" },
		step{ kind="quest", zone="Un'Goro Crater", mapID=78, x=44, y=10, band={48,53}, text="Quest Un'Goro from Marshal's Refuge", complete={ level=53 } },
		step{ kind="quest", zone="Felwood", mapID=77, x=42, y=55, band={48,54}, text="Quest Felwood from Bloodvenom Post" },
		step{ kind="quest", zone="Western Plaguelands", mapID=28, x=43, y=83, band={51,56}, text="Quest Western Plaguelands from The Bulwark" },
		step{ kind="quest", zone="Winterspring", mapID=83, x=60, y=50, band={53,58}, text="Finish to 58 in Winterspring (Everlook)",
			detail="At 58, head to the Blasted Lands and the Dark Portal.", complete={ level=58 } },
	}
end

-- Assemble per-faction routes (Azeroth spine + Outland spine).
local function concat(a, b)
	local out = {}
	for _, v in ipairs(a) do out[#out+1] = v end
	for _, v in ipairs(b) do out[#out+1] = v end
	return out
end

ns.data.routes.HUNTER = {
	Alliance = concat(allianceSteps(), outlandSteps("Alliance")),
	Horde    = concat(hordeSteps(),   outlandSteps("Horde")),
}
