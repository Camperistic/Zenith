--[[ Data/Gear/Generic.lua

     Stat-priority + armor-type gear guidance for every class except Hunter (which
     has a full milestone/BiS dataset in Hunter_Gear.lua). Registered only if a
     class has no detailed gear yet, so Hunter's data is never overwritten.

     These stat priorities and armor-train levels are factual TBC itemization.
     Detailed per-tier item lists are the next data pass (see README roadmap).
]]
local ADDON_NAME, ns = ...

local function ensure(class, def)
	if not ns.data.gear[class] then ns.data.gear[class] = def end
end

local function g(statPriority, notes)
	return { statPriority = statPriority, milestones = {}, notes = notes }
end

ensure("WARRIOR", g("Strength > Crit > Hit > Attack Power > Agility",
	{ "Train Plate at level 40 (any Warrior trainer).",
	  "Use the slowest 2H you can — bigger Mortal Strike & Heroic Strike hits.",
	  "Chase Agility/Strength quest blues; weapon upgrades are your biggest jumps." }))

ensure("PALADIN", g("Strength > Crit > Hit > Attack Power > Stamina/Intellect",
	{ "Train Plate at level 40.",
	  "Slow 2H for Seal of Command/Crusader Strike.",
	  "Some Intellect helps keep Judgement/Consecration flowing." }))

ensure("ROGUE", g("Agility > Attack Power > Hit > Crit",
	{ "Leather all the way. Stack Agility (AP + crit + dodge).",
	  "Main-hand: slower sword for Sinister Strike; off-hand: faster for more poison/Combat Potency procs." }))

ensure("SHAMAN", g("Attack Power / Strength / Agility > Hit > Crit > Intellect",
	{ "Train Mail at level 40.",
	  "Two 1H weapons after Dual Wield; Windfury main-hand. Some Intellect for Shock mana." }))

ensure("DRUID", g("Agility > Attack Power > Strength > Crit > Hit",
	{ "Leather. Cat scales off Agility/AP; your weapon's 'Feral Attack Power' matters most (use a high-DPS staff/2H).",
	  "Stat sticks: feral AP on weapons, Agility on armor." }))

ensure("PRIEST", g("Spell Hit > Shadow Spell Power > Spell Crit > Intellect/Spirit",
	{ "Cloth. Stack Shadow spell power; Spell Hit reduces resists.",
	  "Spirit feeds Spirit Tap regen. A good wand is a real upgrade while leveling." }))

ensure("MAGE", g("Spell Hit > Frost Spell Power > Spell Crit > Intellect",
	{ "Cloth. Stack spell power (frost); Spell Hit cuts resists on higher mobs.",
	  "Intellect for the mana pool to sustain AoE grinding. Keep a good wand." }))

ensure("WARLOCK", g("Shadow Spell Power > Spell Hit > Stamina > Intellect",
	{ "Cloth. Stamina matters a lot — you drain-tank and Life Tap.",
	  "Shadow spell power for your DoTs/Shadow Bolt; a wand helps finish mobs." }))
