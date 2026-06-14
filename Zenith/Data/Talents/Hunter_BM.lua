--[[ Data/Talents/Hunter_BM.lua

     Beast Mastery Hunter leveling talent path for TBC Classic (2.5.x).
     Final spec: 41 Beast Mastery / 20 Marksmanship / 0 Survival — the consensus
     "leveling = endgame" build (no respec needed at 70).

     The TalentCoach recommends `order[spentPoints + 1]` as your next point, so the
     list is one entry PER POINT, in the recommended spend order. `level` is the
     character level at which that point becomes available (first point at L10).

     Sources: Icy-Veins, Wowhead, Warcraft Tavern, wowtbc.gg (see README).
]]
local ADDON_NAME, ns = ...

-- tree codes: BM = Beast Mastery, MM = Marksmanship, SV = Survival
local function pt(level, tree, talent, spike, note)
	return { level = level, tree = tree, talent = talent, spike = spike, note = note }
end

local order = {
	-- Tier 1 — ranged damage backbone
	pt(10, "BM", "Improved Aspect of the Hawk"),
	pt(11, "BM", "Improved Aspect of the Hawk"),
	pt(12, "BM", "Improved Aspect of the Hawk"),
	pt(13, "BM", "Improved Aspect of the Hawk"),
	pt(14, "BM", "Improved Aspect of the Hawk", false, "5/5 — your core ranged haste proc."),
	-- QoL: cheaper, faster pet rezzes while leveling
	pt(15, "BM", "Improved Revive Pet"),
	pt(16, "BM", "Improved Revive Pet"),
	-- Pet damage
	pt(17, "BM", "Unleashed Fury"),
	pt(18, "BM", "Unleashed Fury"),
	pt(19, "BM", "Unleashed Fury"),
	pt(20, "BM", "Unleashed Fury"),
	pt(21, "BM", "Unleashed Fury", false, "5/5 — +20% pet damage."),
	-- Pet crit
	pt(22, "BM", "Ferocity"),
	pt(23, "BM", "Ferocity"),
	pt(24, "BM", "Ferocity"),
	pt(25, "BM", "Ferocity"),
	pt(26, "BM", "Ferocity", false, "5/5 — pet crit chance."),
	-- Frenzy (attack-speed snowball after pet crits)
	pt(27, "BM", "Frenzy"),
	pt(28, "BM", "Frenzy"),
	pt(29, "BM", "Frenzy"),
	-- POWER SPIKE: Intimidation at 30
	pt(30, "BM", "Intimidation", true, "POWER SPIKE — pet stun: threat reset, CC, pull control."),
	pt(31, "BM", "Frenzy"),
	pt(32, "BM", "Frenzy", false, "5/5 — near-permanent pet attack-speed buff."),
	-- Solo sustain
	pt(33, "BM", "Spirit Bond"),
	pt(34, "BM", "Spirit Bond", false, "2/2 — passive HP regen for you AND pet; huge for solo."),
	pt(35, "BM", "Bestial Discipline"),
	pt(36, "BM", "Bestial Discipline", false, "pet focus regen — keeps Kill Command/abilities flowing."),
	pt(37, "BM", "Ferocious Inspiration"),
	pt(38, "BM", "Catlike Reflexes"),
	pt(39, "BM", "Catlike Reflexes"),
	-- POWER SPIKE: Bestial Wrath
	pt(40, "BM", "Bestial Wrath", true, "POWER SPIKE — pet burst cooldown; melts elites & rare spawns."),
	pt(41, "BM", "Catlike Reflexes"),
	pt(42, "BM", "Animal Handler"),
	pt(43, "BM", "Animal Handler"),
	-- POWER SPIKE: Serpent's Swiftness
	pt(44, "BM", "Serpent's Swiftness", true, "POWER SPIKE — +20% ranged & pet attack speed."),
	pt(45, "BM", "Serpent's Swiftness"),
	pt(46, "BM", "Serpent's Swiftness"),
	pt(47, "BM", "Serpent's Swiftness"),
	pt(48, "BM", "Serpent's Swiftness", false, "5/5."),
	pt(49, "BM", "Go for the Throat"),
	pt(50, "BM", "Go for the Throat", false, "your crits give the pet focus → more Kill Commands."),
	-- POWER SPIKE: 41-pt capstone
	pt(51, "BM", "The Beast Within", true, "CAPSTONE — Bestial Wrath now buffs YOU: +10% dmg, -10% dmg taken, CC immunity, -20% mana."),
	-- Dip into Marksmanship for personal ranged damage (20 points)
	pt(52, "MM", "Lethal Shots"),
	pt(53, "MM", "Lethal Shots"),
	pt(54, "MM", "Lethal Shots"),
	pt(55, "MM", "Lethal Shots"),
	pt(56, "MM", "Lethal Shots", false, "5/5 — +5% ranged crit."),
	pt(57, "MM", "Efficiency"),
	pt(58, "MM", "Efficiency"),
	pt(59, "MM", "Efficiency"),
	pt(60, "MM", "Efficiency"),
	pt(61, "MM", "Efficiency", false, "5/5 — -20% shot mana cost; big for leveling sustain."),
	pt(62, "MM", "Improved Arcane Shot"),
	pt(63, "MM", "Improved Arcane Shot"),
	pt(64, "MM", "Improved Arcane Shot", false, "3/3."),
	pt(65, "MM", "Improved Hunter's Mark"),
	pt(66, "MM", "Improved Hunter's Mark"),
	pt(67, "MM", "Improved Hunter's Mark", false, "3/3 — party-wide AP from your mark."),
	pt(68, "MM", "Mortal Shots"),
	pt(69, "MM", "Mortal Shots"),
	pt(70, "MM", "Mortal Shots", false, "ranged crit damage — finish the MM crit package."),
}

ns.data.talents.HUNTER = ns.data.talents.HUNTER or {}
ns.data.talents.HUNTER.BM = {
	key       = "BM",
	specName  = "Beast Mastery",
	finalSpec = "41 / 20 / 0",
	summary   = "Leveling = endgame. Pet-centric: max pet damage & survival, then dip Marksmanship for personal ranged crit. No respec needed at 70.",
	order     = order,
}

-- Default leveling spec for the Hunter route.
ns.data.talents.HUNTER.default = "BM"
