--[[ Data/Classes/Paladin.lua — Retribution leveling (TBC Classic). Final ~17/0/44.
     Alliance, plus Blood Elf (Horde). Sources: Icy-Veins, Wowhead, wowtbc.gg (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.PALADIN = {
	default = "RET",
	RET = {
		key = "RET", specName = "Retribution", finalSpec = "17 / 0 / 44",
		summary = "Seal of Command + Judgement on a slow 2H. Crusader Strike at the 41-point capstone (~50). Sanctity Aura, Crusade, and Vengeance drive the damage.",
		order = U.TalentPath({
			{ tree="Retribution", talent="Benediction", n=5, note="Cheaper Seals/Judgement — smooths mana." },
			{ tree="Retribution", talent="Improved Judgement", n=2, note="Lower Judgement cooldown." },
			{ tree="Retribution", talent="Deflection", n=5 },
			{ tree="Retribution", talent="Seal of Command", n=1, spike=true, note="POWER SPIKE — main leveling seal (scales with slow 2H)." },
			{ tree="Retribution", talent="Conviction", n=5, note="+melee crit." },
			{ tree="Retribution", talent="Sanctity Aura", n=1, spike=true, note="POWER SPIKE — +10% Holy damage aura." },
			{ tree="Retribution", talent="Crusade", n=3, spike=true, note="POWER SPIKE — +3% damage vs nearly all Outland mobs." },
			{ tree="Retribution", talent="Two-Handed Weapon Specialization", n=3, note="+6% damage with a 2H." },
			{ tree="Retribution", talent="Sanctified Judgement", n=3, note="Mana back on Judgement." },
			{ tree="Retribution", talent="Vengeance", n=5, spike=true, note="POWER SPIKE — stacking +damage on crit." },
			{ tree="Retribution", talent="Sanctified Seals", n=3 },
			{ tree="Retribution", talent="Repentance", n=1, note="CC for dangerous pulls." },
			{ tree="Retribution", talent="Eye for an Eye", n=2 },
			{ tree="Retribution", talent="Improved Retribution Aura", n=2 },
			{ tree="Retribution", talent="Vindication", n=1 },
			{ tree="Retribution", talent="Fanaticism", n=1 },
			{ tree="Retribution", talent="Crusader Strike", n=1, spike=true, note="CAPSTONE (~50) — instant strike, refreshes Judgement." },
			-- Holy backfill (mana/healing utility)
			{ tree="Holy", talent="Divine Strength", n=5, note="+Strength." },
			{ tree="Holy", talent="Improved Blessing of Might", n=5 },
			{ tree="Holy", talent="Healing Light", n=3 },
			{ tree="Holy", talent="Divine Intellect", n=4, note="+Intellect for mana." },
		}),
	},
}

ns.data.rotations.PALADIN = {
	default = "RET",
	RET = {
		key = "RET",
		priority = {
			{ spell="Hammer of Wrath", minLevel=44, cond=function(c) return c.targetHP < 0.2 end, note="Execute below 20%." },
			{ spell="Crusader Strike", minLevel=50, note="On cooldown — refreshes Judgement window." },
			{ spell="Judgement", minLevel=4, note="On cooldown when mana allows, then re-apply your Seal." },
			{ spell="Consecration", minLevel=20, cond=function(c) return c.mana > 0.5 end, note="AoE grinding / pulling packs (mana-hungry)." },
		},
		openers = {
			"Buff Blessing of Might + Sanctity Aura (Retribution Aura before 30). Seal of Command up.",
			"Judgement → re-cast Seal of Command (Judgement consumes the seal). That twist is most of your damage.",
		},
		notes = {
			"Use a slow 2H for bigger Seal of Command procs.",
			"Judgement of Wisdom for mana return on long fights; Judgement of Light for self-healing.",
		},
	},
}
