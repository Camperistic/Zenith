--[[ Data/Classes/Mage.lua — Frost (AoE-grind) leveling (TBC Classic). Final ~48/0/13.
     Sources: Icy-Veins, Wowhead, Warcraft Tavern (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.MAGE = {
	default = "FROST",
	FROST = {
		key = "FROST", specName = "Frost", finalSpec = "48 / 0 / 13",
		summary = "Frost: safe single-target early, then AoE-grind with Blizzard + Frost Nova kiting (Improved Blizzard at ~22, Ice Barrier at 40). Minor Arcane dip for mana.",
		order = U.TalentPath({
			{ tree="Frost", talent="Improved Frostbolt", n=5, note="Biggest early DPS — faster Frostbolt." },
			{ tree="Frost", talent="Elemental Precision", n=3, note="Fewer resists." },
			{ tree="Frost", talent="Ice Shards", n=5, note="Frost crit damage." },
			{ tree="Frost", talent="Improved Blizzard", n=3, spike=true, note="POWER SPIKE — slow on Blizzard unlocks AoE grinding." },
			{ tree="Frost", talent="Improved Frost Nova", n=2 },
			{ tree="Frost", talent="Permafrost", n=3 },
			{ tree="Frost", talent="Piercing Ice", n=3, note="+6% Frost damage." },
			{ tree="Frost", talent="Frost Channeling", n=3, note="Cheaper Frost spells." },
			{ tree="Frost", talent="Icy Veins", n=1, spike=true, note="POWER SPIKE — +cast speed cooldown." },
			{ tree="Frost", talent="Cold Snap", n=1, note="Resets Frost cooldowns." },
			{ tree="Frost", talent="Shatter", n=5, spike=true, note="POWER SPIKE — +50% crit on frozen targets." },
			{ tree="Frost", talent="Arctic Reach", n=2, note="+range/radius — kite bigger packs safely." },
			{ tree="Frost", talent="Improved Cone of Cold", n=3 },
			{ tree="Frost", talent="Ice Barrier", n=1, spike=true, note="POWER SPIKE — absorb shield makes AoE farming safe." },
			{ tree="Frost", talent="Winter's Chill", n=5 },
			{ tree="Frost", talent="Summon Water Elemental", n=1, spike=true, note="Pet burst + extra Freeze for AoE." },
			-- Arcane dip for sustain
			{ tree="Arcane", talent="Arcane Subtlety", n=2 },
			{ tree="Arcane", talent="Arcane Concentration", n=5, note="Clearcasting procs — free spells." },
			{ tree="Arcane", talent="Arcane Meditation", n=3, note="Mana regen while casting." },
			{ tree="Arcane", talent="Arcane Instability", n=3, note="+damage & +crit." },
			{ tree="Arcane", talent="Arcane Mind", n=2, note="+Intellect." },
		}),
	},
}

ns.data.rotations.MAGE = {
	default = "FROST",
	FROST = {
		key = "FROST",
		priority = {
			{ spell="Frost Nova", minLevel=10, cond=function(c) return c.targetHP < 0.9 end, note="Root, then step back (AoE & single-target kite)." },
			{ spell="Cone of Cold", minLevel=26, cond=function(c) return c.targetHP < 0.3 end, note="Finisher / re-slow." },
			{ spell="Frostbolt", minLevel=4, cond=function(c) return c.mana > 0.15 end, note="Bread-and-butter nuke." },
			{ spell="Shoot", minLevel=5, note="Wand to conserve mana on low-HP mobs." },
		},
		openers = {
			"Single target: Frostbolt spam; Frost Nova → step back if it reaches you; wand to finish.",
			"AoE grind (22+): gather pack → Frost Nova → back up → Blizzard ×2 → re-Nova → Cone of Cold to finish. Ice Barrier up first (40+).",
		},
		notes = {
			"Conjure Water/Food to drink between pulls — your main downtime tool. Evocation off cooldown.",
			"AoE build: do NOT take Frostbite (random roots scatter packs out of Blizzard).",
		},
	},
}
