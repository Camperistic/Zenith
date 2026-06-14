--[[ Data/Rotations/Hunter_BM.lua

     Beast Mastery Hunter DPS rotation/shot-priority for TBC Classic.
     The RotationHelper walks `priority` top-down each update and suggests the
     first ability that is (a) learned at the player's level, (b) off cooldown /
     resource-available, and (c) condition-satisfied.

     Each entry:
       spell    English spell name (matched via GetSpellInfo; rank-agnostic)
       minLevel level the ability (or its first meaningful rank) is learned
       cond     optional function(ctx) -> bool   extra gating
       note     short reason shown in the helper
     ctx fields: level, mana (0-1), petActive, lastCrit (bool), targetExists

     Sources: Icy-Veins, Wowhead, Warcraft Tavern, wowtbc.gg (see README).
]]
local ADDON_NAME, ns = ...

local priority = {
	{ spell = "Kill Command", minLevel = 66, cond = function(c) return c.petActive and c.lastCrit end,
		note = "Off-GCD; fire after every ranged crit." },
	{ spell = "Bestial Wrath", minLevel = 40, cond = function(c) return c.petActive end,
		note = "Burst cooldown — pop on elites/rares (with The Beast Within it buffs you too)." },
	{ spell = "Serpent Sting", minLevel = 4, note = "Keep the DoT up — cheap, high value." },
	{ spell = "Multi-Shot", minLevel = 18, note = "Highest damage-per-cast; use on cooldown even on 1 target." },
	{ spell = "Arcane Shot", minLevel = 6, cond = function(c) return c.mana > 0.30 end,
		note = "On cooldown while mana allows." },
	{ spell = "Steady Shot", minLevel = 62, note = "Weave between auto-shots — never clip the swing." },
	{ spell = "Auto Shot", minLevel = 1, note = "Core damage; everything is built around its swing timer." },
}

-- AoE / multi-pull priority (3+ targets).
local aoe = {
	{ spell = "Explosive Trap", minLevel = 34, cond = function(c) return c.targets and c.targets >= 7 end,
		note = "Mass AoE — only worth it on ~7+ targets (can be set in combat)." },
	{ spell = "Multi-Shot", minLevel = 18, note = "Primary multi-target tool — on cooldown." },
	{ spell = "Volley", minLevel = 40, cond = function(c) return c.targets and c.targets >= 10 end,
		note = "Only on huge 10+ packs when Trap & Multi-Shot are down." },
	{ spell = "Serpent Sting", minLevel = 4, note = "Spread the DoT on priority targets." },
	{ spell = "Steady Shot", minLevel = 62, note = "Filler between autos." },
	{ spell = "Auto Shot", minLevel = 1, note = "Let the pet hold threat; you stand at range." },
}

ns.data.rotations.HUNTER = ns.data.rotations.HUNTER or {}
ns.data.rotations.HUNTER.BM = {
	key = "BM",
	priority = priority,
	aoe = aoe,
	aspects = {
		"Aspect of the Hawk: default in combat (max ranged damage).",
		"Aspect of the Viper (64+): swap below ~30% mana to regen; back to Hawk when topped off.",
		"Aspect of the Cheetah: between pulls for movement.",
	},
	openers = {
		"Pre-62: Auto Shot → Serpent Sting → Arcane Shot → Multi-Shot on CD. Let the pet tank.",
		"62+: Auto → Steady weave; insert Kill Command (after crits), Multi-Shot & Arcane on cooldown without clipping autos.",
	},
}
ns.data.rotations.HUNTER.default = "BM"
