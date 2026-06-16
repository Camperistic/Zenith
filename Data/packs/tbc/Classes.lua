-- Zenith class-coaching data (TBC). Talent leveling order + rotation priority +
-- gear stat priority, per class. Researched (Wowhead/Icy-Veins/Warcraft Tavern/
-- wowtbc.gg); see CREDITS. Pure data — register via ns.RegisterClass.
local ADDON, ns = ...

-- Expand compact talent groups {tree,talent,n,spike,note} into a per-point list.
local function path(groups)
	local out, lvl = {}, 10
	for _, g in ipairs(groups) do
		for i = 1, (g.n or 1) do
			out[#out + 1] = { level = lvl, talent = g.talent, tree = g.tree,
				spike = g.spike and i == (g.n or 1) or nil, note = (i == (g.n or 1)) and g.note or nil }
			lvl = lvl + 1; if lvl > 70 then return out end
		end
	end
	return out
end
local function hp(f) return f end   -- readability for cond closures

ns.RegisterClass("HUNTER", {
	specName = "Beast Mastery", finalSpec = "41/20/0",
	talents = path({
		{ tree="BM", talent="Improved Aspect of the Hawk", n=5 }, { tree="BM", talent="Improved Revive Pet", n=2 },
		{ tree="BM", talent="Unleashed Fury", n=5, note="+pet damage" }, { tree="BM", talent="Ferocity", n=5 },
		{ tree="BM", talent="Frenzy", n=5 }, { tree="BM", talent="Intimidation", n=1, spike=true, note="POWER SPIKE — pet stun" },
		{ tree="BM", talent="Spirit Bond", n=2 }, { tree="BM", talent="Bestial Discipline", n=2 },
		{ tree="BM", talent="Ferocious Inspiration", n=1 }, { tree="BM", talent="Catlike Reflexes", n=3 },
		{ tree="BM", talent="Bestial Wrath", n=1, spike=true, note="POWER SPIKE" }, { tree="BM", talent="Animal Handler", n=2 },
		{ tree="BM", talent="Serpent's Swiftness", n=5, spike=true, note="POWER SPIKE — +20% attack speed" },
		{ tree="BM", talent="Go for the Throat", n=2 }, { tree="BM", talent="The Beast Within", n=1, spike=true, note="CAPSTONE" },
		{ tree="MM", talent="Lethal Shots", n=5 }, { tree="MM", talent="Efficiency", n=5 },
		{ tree="MM", talent="Improved Arcane Shot", n=3 }, { tree="MM", talent="Improved Hunter's Mark", n=3 },
		{ tree="MM", talent="Mortal Shots", n=3 },
	}),
	rotation = { priority = {
		{ spell="Kill Command", minLevel=66, note="Off-GCD after a ranged crit" },
		{ spell="Bestial Wrath", minLevel=40, cond=hp(function(c) return c.petActive end), note="Burst CD" },
		{ spell="Serpent Sting", minLevel=4, note="Keep the DoT up" },
		{ spell="Multi-Shot", minLevel=18, note="On cooldown" },
		{ spell="Arcane Shot", minLevel=6, cond=hp(function(c) return c.mana > 0.3 end) },
		{ spell="Steady Shot", minLevel=62, note="Weave; don't clip Auto Shot" },
		{ spell="Auto Shot", minLevel=1 },
	} },
	gear = { statPriority = "Agility > Attack Power > Stamina",
		notes = { "Best leveling pet: Cat/Boar early, Ravager (Gore) at 61+.", "Slow ranged weapon = bigger hits. Train Mail at 40." } },
})

