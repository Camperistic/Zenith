--[[ Data/Routes/Leveling.lua

     Class-AGNOSTIC TBC Classic 1–70 leveling route (zone-progression granularity).
     The route is the same whatever you play; only the 1–~12 start differs by race,
     so race intros live in ns.data.starts[race] and the shared faction spine lives
     in ns.data.route[faction]. StepEngine stitches: race start + faction spine.

     STEP SCHEMA (see Engine/StepEngine.lua):
       kind  "travel"|"quest"|"grind"|"dungeon"|"train"|"gear"|"note"
       zone  string · mapID number · x,y 0–100 (waypoint) · band {lo,hi}
       text  short instruction · detail longer tip
       complete { level=, quest=, coord={mapID,x,y,radius} }

     Coords are approximate hub locations — good enough for a directional arrow.
     Sources: Wowhead / Icy-Veins / Warcraft Tavern leveling routes (see README).
]]
local ADDON_NAME, ns = ...

local function step(t) return t end

-- ── Per-race starting zones (levels 1–~12), then "go meet the spine". ──────────
-- These zones/hubs are factual TBC start locations.
ns.data.starts = {
	-- Alliance
	Human = {
		step{ kind="quest", zone="Elwynn Forest", mapID=37, x=41.7, y=65.5, band={1,10},
			text="Northshire → Elwynn Forest (Goldshire)", complete={ level=10 } },
	},
	Dwarf = {
		step{ kind="quest", zone="Dun Morogh", mapID=27, x=47, y=52, band={1,10},
			text="Coldridge Valley → Dun Morogh (Kharanos)", complete={ level=10 } },
	},
	Gnome = {
		step{ kind="quest", zone="Dun Morogh", mapID=27, x=47, y=52, band={1,10},
			text="Coldridge Valley → Dun Morogh (Kharanos)", complete={ level=10 } },
	},
	NightElf = {
		step{ kind="quest", zone="Teldrassil", mapID=57, x=55, y=60, band={1,10},
			text="Shadowglen → Teldrassil (Dolanaar)", complete={ level=10 } },
		step{ kind="travel", zone="Darkshore", mapID=62, x=37, y=42, band={10,12},
			text="Boat from Rut'theran to Auberdine, Darkshore", complete={ level=12 } },
	},
	Draenei = {
		step{ kind="quest", zone="Azuremyst Isle", mapID=97, x=49, y=55, band={1,10},
			text="Ammen Vale → Azuremyst Isle (Azure Watch)", complete={ level=10 } },
		step{ kind="quest", zone="Bloodmyst Isle", mapID=106, x=44, y=72, band={10,18},
			text="Bloodmyst Isle (Blood Watch) to ~18, then mainland", complete={ level=18 } },
	},
	-- Horde
	Orc = {
		step{ kind="quest", zone="Durotar", mapID=1, x=43, y=68, band={1,10},
			text="Valley of Trials → Durotar (Razor Hill)", complete={ level=10 } },
	},
	Troll = {
		step{ kind="quest", zone="Durotar", mapID=1, x=43, y=68, band={1,10},
			text="Valley of Trials → Durotar (Razor Hill)", complete={ level=10 } },
	},
	Tauren = {
		step{ kind="quest", zone="Mulgore", mapID=7, x=47, y=58, band={1,10},
			text="Camp Narache → Mulgore (Bloodhoof Village)", complete={ level=10 } },
	},
	Scourge = {  -- Undead (UnitRace returns "Scourge")
		step{ kind="quest", zone="Tirisfal Glades", mapID=18, x=60, y=52, band={1,10},
			text="Deathknell → Tirisfal Glades (Brill)", complete={ level=10 } },
		step{ kind="quest", zone="Silverpine Forest", mapID=21, x=46, y=42, band={10,14},
			text="Silverpine Forest (The Sepulcher)", complete={ level=14 } },
	},
	BloodElf = {
		step{ kind="quest", zone="Eversong Woods", mapID=94, x=48, y=50, band={1,10},
			text="Sunstrider Isle → Eversong Woods (Falconwing Square)", complete={ level=10 } },
		step{ kind="quest", zone="Ghostlands", mapID=95, x=46, y=29, band={10,18},
			text="Ghostlands (Tranquillien) to ~18, then mainland", complete={ level=18 } },
	},
}

