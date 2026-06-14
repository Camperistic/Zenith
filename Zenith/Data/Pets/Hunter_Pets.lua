--[[ Data/Pets/Hunter_Pets.lua

     TBC Classic Hunter leveling pet recommendations (Beast Mastery focus).
     TBC mechanics note: all pet melee is normalized to 2.0s/swing (no Classic
     Broken-Tooth advantage), so family choice is about ABILITIES, not speed.
     Pick a pet with TWO focus-dump abilities (e.g. Bite + Claw) for max output.

     Sources: Wowhead pet DB, Icy-Veins, Warcraft Tavern (see README).
]]
local ADDON_NAME, ns = ...

ns.data.pets.HUNTER = {
	tips = {
		"Keep your pet Happy: +25% damage when Happy, -25% when Unhappy. Carry food it likes.",
		"Want max DPS? Use a pet with two focus dumps (Bite + Claw). Single-ability pets underperform.",
		"All pets have Growl (threat) and Cower (drop threat). Keep Growl on while solo so it tanks.",
	},
	phases = {
		{
			band = {10, 20}, title = "Levels 10–20 — first pet",
			pick = "Cat or Raptor (Bite + Claw) for top DPS; Boar (Charge) if you want a tankier, safer leveler.",
			where = "Tame at level 10 from the Hunter trainer quest. Cats/raptors/boars are in most starting zones.",
		},
		{
			band = {20, 50}, title = "Levels 20–50 — keep it simple",
			pick = "Stick with Cat/Raptor for fastest kills, or a Boar for survivability. Grab a Wolf (Furious Howl) if you dungeon a lot.",
			where = "Wolf's Furious Howl buffs the whole party's next physical attack — great in groups.",
		},
		{
			band = {61, 70}, title = "Levels 61+ — the big upgrade: Ravager",
			pick = "Tame a Ravager — its Gore ability is the best leveling focus dump and stays strong to 70.",
			where = "Tame Quillfang Skitterer (lvl 62–63) in Hellfire Peninsula. Wind Serpent (Lightning Breath, ignores armor) overtakes it once you're geared at 70.",
		},
	},
}