ns.RegisterClass("WARRIOR", {
	specName = "Arms", finalSpec = "33/28/0",
	talents = path({
		{ tree="Arms", talent="Improved Heroic Strike", n=3 }, { tree="Arms", talent="Improved Charge", n=2 },
		{ tree="Arms", talent="Tactical Mastery", n=3 }, { tree="Arms", talent="Deep Wounds", n=3 },
		{ tree="Arms", talent="Anger Management", n=1 }, { tree="Arms", talent="Two-Handed Weapon Specialization", n=5 },
		{ tree="Arms", talent="Impale", n=2 }, { tree="Arms", talent="Improved Overpower", n=2 },
		{ tree="Arms", talent="Deflection", n=5 }, { tree="Arms", talent="Death Wish", n=1, spike=true, note="POWER SPIKE" },
		{ tree="Arms", talent="Mortal Strike", n=1, spike=true, note="DEFINING ABILITY" }, { tree="Arms", talent="Improved Slam", n=2 },
		{ tree="Fury", talent="Cruelty", n=5 }, { tree="Fury", talent="Unbridled Wrath", n=5 },
		{ tree="Fury", talent="Booming Voice", n=2 }, { tree="Fury", talent="Improved Battle Shout", n=5 },
		{ tree="Fury", talent="Enrage", n=5 }, { tree="Fury", talent="Flurry", n=5, spike=true, note="POWER SPIKE" },
		{ tree="Fury", talent="Improved Execute", n=2 }, { tree="Fury", talent="Blood Craze", n=1 },
		{ tree="Arms", talent="Sweeping Strikes", n=1 },
	}),
	rotation = { priority = {
		{ spell="Execute", minLevel=24, cond=hp(function(c) return c.targetHP < 0.2 end), note="Below 20%" },
		{ spell="Mortal Strike", minLevel=40, note="On cooldown" },
		{ spell="Overpower", minLevel=14, note="When target dodges (Battle Stance)" },
		{ spell="Whirlwind", minLevel=36, note="On cooldown (Berserker)" },
		{ spell="Rend", minLevel=4, cond=hp(function(c) return c.level < 40 end) },
		{ spell="Heroic Strike", minLevel=1, note="Rage dump" },
	} },
	gear = { statPriority = "Strength > Crit > Hit > Attack Power", notes = { "Train Plate at 40. Use the slowest 2H you can." } },
})

ns.RegisterClass("MAGE", {
	specName = "Frost", finalSpec = "48/0/13",
	talents = path({
		{ tree="Frost", talent="Improved Frostbolt", n=5 }, { tree="Frost", talent="Elemental Precision", n=3 },
		{ tree="Frost", talent="Ice Shards", n=5 }, { tree="Frost", talent="Improved Blizzard", n=3, spike=true, note="AoE grinding" },
		{ tree="Frost", talent="Piercing Ice", n=3 }, { tree="Frost", talent="Frost Channeling", n=3 },
		{ tree="Frost", talent="Icy Veins", n=1, spike=true }, { tree="Frost", talent="Shatter", n=5, spike=true },
		{ tree="Frost", talent="Ice Barrier", n=1, spike=true, note="POWER SPIKE" }, { tree="Frost", talent="Arctic Reach", n=2 },
		{ tree="Frost", talent="Winter's Chill", n=5 }, { tree="Frost", talent="Summon Water Elemental", n=1, spike=true },
		{ tree="Arcane", talent="Arcane Concentration", n=5 }, { tree="Arcane", talent="Arcane Meditation", n=3 },
		{ tree="Arcane", talent="Arcane Instability", n=3 }, { tree="Arcane", talent="Arcane Mind", n=2 },
	}),
	rotation = { priority = {
		{ spell="Frost Nova", minLevel=10, cond=hp(function(c) return c.targetHP < 0.9 end), note="Root, step back" },
		{ spell="Cone of Cold", minLevel=26, cond=hp(function(c) return c.targetHP < 0.3 end) },
		{ spell="Frostbolt", minLevel=4, cond=hp(function(c) return c.mana > 0.15 end) },
		{ spell="Shoot", minLevel=5, note="Wand to conserve mana" },
	} },
	gear = { statPriority = "Spell Hit > Frost Spell Power > Crit > Intellect", notes = { "Conjure water; AoE-grind with Blizzard + Frost Nova." } },
})