-- ── Shared Outland spine (58–70). Hub names/coords differ by faction. ──────────
local function outlandSteps(faction)
	local A = (faction == "Alliance")
	return {
		step{ kind="travel", zone="Outland", band={58,58}, text="Take the Dark Portal in the Blasted Lands to Outland",
			detail="At 58 you out-level Azeroth. Hellfire questing dings 60 within the first hour." },
		step{ kind="quest", zone="Hellfire Peninsula", mapID=100, band={58,62},
			x = 56, y = A and 65 or 36,
			text = "Quest Hellfire Peninsula from "..(A and "Honor Hold" or "Thrallmar"),
			detail="Grab Falcon Watch / Temple of Telhamat side hubs. Fel Reaver patrols — watch your back.",
			complete={ level=62 } },
		step{ kind="dungeon", zone="Hellfire Ramparts", mapID=100, band={60,62},
			text="Optional: Hellfire Ramparts (60–62) then The Blood Furnace (61–63)",
			detail="Earliest TBC dungeons; great early-Outland gear." },
		step{ kind="quest", zone="Zangarmarsh", mapID=102, band={60,64},
			x = A and 69 or 33, y = A and 50 or 52,
			text="Quest Zangarmarsh from "..(A and "Telredor" or "Zabra'jin"),
			detail="Do Cenarion Refuge & Orebor Harborage. Get the flight points.",
			complete={ level=64 } },
		step{ kind="quest", zone="Terokkar Forest", mapID=108, band={62,65},
			x = A and 53 or 49, y = A and 60 or 50,
			text="Quest Terokkar from "..(A and "Allerian Stronghold" or "Stonebreaker Hold"),
			detail="Set Shattrath as your hearth — the central neutral city.",
			complete={ level=65 } },
		step{ kind="note", zone="Shattrath City", mapID=111, band={62,70}, x=55, y=47,
			text="Pick a faction: Aldor or Scryer (reputation rewards)",
			detail="Choose by the rep gear/enchants your class wants at 70." },
		step{ kind="quest", zone="Nagrand", mapID=107, band={64,67},
			x = A and 53 or 54, y = A and 70 or 38,
			text="Quest Nagrand from "..(A and "Telaar" or "Garadar").." — best XP zone in TBC",
			detail="Nesingwary kill-chains + Throne of the Elements + the Ring of Blood quest line (huge XP & a blue weapon).",
			complete={ level=67 } },
		step{ kind="quest", zone="Blade's Edge Mountains", mapID=105, band={65,68},
			x = A and 36 or 55, y = A and 61 or 57,
			text="Quest Blade's Edge from "..(A and "Sylvanaar" or "Thunderlord Stronghold"),
			detail="Evergrove and Mok'Nathal Village fill out the zone.",
			complete={ level=68 } },
		step{ kind="quest", zone="Netherstorm", mapID=109, band={67,70}, x=32, y=65,
			text="Quest Netherstorm from Area 52 (neutral)",
			detail="Great gold & gear; Tempest Keep dungeons at 69–70.",
			complete={ level=70 } },
		step{ kind="quest", zone="Shadowmoon Valley", mapID=104, band={67,70},
			x = A and 36 or 30, y = A and 56 or 28,
			text="Finish to 70 in Shadowmoon Valley from "..(A and "Wildhammer Stronghold" or "Shadowmoon Village"),
			detail="Run in parallel with Netherstorm.",
			complete={ level=70 } },
		step{ kind="note", zone="Outland", band={70,70}, text="Dinged 70! Open the Gear tab for pre-raid targets.",
			detail="Chase heroic dungeon gear, Karazhan attunement, and your pre-raid weapon." },
	}
end

