--[[ Data/Classes/Warrior.lua — Arms leveling (TBC Classic). Final ~33/28/0.
     Sources: Icy-Veins, Wowhead, Warcraft Tavern, wowtbc.gg (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.WARRIOR = {
	default = "ARMS",
	ARMS = {
		key = "ARMS", specName = "Arms", finalSpec = "33 / 28 / 0",
		summary = "2H Arms: Charge in, stance-dance Overpower, Mortal Strike at 40. Strong burst and great with a slow two-hander.",
		order = U.TalentPath({
			{ tree="Arms", talent="Improved Heroic Strike", n=3 },
			{ tree="Arms", talent="Improved Charge", n=2, note="Extra rage on Charge — great leveling burst." },
			{ tree="Arms", talent="Tactical Mastery", n=3, note="Keeps rage across stance swaps." },
			{ tree="Arms", talent="Deep Wounds", n=3, note="Crits apply a bleed." },
			{ tree="Arms", talent="Anger Management", n=1 },
			{ tree="Arms", talent="Two-Handed Weapon Specialization", n=5, note="+5% 2H damage." },
			{ tree="Arms", talent="Impale", n=2 },
			{ tree="Arms", talent="Improved Overpower", n=2 },
			{ tree="Arms", talent="Deflection", n=5 },
			{ tree="Arms", talent="Death Wish", n=1, spike=true, note="POWER SPIKE — +20% damage cooldown." },
			{ tree="Arms", talent="Mortal Strike", n=1, spike=true, note="DEFINING ABILITY — instant strike + healing debuff." },
			{ tree="Arms", talent="Improved Slam", n=2, note="Makes Slam a usable filler." },
			-- Fury support
			{ tree="Fury", talent="Cruelty", n=5, note="+5% melee crit." },
			{ tree="Fury", talent="Unbridled Wrath", n=5 },
			{ tree="Fury", talent="Booming Voice", n=2 },
			{ tree="Fury", talent="Improved Battle Shout", n=5, note="Stronger self AP buff." },
			{ tree="Fury", talent="Enrage", n=5 },
			{ tree="Fury", talent="Flurry", n=5, spike=true, note="POWER SPIKE — haste after a crit." },
			{ tree="Fury", talent="Improved Execute", n=2 },
			{ tree="Fury", talent="Blood Craze", n=1 },
			{ tree="Arms", talent="Sweeping Strikes", n=1, note="Cleave for double-pulls." },
		}),
	},
}

ns.data.rotations.WARRIOR = {
	default = "ARMS",
	ARMS = {
		key = "ARMS",
		priority = {
			{ spell="Execute", minLevel=24, cond=function(c) return c.targetHP < 0.2 end, note="Below 20% — your hardest hit." },
			{ spell="Mortal Strike", minLevel=40, note="On cooldown — core Arms damage." },
			{ spell="Overpower", minLevel=14, note="When the target dodges (Battle Stance)." },
			{ spell="Whirlwind", minLevel=36, note="On cooldown, even single target (Berserker Stance)." },
			{ spell="Rend", minLevel=4, cond=function(c) return c.level < 40 end, note="Early bleed while leveling." },
			{ spell="Heroic Strike", minLevel=1, cond=function(c) return c.mana > 0.4 end, note="Rage dump when you have excess." },
		},
		openers = {
			"Charge (Battle Stance) → Rend → builders. Keep Battle Shout up at all times.",
			"Stance-dance: Battle for Mortal Strike/Overpower; Berserker for Whirlwind/Intercept (Tactical Mastery saves rage).",
		},
		notes = {
			"Use a slow 2H weapon — bigger Mortal Strike & melee hits.",
			"Below 20% HP: spam Execute. Hamstring runners.",
		},
	},
}