ns.RegisterClass("WARLOCK", {
	specName = "Demonology (Felguard)", finalSpec = "0/41/20",
	talents = path({
		{ tree="Demo", talent="Improved Imp", n=3 }, { tree="Demo", talent="Demonic Embrace", n=5, spike=true },
		{ tree="Demo", talent="Fel Intellect", n=3 }, { tree="Demo", talent="Improved Voidwalker", n=3 },
		{ tree="Demo", talent="Fel Stamina", n=3 }, { tree="Demo", talent="Fel Domination", n=1, spike=true },
		{ tree="Demo", talent="Master Summoner", n=2 }, { tree="Demo", talent="Unholy Power", n=5 },
		{ tree="Demo", talent="Demonic Sacrifice", n=1 }, { tree="Demo", talent="Master Demonologist", n=5 },
		{ tree="Demo", talent="Soul Link", n=1, spike=true }, { tree="Demo", talent="Demonic Knowledge", n=3 },
		{ tree="Demo", talent="Demonic Tactics", n=5 }, { tree="Demo", talent="Summon Felguard", n=1, spike=true, note="CAPSTONE @50" },
		{ tree="Destro", talent="Improved Shadow Bolt", n=5 }, { tree="Destro", talent="Bane", n=5 },
		{ tree="Destro", talent="Devastation", n=5 }, { tree="Destro", talent="Improved Immolate", n=3 }, { tree="Destro", talent="Cataclysm", n=2 },
	}),
	rotation = { priority = {
		{ spell="Corruption", minLevel=4, note="Instant DoT" }, { spell="Curse of Agony", minLevel=8 },
		{ spell="Immolate", minLevel=10 }, { spell="Siphon Life", minLevel=30 },
		{ spell="Drain Soul", minLevel=8, cond=hp(function(c) return c.targetHP < 0.25 end), note="Killing blow" },
		{ spell="Shadow Bolt", minLevel=1, cond=hp(function(c) return c.mana > 0.2 end) },
		{ spell="Life Tap", minLevel=6, cond=hp(function(c) return c.mana < 0.2 end) },
	} },
	gear = { statPriority = "Shadow Spell Power > Spell Hit > Stamina > Intellect", notes = { "Voidwalker drain-tank 1-49, Felguard from 50." } },
})

ns.RegisterClass("PRIEST", {
	specName = "Shadow", finalSpec = "5/0/56",
	talents = path({
		{ tree="Shadow", talent="Spirit Tap", n=5, spike=true }, { tree="Shadow", talent="Improved Spirit Tap", n=2 },
		{ tree="Shadow", talent="Shadow Focus", n=5 }, { tree="Shadow", talent="Improved Shadow Word: Pain", n=2 },
		{ tree="Shadow", talent="Improved Mind Blast", n=5 }, { tree="Shadow", talent="Mind Flay", n=1, spike=true },
		{ tree="Shadow", talent="Veiled Shadows", n=2 }, { tree="Shadow", talent="Vampiric Embrace", n=1, spike=true },
		{ tree="Shadow", talent="Shadow Reach", n=2 }, { tree="Shadow", talent="Shadow Weaving", n=5 },
		{ tree="Shadow", talent="Shadowform", n=1, spike=true, note="MAJOR SPIKE @40" }, { tree="Shadow", talent="Shadow Power", n=5 },
		{ tree="Shadow", talent="Improved Vampiric Embrace", n=2 }, { tree="Shadow", talent="Focused Mind", n=3 },
		{ tree="Shadow", talent="Darkness", n=5 }, { tree="Shadow", talent="Vampiric Touch", n=1, spike=true },
		{ tree="Shadow", talent="Misery", n=3 }, { tree="Shadow", talent="Blackout", n=5 }, { tree="Shadow", talent="Improved Fade", n=1 },
		{ tree="Disc", talent="Wand Specialization", n=5 },
	}),
	rotation = { priority = {
		{ spell="Shadow Word: Pain", minLevel=4 }, { spell="Vampiric Touch", minLevel=50, cond=hp(function(c) return c.mana < 0.7 end) },
		{ spell="Mind Blast", minLevel=10 }, { spell="Mind Flay", minLevel=20, cond=hp(function(c) return c.targetHP > 0.25 end) },
		{ spell="Shoot", minLevel=5, cond=hp(function(c) return c.targetHP < 0.3 end), note="Wand to finish" },
	} },
	gear = { statPriority = "Spell Hit > Shadow Spell Power > Crit > Spirit", notes = { "Shadowform at 40; Spirit Tap kills downtime." } },
})