-- ── Alliance Azeroth spine (~12–58) ───────────────────────────────────────────
local function allianceAzeroth()
	return {
		step{ kind="note", zone="Azeroth", band={10,12}, text="Train your new level-10 abilities (Hunters: tame a pet)",
			detail="Visit your class trainer in a capital whenever you can." },
		step{ kind="quest", zone="Westfall", mapID=52, x=56, y=48, band={12,15}, text="Quest Westfall from Sentinel Hill",
			detail="The Defias chain feeds straight into Deadmines.", complete={ level=15 } },
		step{ kind="dungeon", zone="The Deadmines", mapID=52, band={17,21}, text="Optional: The Deadmines (17–21)" },
		step{ kind="quest", zone="Redridge Mountains", mapID=49, x=24, y=42, band={15,18}, text="Quest Redridge from Lakeshire", complete={ level=18 } },
		step{ kind="quest", zone="Duskwood", mapID=47, x=75, y=44, band={18,24}, text="Quest Duskwood from Darkshire", complete={ level=24 } },
		step{ kind="quest", zone="Stranglethorn Vale", mapID=50, x=27, y=77, band={24,35}, text="STV: Rebel Camp → Nesingwary → Booty Bay",
			detail="Set Booty Bay as hearth. Nesingwary beast chains are great XP.", complete={ level=35 } },
		step{ kind="quest", zone="Arathi Highlands", mapID=14, x=45, y=46, band={30,36}, text="Weave in Arathi Highlands from Refuge Pointe" },
		step{ kind="quest", zone="Tanaris", mapID=71, x=51, y=29, band={40,47}, text="Quest Tanaris from Gadgetzan",
			detail="Zul'Farrak (44–50) gives a huge XP burst.", complete={ level=47 } },
		step{ kind="quest", zone="Feralas", mapID=69, x=30, y=45, band={40,47}, text="Quest Feralas from Feathermoon Stronghold" },
		step{ kind="quest", zone="Un'Goro Crater", mapID=78, x=44, y=10, band={48,53}, text="Quest Un'Goro from Marshal's Refuge", complete={ level=53 } },
		step{ kind="quest", zone="Western Plaguelands", mapID=28, x=43, y=83, band={51,56}, text="Quest Western Plaguelands from Chillwind Camp" },
		step{ kind="quest", zone="Winterspring", mapID=83, x=60, y=50, band={53,58}, text="Quest Winterspring from Everlook", complete={ level=58 } },
		step{ kind="quest", zone="Eastern Plaguelands", mapID=23, x=80, y=58, band={54,58}, text="Top up to 58 in Eastern Plaguelands (Light's Hope) if needed",
			detail="At 58, head to the Blasted Lands and the Dark Portal.", complete={ level=58 } },
	}
end

-- ── Horde Azeroth spine (~12–58) ──────────────────────────────────────────────
local function hordeAzeroth()
	return {
		step{ kind="note", zone="Azeroth", band={10,12}, text="Train your new level-10 abilities (Hunters: tame a pet)",
			detail="Visit your class trainer in a capital whenever you can." },
		step{ kind="quest", zone="The Barrens", mapID=10, x=52, y=30, band={12,22}, text="Quest The Barrens (Crossroads → Camp Taurajo → Ratchet)",
			detail="The universal Horde backbone. Wailing Caverns (17–24) is right here.", complete={ level=22 } },
		step{ kind="dungeon", zone="Wailing Caverns", mapID=10, band={17,24}, text="Optional: Wailing Caverns (17–24)" },
		step{ kind="quest", zone="Stonetalon Mountains", mapID=65, x=44, y=60, band={18,25}, text="Quest Stonetalon from Sun Rock Retreat" },
		step{ kind="quest", zone="Ashenvale", mapID=63, x=73, y=60, band={20,29}, text="Quest Ashenvale from Splintertree Post", complete={ level=29 } },
		step{ kind="quest", zone="Thousand Needles", mapID=64, x=46, y=51, band={27,34}, text="Quest Thousand Needles from Freewind Post", complete={ level=34 } },
		step{ kind="quest", zone="Stranglethorn Vale", mapID=50, x=31, y=30, band={30,40}, text="STV: Grom'gol → Nesingwary → Booty Bay",
			detail="Set Booty Bay as hearth. Nesingwary beast chains = great XP.", complete={ level=40 } },
		step{ kind="quest", zone="Tanaris", mapID=71, x=51, y=29, band={40,47}, text="Quest Tanaris from Gadgetzan",
			detail="Zul'Farrak (44–50) gives huge XP.", complete={ level=47 } },
		step{ kind="quest", zone="Feralas", mapID=69, x=75, y=45, band={40,47}, text="Quest Feralas from Camp Mojache" },
		step{ kind="quest", zone="Un'Goro Crater", mapID=78, x=44, y=10, band={48,53}, text="Quest Un'Goro from Marshal's Refuge", complete={ level=53 } },
		step{ kind="quest", zone="Felwood", mapID=77, x=42, y=55, band={48,54}, text="Quest Felwood from Bloodvenom Post" },
		step{ kind="quest", zone="Western Plaguelands", mapID=28, x=43, y=83, band={51,56}, text="Quest Western Plaguelands from The Bulwark" },
		step{ kind="quest", zone="Winterspring", mapID=83, x=60, y=50, band={53,58}, text="Finish to 58 in Winterspring (Everlook)",
			detail="At 58, head to the Blasted Lands and the Dark Portal.", complete={ level=58 } },
	}
end

local function concat(...)
	local out = {}
	for _, list in ipairs({...}) do
		for _, v in ipairs(list) do out[#out+1] = v end
	end
	return out
end

ns.data.route = {
	Alliance = concat(allianceAzeroth(), outlandSteps("Alliance")),
	Horde    = concat(hordeAzeroth(),   outlandSteps("Horde")),
}
