--[[ Data/Gear/Hunter_Gear.lua

     TBC Classic Hunter gear plan: leveling milestones (the ranged weapon is the
     #1 slot at every tier) + a fresh-70 pre-raid BiS target list.

     Stat priority while leveling: Agility > Attack Power > Stamina
     (1 Agility = 2 ranged AP + crit for hunters).

     Sources: Wowhead, Icy-Veins, Warcraft Tavern, wowtbc.gg (see README).
     A few items flagged as world-boss/raid are aspirational, not fresh-70 realistic.
]]
local ADDON_NAME, ns = ...

-- Milestones the GearAdvisor surfaces as you cross each level band.
local milestones = {
	{
		level = 20, title = "Level ~20 — first real weapon",
		items = {
			{ slot = "Ranged", name = "Venomstrike", note = "Bow — Wailing Caverns. The standout early bow, lasts a long time." },
			{ slot = "Ranged", name = "Cliffrunner's Aim / Bow of Plunder", note = "Quest bows (Thousand Needles / Horde)." },
			{ slot = "Chest",  name = "Tunic of Westfall", note = "Agi/Sta — lasts well past 30 (Alliance quest)." },
			{ slot = "Feet",   name = "Feet of the Lynx", note = "Cheap agility BoE world drop (req 19)." },
		},
	},
	{
		level = 30, title = "Level ~30 — bridge the bow gap",
		items = {
			{ slot = "Ranged", name = "Shrapnel Blaster", note = "Gun — Colonel Kurzen, Stranglethorn." },
			{ slot = "Ranged", name = "Heavy Crossbow", note = "Cheap slow vendor/AH crossbow to bridge to lvl 35." },
		},
	},
	{
		level = 40, title = "Level ~40 — big upgrades + Mail",
		items = {
			{ slot = "Armor",  name = "Train Mail Armor!", note = "At 40 visit any Hunter trainer to wear Mail. Start swapping Leather → Mail." },
			{ slot = "Ranged", name = "Master Hunter's Bow", note = "Big Game Hunter, Stranglethorn — major upgrade." },
			{ slot = "Ranged", name = "Mithril Heavy-bore Rifle", note = "Engineering crafted slow gun." },
			{ slot = "Melee",  name = "Witchfury", note = "2H world drop — cheap AP stat-stick." },
		},
	},
	{
		level = 50, title = "Level ~50",
		items = {
			{ slot = "Ranged", name = "Verdant Keeper's Aim", note = "Bow — Maraudon, strong leveling bow." },
			{ slot = "Ranged", name = "Highland Bow", note = "Primal Torntusk, The Hinterlands." },
		},
	},
	{
		level = 60, title = "Level 60 — investment that lasts to 70",
		items = {
			{ slot = "Ranged", name = "High Warlord's / Grand Marshal's Crossbow", note = "Honor purchase at 60 — lasts all the way to 70." },
			{ slot = "Ranged", name = "Hellfire intro-quest bow", note = "Grab the Hellfire Peninsula quest reward the moment you hit Outland." },
		},
	},
	{
		level = 70, title = "Level 70 — leveling tail",
		items = {
			{ slot = "Ranged", name = "Hemet's Elekk Gun", note = "Hemet Nesingwary chain, Nagrand — best gun while leveling Outland." },
			{ slot = "Ranged", name = "Ring of Blood reward (Nagrand)", note = "Short boss gauntlet — rare weapons that last several levels." },
		},
	},
}

-- Fresh-70 pre-raid BiS targets. Core plan: Beast Lord 4-set (heroics) + Primalstrike
-- (crafted) + badge pieces + Honor Hold/Thrallmar exalted ranged weapon.
local preraid = {
	{ slot = "Head",     name = "Beast Lord Helm",        source = "Heroic The Mechanar" },
	{ slot = "Neck",     name = "Jagged Bark Pendant",    source = "Botanica (Warp Splinter) / Choker of Vile Intent (25 Badges)" },
	{ slot = "Shoulder", name = "Beast Lord Mantle",      source = "Heroic The Steamvault" },
	{ slot = "Back",     name = "Blood Knight War Cloak", source = "25 Badges of Justice (G'eras)" },
	{ slot = "Chest",    name = "Beast Lord Cuirass",     source = "Botanica / alt Primalstrike Vest (crafted)" },
	{ slot = "Wrist",    name = "Primalstrike Bracers",   source = "Crafted (Elemental Leatherworking)" },
	{ slot = "Hands",    name = "Beast Lord Handguards",  source = "Heroic The Shattered Halls" },
	{ slot = "Waist",    name = "Primalstrike Belt",      source = "Crafted (Elemental Leatherworking)" },
	{ slot = "Legs",     name = "Wastewalker Leggings",   source = "Heroic Mana-Tombs — highest Agi + 3 sockets" },
	{ slot = "Feet",     name = "Fel Leather Boots",      source = "Crafted (Leatherworking)" },
	{ slot = "Ring 1",   name = "Ring of the Recalcitrant", source = "Magtheridon attune chain (quest)" },
	{ slot = "Ring 2",   name = "Pathfinder's Band",      source = "World drop / BoE" },
	{ slot = "Trinket 1",name = "Bloodlust Brooch",       source = "41 Badges of Justice (G'eras)" },
	{ slot = "Trinket 2",name = "Hourglass of the Unraveller", source = "Heroic Black Morass (Temporus)" },
	{ slot = "Ranged",   name = "Veteran's Musket / Marksman's Bow", source = "Honor Hold / Thrallmar — Exalted (no-RNG target)" },
	{ slot = "Ranged",   name = "Wrathtide Longbow",      source = "Heroic Steamvault — common pre-raid BiS bow" },
}

local notes = {
	"Beast Lord 4-set bonus (pet melee → +50 AP to you, stacks 10x) is BiS until Tier 5 — top priority.",
	"Hit first: 142 ranged hit (9%) solo, ~95 (6%) with Misery/Imp Faerie Fire in raid. Then stack Agility.",
	"Meta: Relentless Earthstorm Diamond. Red sockets: Delicate Living Ruby (+8 Agi).",
	"Take Leatherworking + Skinning: Primalstrike set, Fel Leather Boots, and Drums of Battle.",
	"Key reps: Honor Hold/Thrallmar (ranged weapon), Cenarion Expedition (heroic Coilfang key), Lower City (Mana-Tombs), Keepers of Time (Black Morass).",
}

ns.data.gear.HUNTER = {
	statPriority = "Agility > Attack Power > Stamina",
	milestones   = milestones,
	preraid      = preraid,
	notes        = notes,
}
