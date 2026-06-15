--[[ Data/Classes/Rogue.lua — Combat (Swords) leveling (TBC Classic). Final ~15/41/5.
     Sources: Icy-Veins, Wowhead, Warcraft Tavern, wowtbc.gg (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.ROGUE = {
	default = "COMBAT",
	COMBAT = {
		key = "COMBAT", specName = "Combat Swords", finalSpec = "15 / 41 / 5",
		summary = "Sinister Strike → Slice and Dice uptime → Eviscerate. Blade Flurry at 30 for double-pulls; Adrenaline Rush & Surprise Attacks late.",
		order = U.TalentPath({
			{ tree="Assassination", talent="Malice", n=5, note="+5% crit." },
			{ tree="Assassination", talent="Improved Sinister Strike", n=2, note="Cheaper builder." },
			{ tree="Assassination", talent="Ruthlessness", n=3 },
			{ tree="Assassination", talent="Lethality", n=5, note="+crit damage on builders." },
			-- Combat tree
			{ tree="Combat", talent="Precision", n=5, note="+5% hit — huge leveling consistency." },
			{ tree="Combat", talent="Improved Slice and Dice", n=3, note="Longer SnD uptime." },
			{ tree="Combat", talent="Blade Flurry", n=1, spike=true, note="POWER SPIKE — cleave; melt double-pulls." },
			{ tree="Combat", talent="Dual Wield Specialization", n=5, note="+off-hand damage." },
			{ tree="Combat", talent="Lightning Reflexes", n=5 },
			{ tree="Combat", talent="Aggression", n=3, note="+Sinister Strike/Eviscerate damage." },
			{ tree="Combat", talent="Vitality", n=3 },
			{ tree="Combat", talent="Adrenaline Rush", n=1, spike=true, note="POWER SPIKE — +100% energy regen cooldown." },
			{ tree="Combat", talent="Sword Specialization", n=5, note="Free extra swings — big sustained DPS." },
			{ tree="Combat", talent="Weapon Expertise", n=2 },
			{ tree="Combat", talent="Combat Potency", n=5, note="Off-hand procs return energy." },
			{ tree="Combat", talent="Endurance", n=2 },
			{ tree="Combat", talent="Surprise Attacks", n=1, spike=true, note="CAPSTONE — finishers can't be dodged." },
			{ tree="Subtlety", talent="Opportunity", n=5 },
		}),
	},
}

ns.data.rotations.ROGUE = {
	default = "COMBAT",
	COMBAT = {
		key = "COMBAT",
		priority = {
			{ spell="Slice and Dice", minLevel=10, note="Top priority — keep ~100% uptime." },
			{ spell="Eviscerate", minLevel=1, cond=function(c) return c.targetHP < 0.35 end, note="Dump 5 combo points to finish." },
			{ spell="Blade Flurry", minLevel=30, note="On cooldown vs 2+ targets / tough mobs." },
			{ spell="Sinister Strike", minLevel=1, note="Primary combo builder (from the front)." },
		},
		openers = {
			"Stealth → Ambush/Cheap Shot → Sinister Strike → Slice and Dice early → rebuild → Eviscerate at 5 CP.",
			"Don't cap energy and don't let Slice and Dice drop.",
		},
		notes = {
			"Poisons: Instant Poison main-hand (slow), Instant/Deadly off-hand (fast = more procs & Combat Potency energy).",
			"Blade Flurry on cooldown for double-pulls; Adrenaline Rush for elites.",
		},
	},
}
