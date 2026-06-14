--[[ Data/Classes/Priest.lua — Shadow leveling (TBC Classic). Final ~5/0/56.
     Sources: Icy-Veins, Wowhead, Warcraft Tavern (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.PRIEST = {
	default = "SHADOW",
	SHADOW = {
		key = "SHADOW", specName = "Shadow", finalSpec = "5 / 0 / 56",
		summary = "Spirit Tap removes downtime; Shadowform at 40 is the big spike. DoT + Mind Blast/Mind Flay, wand to finish.",
		order = U.TalentPath({
			{ tree="Shadow", talent="Spirit Tap", n=5, spike=true, note="POWER SPIKE — huge mana sustain after kills." },
			{ tree="Shadow", talent="Improved Spirit Tap", n=2 },
			{ tree="Shadow", talent="Shadow Focus", n=5, note="+shadow hit, fewer resists." },
			{ tree="Shadow", talent="Improved Shadow Word: Pain", n=2 },
			{ tree="Shadow", talent="Improved Mind Blast", n=5, note="Lower Mind Blast cooldown." },
			{ tree="Shadow", talent="Mind Flay", n=1, spike=true, note="POWER SPIKE — spammable filler + 50% slow." },
			{ tree="Shadow", talent="Veiled Shadows", n=2 },
			{ tree="Shadow", talent="Vampiric Embrace", n=1, spike=true, note="POWER SPIKE — shadow damage heals you; kills downtime." },
			{ tree="Shadow", talent="Shadow Reach", n=2 },
			{ tree="Shadow", talent="Shadow Weaving", n=5, note="Stacking +shadow damage taken." },
			{ tree="Shadow", talent="Shadowform", n=1, spike=true, note="MAJOR SPIKE at 40 — +15% shadow dmg, -15% physical taken." },
			{ tree="Shadow", talent="Shadow Power", n=5, note="+Mind Blast/SW:Death crit damage." },
			{ tree="Shadow", talent="Improved Vampiric Embrace", n=2 },
			{ tree="Shadow", talent="Focused Mind", n=3, note="Cheaper Mind spells." },
			{ tree="Shadow", talent="Darkness", n=5, note="+10% shadow damage." },
			{ tree="Shadow", talent="Vampiric Touch", n=1, spike=true, note="POWER SPIKE — mana-battery DoT." },
			{ tree="Shadow", talent="Misery", n=3, note="+hit & +spell damage taken on target." },
			{ tree="Shadow", talent="Blackout", n=5 },
			{ tree="Shadow", talent="Improved Fade", n=1 },
			{ tree="Discipline", talent="Wand Specialization", n=5, note="Faster wand kills." },
		}),
	},
}

ns.data.rotations.PRIEST = {
	default = "SHADOW",
	SHADOW = {
		key = "SHADOW",
		priority = {
			{ spell="Shadow Word: Pain", minLevel=4, note="Keep the DoT up (skip on near-dead mobs)." },
			{ spell="Vampiric Touch", minLevel=50, cond=function(c) return c.mana < 0.7 end, note="Mana battery on tougher fights." },
			{ spell="Mind Blast", minLevel=10, note="On cooldown — core nuke." },
			{ spell="Mind Flay", minLevel=20, cond=function(c) return c.targetHP > 0.25 end, note="Filler + slow; bring mob to wand range." },
			{ spell="Shoot", minLevel=5, cond=function(c) return c.targetHP < 0.3 end, note="Wand to finish & save mana." },
		},
		openers = {
			"Pre-40: SW:Pain → Mind Blast → Mind Flay → wand finish.",
			"Post-40 (Shadowform): SW:Pain → Mind Blast on CD → Mind Flay → wand. Vampiric Embrace on tanky mobs.",
		},
		notes = {
			"Spirit Tap means you rarely drink. Don't refresh SW:Pain on dying mobs.",
			"Mind Flay's slow lets you kite dangerous mobs.",
		},
	},
}
