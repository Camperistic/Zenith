--[[ Data/Classes/Shaman.lua — Enhancement leveling (TBC Classic). Final ~0/41/20.
     Horde, plus Draenei (Alliance). Sources: Icy-Veins, Warcraft Tavern, wowtbc.gg (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.SHAMAN = {
	default = "ENH",
	ENH = {
		key = "ENH", specName = "Enhancement", finalSpec = "0 / 41 / 20",
		summary = "Melee shaman: Windfury weapon, Dual Wield + Stormstrike, Shamanistic Rage. Earth Shock weave and Flurry crit snowball.",
		order = U.TalentPath({
			{ tree="Enhancement", talent="Ancestral Knowledge", n=5, note="+mana." },
			{ tree="Enhancement", talent="Thundering Strikes", n=5, note="+crit (prereq for Flurry)." },
			{ tree="Enhancement", talent="Enhancing Totems", n=2 },
			{ tree="Enhancement", talent="Flurry", n=5, spike=true, note="POWER SPIKE — +30% attack speed after a crit." },
			{ tree="Enhancement", talent="Elemental Weapons", n=3, note="+Windfury/Flametongue." },
			{ tree="Enhancement", talent="Weapon Mastery", n=5, note="+weapon damage." },
			{ tree="Enhancement", talent="Spirit Weapons", n=1, note="Threat reduction (prereq for Dual Wield)." },
			{ tree="Enhancement", talent="Dual Wield", n=1, spike=true, note="POWER SPIKE — equip two 1H weapons." },
			{ tree="Enhancement", talent="Dual Wield Specialization", n=3, note="+off-hand hit/damage." },
			{ tree="Enhancement", talent="Stormstrike", n=1, spike=true, note="POWER SPIKE — instant double-strike + Nature debuff for Earth Shock." },
			{ tree="Enhancement", talent="Elemental Devastation", n=3 },
			{ tree="Enhancement", talent="Unleashed Rage", n=5, note="+AP party buff on crit." },
			{ tree="Enhancement", talent="Mental Quickness", n=3, note="Cheaper instant spells; +spell power from AP." },
			{ tree="Enhancement", talent="Shamanistic Rage", n=1, spike=true, note="CAPSTONE — damage reduction + mana return." },
			-- Restoration backfill
			{ tree="Restoration", talent="Totemic Focus", n=5, note="Cheaper totems." },
			{ tree="Restoration", talent="Nature's Guidance", n=3, note="+hit." },
			{ tree="Restoration", talent="Ancestral Healing", n=3 },
			{ tree="Restoration", talent="Restorative Totems", n=5 },
			{ tree="Restoration", talent="Healing Focus", n=4 },
		}),
	},
}

ns.data.rotations.SHAMAN = {
	default = "ENH",
	ENH = {
		key = "ENH",
		priority = {
			{ spell="Stormstrike", minLevel=40, note="On cooldown — sets up Earth Shock." },
			{ spell="Earth Shock", minLevel=4, cond=function(c) return c.mana > 0.25 end, note="After Stormstrike (consumes Nature debuff); also your interrupt." },
			{ spell="Flame Shock", minLevel=10, cond=function(c) return c.mana > 0.3 end, note="DoT on tougher targets." },
			{ spell="Searing Totem", minLevel=10, cond=function(c) return c.mana > 0.5 end, note="Extra single-target DPS." },
		},
		openers = {
			"Imbue: Rockbiter early → Windfury main-hand (~30) → Flametongue off-hand after Dual Wield.",
			"Stormstrike on cooldown → Earth Shock to consume the Nature debuff. Let auto-attacks/Windfury flow.",
		},
		notes = {
			"Shamanistic Rage (~capstone): mana return + defensive button on dangerous pulls.",
			"Drop totems only when worth it: Searing (DPS), Strength of Earth/Grace of Air (elites), Mana Spring (sustain).",
		},
	},
}