ns.RegisterClass("ROGUE", {
	specName = "Combat Swords", finalSpec = "15/41/5",
	talents = path({
		{ tree="Assa", talent="Malice", n=5 }, { tree="Assa", talent="Improved Sinister Strike", n=2 },
		{ tree="Assa", talent="Ruthlessness", n=3 }, { tree="Assa", talent="Lethality", n=5 },
		{ tree="Combat", talent="Precision", n=5 }, { tree="Combat", talent="Improved Slice and Dice", n=3 },
		{ tree="Combat", talent="Blade Flurry", n=1, spike=true, note="POWER SPIKE @30" }, { tree="Combat", talent="Dual Wield Specialization", n=5 },
		{ tree="Combat", talent="Lightning Reflexes", n=5 }, { tree="Combat", talent="Aggression", n=3 },
		{ tree="Combat", talent="Vitality", n=3 }, { tree="Combat", talent="Adrenaline Rush", n=1, spike=true },
		{ tree="Combat", talent="Sword Specialization", n=5 }, { tree="Combat", talent="Weapon Expertise", n=2 },
		{ tree="Combat", talent="Combat Potency", n=5 }, { tree="Combat", talent="Endurance", n=2 },
		{ tree="Combat", talent="Surprise Attacks", n=1, spike=true, note="CAPSTONE" }, { tree="Sub", talent="Opportunity", n=5 },
	}),
	rotation = { priority = {
		{ spell="Slice and Dice", minLevel=10, note="Keep ~100% uptime" },
		{ spell="Eviscerate", minLevel=1, cond=hp(function(c) return c.targetHP < 0.35 end), note="Finisher at 5 CP" },
		{ spell="Blade Flurry", minLevel=30, note="On cooldown vs 2+ / tough" },
		{ spell="Sinister Strike", minLevel=1, note="Builder" },
	} },
	gear = { statPriority = "Agility > Attack Power > Hit > Crit", notes = { "Instant Poison main-hand; fast off-hand for procs." } },
})

ns.RegisterClass("PALADIN", {
	specName = "Retribution", finalSpec = "17/0/44",
	talents = path({
		{ tree="Ret", talent="Benediction", n=5 }, { tree="Ret", talent="Improved Judgement", n=2 },
		{ tree="Ret", talent="Deflection", n=5 }, { tree="Ret", talent="Seal of Command", n=1, spike=true },
		{ tree="Ret", talent="Conviction", n=5 }, { tree="Ret", talent="Sanctity Aura", n=1, spike=true },
		{ tree="Ret", talent="Crusade", n=3, spike=true }, { tree="Ret", talent="Two-Handed Weapon Specialization", n=3 },
		{ tree="Ret", talent="Sanctified Judgement", n=3 }, { tree="Ret", talent="Vengeance", n=5, spike=true },
		{ tree="Ret", talent="Sanctified Seals", n=3 }, { tree="Ret", talent="Repentance", n=1 },
		{ tree="Ret", talent="Eye for an Eye", n=2 }, { tree="Ret", talent="Improved Retribution Aura", n=2 },
		{ tree="Ret", talent="Vindication", n=1 }, { tree="Ret", talent="Fanaticism", n=1 },
		{ tree="Ret", talent="Crusader Strike", n=1, spike=true, note="CAPSTONE ~50" },
		{ tree="Holy", talent="Divine Strength", n=5 }, { tree="Holy", talent="Improved Blessing of Might", n=5 },
		{ tree="Holy", talent="Healing Light", n=3 }, { tree="Holy", talent="Divine Intellect", n=4 },
	}),
	rotation = { priority = {
		{ spell="Hammer of Wrath", minLevel=44, cond=hp(function(c) return c.targetHP < 0.2 end) },
		{ spell="Crusader Strike", minLevel=50, note="On cooldown" },
		{ spell="Judgement", minLevel=4, note="On cooldown, then re-seal" },
		{ spell="Consecration", minLevel=20, cond=hp(function(c) return c.mana > 0.5 end), note="AoE grinding" },
	} },
	gear = { statPriority = "Strength > Crit > Hit > Attack Power", notes = { "Train Plate at 40. Slow 2H + Seal of Command." } },
})

