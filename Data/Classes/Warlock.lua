--[[ Data/Classes/Warlock.lua — Affliction→Demonology (Felguard) leveling. Final ~0/41/20.
     Level Affliction drain-tanking, then the Felguard carries from ~50.
     Sources: Icy-Veins, Warcraft Tavern (see README). ]]
local ADDON_NAME, ns = ...
local U = ns.U

ns.data.talents.WARLOCK = {
	default = "DEMO",
	DEMO = {
		key = "DEMO", specName = "Demonology (Felguard)", finalSpec = "0 / 41 / 20",
		summary = "DoT + drain-tank with Voidwalker early; the path culminates in Summon Felguard (the carry pet) + Soul Link survivability, with a Destruction dip for Shadow Bolt.",
		order = U.TalentPath({
			-- early Affliction-style sustain often lives in Demo/Aff; this Demo path keeps it simple
			{ tree="Demonology", talent="Improved Imp", n=3 },
			{ tree="Demonology", talent="Demonic Embrace", n=5, spike=true, note="POWER SPIKE — big Stamina for drain-tanking." },
			{ tree="Demonology", talent="Fel Intellect", n=3 },
			{ tree="Demonology", talent="Improved Voidwalker", n=3, note="Tankier pet." },
			{ tree="Demonology", talent="Fel Stamina", n=3 },
			{ tree="Demonology", talent="Fel Domination", n=1, spike=true, note="POWER SPIKE — instant free pet resummon." },
			{ tree="Demonology", talent="Master Summoner", n=2 },
			{ tree="Demonology", talent="Unholy Power", n=5, note="+pet melee damage." },
			{ tree="Demonology", talent="Demonic Sacrifice", n=1, note="Sacrifice pet for a buff when not using Felguard." },
			{ tree="Demonology", talent="Master Demonologist", n=5 },
			{ tree="Demonology", talent="Soul Link", n=1, spike=true, note="POWER SPIKE — 20% damage redirected to pet; huge survivability." },
			{ tree="Demonology", talent="Demonic Knowledge", n=3 },
			{ tree="Demonology", talent="Demonic Tactics", n=5 },
			{ tree="Demonology", talent="Summon Felguard", n=1, spike=true, note="CAPSTONE at 50 — the leveling carry pet." },
			-- Destruction dip
			{ tree="Destruction", talent="Improved Shadow Bolt", n=5 },
			{ tree="Destruction", talent="Bane", n=5, note="Faster Shadow Bolt / Immolate." },
			{ tree="Destruction", talent="Devastation", n=5 },
			{ tree="Destruction", talent="Improved Immolate", n=3 },
			{ tree="Destruction", talent="Cataclysm", n=2 },
		}),
	},
}

ns.data.rotations.WARLOCK = {
	default = "DEMO",
	DEMO = {
		key = "DEMO",
		priority = {
			{ spell="Corruption", minLevel=4, note="Instant DoT — always keep up." },
			{ spell="Curse of Agony", minLevel=8, note="Second DoT." },
			{ spell="Immolate", minLevel=10, note="Strong direct + DoT filler (with Bane)." },
			{ spell="Siphon Life", minLevel=30, note="Passive self-heal DoT." },
			{ spell="Drain Soul", minLevel=8, cond=function(c) return c.targetHP < 0.25 end, note="Killing blow on low mobs — refunds mana + shards." },
			{ spell="Shadow Bolt", minLevel=1, cond=function(c) return c.mana > 0.2 end, note="Filler (free on Nightfall procs)." },
			{ spell="Life Tap", minLevel=6, cond=function(c) return c.mana < 0.2 end, note="Health → mana (heal it back with drains)." },
		},
		openers = {
			"Let the pet tank. Apply Corruption → Curse of Agony → Immolate, then Shadow Bolt / Drain Life filler.",
			"Pet: Voidwalker 1–49 (drain-tank), Felguard from 50 (it cleaves & tanks).",
		},
		notes = {
			"Drain Life + Siphon Life + Life Tap loop = almost no downtime.",
			"Fel Domination for instant resummons; Health Funnel to keep the pet alive.",
		},
	},
}
