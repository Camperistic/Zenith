--[[ Data/Classes/Druid.lua — Feral (cat) leveling (TBC Classic). Final ~0/47/14.
     Cat for solo speed, bear for tanking — no respec. Sources: Icy-Veins, Wowhead, wowtbc.gg. ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.DRUID = {
	default = "FERAL",
	FERAL = {
		key = "FERAL", specName = "Feral (Cat)", finalSpec = "0 / 47 / 14",
		summary = "Cat-form melee: Mangle/Shred builders → Rip/Ferocious Bite. Heart of the Wild + Leader of the Pack are the mid-game spikes; bear-form for dungeons.",
		order = U.TalentPath({
			{ tree="Feral", talent="Ferocity", n=5, spike=true, note="POWER SPIKE — cheaper Claw/Rake/Maul; massive sustain." },
			{ tree="Feral", talent="Feral Aggression", n=5, note="+Mangle/Maul damage." },
			{ tree="Feral", talent="Feral Instinct", n=3, note="+Shred damage." },
			{ tree="Feral", talent="Brutal Impact", n=2 },
			{ tree="Feral", talent="Thick Hide", n=3, note="Armor / survivability." },
			{ tree="Feral", talent="Sharpened Claws", n=3, spike=true, note="POWER SPIKE — +crit in forms." },
			{ tree="Feral", talent="Shredding Attacks", n=2, note="Cheaper Shred & Rip." },
			{ tree="Feral", talent="Predatory Strikes", n=3, note="+AP scaling — unlocks Mangle tier." },
			{ tree="Feral", talent="Primal Fury", n=2, note="Extra combo point on crit." },
			{ tree="Feral", talent="Savage Fury", n=2, note="+Claw/Rake/Mangle/Shred damage." },
			{ tree="Feral", talent="Faerie Fire (Feral)", n=1, note="Armor debuff + ranged pull." },
			{ tree="Feral", talent="Heart of the Wild", n=5, spike=true, note="POWER SPIKE — +20% AP in cat; top leveling DPS talent." },
			{ tree="Feral", talent="Leader of the Pack", n=1, spike=true, note="POWER SPIKE — +5% crit aura." },
			{ tree="Feral", talent="Improved Leader of the Pack", n=2, note="Crits heal & restore mana — strong sustain." },
			{ tree="Feral", talent="Mangle", n=1, spike=true, note="MAJOR SPIKE — top combo-builder + 30% bleed amp." },
			{ tree="Feral", talent="Survival of the Fittest", n=3, note="+stats, crit immunity (tanking)." },
			{ tree="Feral", talent="Predatory Instincts", n=4 },
			-- Restoration dip for powershifting/sustain
			{ tree="Restoration", talent="Furor", n=5, note="Full energy on shift — powershifting." },
			{ tree="Restoration", talent="Naturalist", n=5, note="+physical damage." },
			{ tree="Restoration", talent="Omen of Clarity", n=1, spike=true, note="POWER SPIKE — free attacks (Clearcasting)." },
			{ tree="Restoration", talent="Natural Shapeshifter", n=3, note="Cheaper shapeshifting." },
		}),
	},
}

ns.data.rotations.DRUID = {
	default = "FERAL",
	FERAL = {
		key = "FERAL",
		priority = {
			{ spell="Mangle (Cat)", minLevel=40, note="Keep the 30% bleed-amp debuff up." },
			{ spell="Tiger's Fury", minLevel=20, cond=function(c) return c.mana > 0.3 end, note="+attack power; on cooldown when energy allows." },
			{ spell="Rip", minLevel=20, cond=function(c) return c.targetHP > 0.35 end, note="Finisher at 4–5 CP on mobs that survive it." },
			{ spell="Ferocious Bite", minLevel=32, cond=function(c) return c.targetHP < 0.35 end, note="Finisher on low-HP mobs." },
			{ spell="Shred", minLevel=22, note="Builder (from behind)." },
			{ spell="Claw", minLevel=20, note="Builder when you can't get behind." },
		},
		openers = {
			"Stealth → Prowl → Pounce (stun) → Shred during the stun.",
			"Builders: Mangle to keep the bleed amp up → Shred (behind) / Rake to 5 CP → Rip or Ferocious Bite.",
		},
		notes = {
			"Energy regen is fixed — don't cap combo points; stay behind the target for Shred.",
			"Swap to Dire Bear Form for dungeons / heavy pulls (Mangle, Maul, Swipe). No respec needed.",
		},
	},
}