ns.RegisterClass("SHAMAN", {
	specName = "Enhancement", finalSpec = "0/41/20",
	talents = path({
		{ tree="Enh", talent="Ancestral Knowledge", n=5 }, { tree="Enh", talent="Thundering Strikes", n=5 },
		{ tree="Enh", talent="Enhancing Totems", n=2 }, { tree="Enh", talent="Flurry", n=5, spike=true },
		{ tree="Enh", talent="Elemental Weapons", n=3 }, { tree="Enh", talent="Weapon Mastery", n=5 },
		{ tree="Enh", talent="Spirit Weapons", n=1 }, { tree="Enh", talent="Dual Wield", n=1, spike=true },
		{ tree="Enh", talent="Dual Wield Specialization", n=3 }, { tree="Enh", talent="Stormstrike", n=1, spike=true },
		{ tree="Enh", talent="Elemental Devastation", n=3 }, { tree="Enh", talent="Unleashed Rage", n=5 },
		{ tree="Enh", talent="Mental Quickness", n=3 }, { tree="Enh", talent="Shamanistic Rage", n=1, spike=true, note="CAPSTONE" },
		{ tree="Resto", talent="Totemic Focus", n=5 }, { tree="Resto", talent="Nature's Guidance", n=3 },
		{ tree="Resto", talent="Ancestral Healing", n=3 }, { tree="Resto", talent="Restorative Totems", n=5 }, { tree="Resto", talent="Healing Focus", n=4 },
	}),
	rotation = { priority = {
		{ spell="Stormstrike", minLevel=40, note="On cooldown" },
		{ spell="Earth Shock", minLevel=4, cond=hp(function(c) return c.mana > 0.25 end), note="Consume the Nature debuff" },
		{ spell="Flame Shock", minLevel=10, cond=hp(function(c) return c.mana > 0.3 end) },
		{ spell="Searing Totem", minLevel=10, cond=hp(function(c) return c.mana > 0.5 end) },
	} },
	gear = { statPriority = "Attack Power/Agility > Hit > Crit > Intellect", notes = { "Train Mail at 40. Windfury main-hand after Dual Wield." } },
})

ns.RegisterClass("DRUID", {
	specName = "Feral (Cat)", finalSpec = "0/47/14",
	talents = path({
		{ tree="Feral", talent="Ferocity", n=5, spike=true }, { tree="Feral", talent="Feral Aggression", n=5 },
		{ tree="Feral", talent="Feral Instinct", n=3 }, { tree="Feral", talent="Brutal Impact", n=2 },
		{ tree="Feral", talent="Thick Hide", n=3 }, { tree="Feral", talent="Sharpened Claws", n=3, spike=true },
		{ tree="Feral", talent="Shredding Attacks", n=2 }, { tree="Feral", talent="Predatory Strikes", n=3 },
		{ tree="Feral", talent="Primal Fury", n=2 }, { tree="Feral", talent="Savage Fury", n=2 },
		{ tree="Feral", talent="Faerie Fire (Feral)", n=1 }, { tree="Feral", talent="Heart of the Wild", n=5, spike=true },
		{ tree="Feral", talent="Leader of the Pack", n=1, spike=true }, { tree="Feral", talent="Improved Leader of the Pack", n=2 },
		{ tree="Feral", talent="Mangle", n=1, spike=true, note="MAJOR SPIKE" }, { tree="Feral", talent="Survival of the Fittest", n=3 },
		{ tree="Feral", talent="Predatory Instincts", n=4 }, { tree="Resto", talent="Furor", n=5 },
		{ tree="Resto", talent="Naturalist", n=5 }, { tree="Resto", talent="Omen of Clarity", n=1, spike=true }, { tree="Resto", talent="Natural Shapeshifter", n=3 },
	}),
	rotation = { priority = {
		{ spell="Mangle (Cat)", minLevel=40, note="Keep the bleed-amp up" },
		{ spell="Tiger's Fury", minLevel=20, cond=hp(function(c) return c.mana > 0.3 end) },
		{ spell="Rip", minLevel=20, cond=hp(function(c) return c.targetHP > 0.35 end), note="Finisher 4-5 CP" },
		{ spell="Ferocious Bite", minLevel=32, cond=hp(function(c) return c.targetHP < 0.35 end) },
		{ spell="Shred", minLevel=22, note="Builder (from behind)" }, { spell="Claw", minLevel=20 },
	} },
	gear = { statPriority = "Agility > Attack Power > Strength > Crit", notes = { "Cat for solo, bear for dungeons. Feral AP weapon matters most." } },
})
