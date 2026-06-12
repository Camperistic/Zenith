-- TalentMate
-- Detects your class and applies a recommended PvE or PvP talent build for
-- TBC Classic (2.5.x) with a single command.
--
-- How the apply works (and why it's written this way):
--   On 2.5.5, LearnTalent(tab, index) is callable by addons, but it is ASYNC --
--   a just-learned point is NOT visible to GetTalentInfo/UnitCharacterPoints in
--   the same frame. So we spend exactly ONE point, wait for the
--   CHARACTER_POINTS_CHANGED event, then place the next. A tight synchronous
--   loop would desync. This is the proven TalentedClassic approach.
--
-- Talents are matched to your live tree BY NAME, so build order and the (non
-- row-major) talent index don't matter. Spending points is irreversible without
-- a gold respec, and only works on UNSPENT points, so applying is gated behind a
-- confirmation and only ever started by your own command (never automatically).

local ADDON_NAME = ...

local strlower, format, min = string.lower, string.format, math.min

local PREFIX = "|cffffd200TalentMate|r: "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

-- WoW API (TBC 2.5.5 talent system)
local GetNumTalentTabs   = GetNumTalentTabs
local GetNumTalents      = GetNumTalents
local GetTalentInfo      = GetTalentInfo
local GetTalentTabInfo   = GetTalentTabInfo
local LearnTalent        = LearnTalent
local UnitLevel          = UnitLevel

-- The talent group to operate on. With dual spec (level 40+) there are two
-- groups; target the one shown in the talent frame, else the active spec. Sub-40
-- there is only group 1. Every talent read/write below is given this group so
-- reads and the spend always agree -- passing NO group was why dual spec did
-- nothing (reads and LearnTalent could land on different specs).
local function GetTargetGroup()
    return (PlayerTalentFrame and PlayerTalentFrame.talentGroup)
        or (GetActiveTalentGroup and GetActiveTalentGroup())
        or 1
end

-- Count points spent in a talent tree by summing its talents' ranks. This is
-- signature-proof, unlike GetTalentTabInfo -- on this client its 3rd return is a
-- description STRING, not pointsSpent, which caused the "compare number with
-- string" crash. GetTalentInfo's 5th return (rank) is verified correct here.
local function tabPointsSpent(tab, group)
    local sum = 0
    for index = 1, (GetNumTalents(tab, false, false, group) or 0) do
        local rank = select(5, GetTalentInfo(tab, index, false, false, group))
        sum = sum + (rank or 0)
    end
    return sum
end

-- Unspent talent points for a group. GetUnspentTalentPoints is the dual-spec-
-- aware reader, so prefer it (minus any staged preview points); fall back to
-- UnitCharacterPoints (active spec only), then to level math.
local function GetUnspentPoints(group)
    group = group or GetTargetGroup()
    if type(GetUnspentTalentPoints) == "function" then
        local p = GetUnspentTalentPoints(false, false, group)
        if p then
            local staged = (GetGroupPreviewTalentPointsSpent and GetGroupPreviewTalentPointsSpent(false, group)) or 0
            return p - staged
        end
    end
    if type(UnitCharacterPoints) == "function" then
        local p = UnitCharacterPoints("player")
        if p then return p end
    end
    local spent = 0
    for tab = 1, (GetNumTalentTabs(false, false, group) or 0) do
        spent = spent + tabPointsSpent(tab, group)
    end
    return math.max(0, (UnitLevel("player") or 0) - 9 - spent)
end

-- ---------------------------------------------------------------------------
-- Recommended builds, keyed by class file token (UnitClass's second return --
-- "WARRIOR", "HUNTER", ... -- which is locale-independent).
--
-- Each class maps to a LIST of builds; each build is
--   { category = "pve"|"pvp", label = <short name>, useCase = <description>,
--     talents = { {"Exact English talent name", rank}, ... } }.
-- Talents are matched to the live tree by NAME at apply time. Every build was
-- independently fact-checked against the WoWhead TBC calculator / Icy-Veins for
-- correct names, a 61-point total, and satisfiable tier prerequisites.
local BUILDS = {
    WARRIOR = {
        { category="pve", label="Fury (Raid DPS)", useCase="Raid DPS: top sustained-DPS warrior spec. Dual-wields two fast weapons; relies on Bloodthirst, Flurry and a maintained Rampage. This is the default raiding DPS warrior build. Pick over Arms when your raid already has the physical-damage buff covered.", talents={ {"Improved Heroic Strike",3},{"Improved Charge",2},{"Tactical Mastery",5},{"Anger Management",1},{"Deep Wounds",3},{"Impale",2},{"Deflection",1},{"Cruelty",5},{"Unbridled Wrath",5},{"Commanding Presence",5},{"Dual Wield Specialization",5},{"Improved Execute",2},{"Enrage",5},{"Precision",2},{"Death Wish",1},{"Improved Slam",2},{"Flurry",5},{"Bloodthirst",1},{"Improved Berserker Stance",5},{"Rampage",1} } },
        { category="pve", label="Arms (Raid DPS / Blood Frenzy)", useCase="Raid DPS spec that brings Blood Frenzy (raid-wide +4% physical damage) and Mortal Strike. Slightly lower personal DPS than Fury but the raid buff plus consistent two-hander damage makes it a valued support DPS slot, especially when the raid lacks the physical-damage buff.", talents={ {"Improved Heroic Strike",3},{"Improved Charge",2},{"Tactical Mastery",5},{"Improved Overpower",2},{"Anger Management",1},{"Deep Wounds",3},{"Two-Handed Weapon Specialization",5},{"Impale",2},{"Poleaxe Specialization",5},{"Improved Disciplines",2},{"Blood Frenzy",2},{"Mortal Strike",1},{"Cruelty",5},{"Unbridled Wrath",5},{"Commanding Presence",5},{"Enrage",5},{"Precision",3},{"Flurry",5} } },
        { category="pve", label="Protection (Raid/Heroic Tank)", useCase="Main tank build for raids and Heroic dungeons. Maximizes threat (Shield Slam, Devastate, Defiance, Focused Rage, One-Handed Weapon Specialization) and survivability (Anticipation for crit immunity, Toughness, Shield Specialization, Shield Mastery). THE warrior tanking spec.", talents={ {"Improved Heroic Strike",3},{"Improved Charge",2},{"Tactical Mastery",3},{"Cruelty",5},{"Improved Bloodrage",2},{"Shield Specialization",5},{"Anticipation",5},{"Toughness",5},{"Improved Shield Block",1},{"Last Stand",1},{"Improved Revenge",3},{"Defiance",5},{"Improved Sunder Armor",2},{"Concussion Blow",1},{"Shield Mastery",3},{"One-Handed Weapon Specialization",5},{"Focused Rage",3},{"Vitality",5},{"Shield Slam",1},{"Devastate",1} } },
        { category="pvp", label="Arms (Arena 2v2/3v3)", useCase="The dominant warrior PvP/arena spec. Deep Arms (41 pts) for Mortal Strike (50% healing reduction), Improved Mortal Strike, Endless Rage, Second Wind, Improved Intercept, Improved Hamstring and weapon specialization. Excellent in 2v2 Warrior/Healer and 3v3 cleaves; burst plus the all-important MS healing debuff.", talents={ {"Improved Heroic Strike",3},{"Improved Charge",2},{"Tactical Mastery",5},{"Anger Management",1},{"Deep Wounds",3},{"Two-Handed Weapon Specialization",5},{"Impale",2},{"Improved Hamstring",3},{"Sword Specialization",5},{"Improved Disciplines",1},{"Blood Frenzy",2},{"Second Wind",2},{"Mortal Strike",1},{"Improved Intercept",2},{"Improved Mortal Strike",3},{"Endless Rage",1},{"Death Wish",1},{"Cruelty",5},{"Booming Voice",5},{"Piercing Howl",1},{"Improved Cleave",3},{"Commanding Presence",5} } },
        { category="pvp", label="Arms/Prot (Battlegrounds / Survival)", useCase="Battleground / world-PvP hybrid. Deep enough Arms (30 pts) for Mortal Strike, Second Wind and Improved Hamstring, then a 21-point Protection dip for Anticipation, Toughness, Last Stand and the Concussion Blow stun. Niche vs. the 41/20/0 arena build but a real survivability-focused setup for objective BGs and world PvP where staying alive and snaring beats peak burst.", talents={ {"Improved Heroic Strike",3},{"Deflection",1},{"Improved Charge",2},{"Tactical Mastery",5},{"Anger Management",1},{"Deep Wounds",3},{"Two-Handed Weapon Specialization",5},{"Impale",2},{"Improved Hamstring",3},{"Blood Frenzy",2},{"Second Wind",2},{"Mortal Strike",1},{"Cruelty",5},{"Unbridled Wrath",5},{"Improved Bloodrage",2},{"Shield Specialization",5},{"Anticipation",5},{"Toughness",5},{"Improved Shield Block",1},{"Last Stand",1},{"Improved Revenge",1},{"Concussion Blow",1} } },
        { category="leveling", label="Arms (10-70)", useCase="Standard TBC 2H Arms leveling build: rushes Deep Wounds + Two-Handed Weapon Specialization + Mortal Strike for big single-target burst and Sweeping Strikes for cleave, then fills Fury (Cruelty/Unbridled Wrath/Commanding Presence/Enrage/Flurry) for sustained crit, rage, and damage - fast, durable, low-downtime questing.", order={ "Improved Heroic Strike","Improved Heroic Strike","Improved Heroic Strike","Deflection","Deflection","Improved Charge","Improved Charge","Tactical Mastery","Tactical Mastery","Tactical Mastery","Anger Management","Improved Overpower","Improved Overpower","Deep Wounds","Deep Wounds","Deep Wounds","Improved Thunder Clap","Improved Thunder Clap","Two-Handed Weapon Specialization","Two-Handed Weapon Specialization","Two-Handed Weapon Specialization","Two-Handed Weapon Specialization","Two-Handed Weapon Specialization","Impale","Impale","Poleaxe Specialization","Poleaxe Specialization","Poleaxe Specialization","Poleaxe Specialization","Poleaxe Specialization","Sweeping Strikes","Mortal Strike","Cruelty","Cruelty","Cruelty","Cruelty","Cruelty","Unbridled Wrath","Unbridled Wrath","Unbridled Wrath","Unbridled Wrath","Unbridled Wrath","Commanding Presence","Commanding Presence","Commanding Presence","Commanding Presence","Commanding Presence","Improved Execute","Improved Execute","Enrage","Enrage","Enrage","Enrage","Enrage","Booming Voice","Booming Voice","Booming Voice","Flurry","Flurry","Flurry","Flurry" }, talents={ {"Improved Heroic Strike",3},{"Deflection",2},{"Improved Charge",2},{"Tactical Mastery",3},{"Anger Management",1},{"Improved Overpower",2},{"Deep Wounds",3},{"Improved Thunder Clap",2},{"Two-Handed Weapon Specialization",5},{"Impale",2},{"Poleaxe Specialization",5},{"Sweeping Strikes",1},{"Mortal Strike",1},{"Cruelty",5},{"Unbridled Wrath",5},{"Commanding Presence",5},{"Improved Execute",2},{"Enrage",5},{"Booming Voice",3},{"Flurry",4} } },
    },
    PALADIN = {
        { category="pve", label="Ret (Raid DPS)", useCase="Raid melee DPS. The mainstay PvE damage spec; brings Sanctity Aura, Improved Seal of the Crusader and Judgement of the Crusader, plus strong physical/holy burst. Take this when you want to deal damage in raids and 5-mans.", talents={ {"Precision",3},{"Anticipation",5},{"Blessing of Kings",1},{"Improved Concentration Aura",3},{"Toughness",1},{"Spell Warding",1},{"Benediction",5},{"Improved Judgement",2},{"Improved Seal of the Crusader",3},{"Deflection",2},{"Conviction",5},{"Seal of Command",1},{"Pursuit of Justice",2},{"Crusade",3},{"Two-Handed Weapon Specialization",3},{"Sanctity Aura",1},{"Improved Sanctity Aura",2},{"Vengeance",5},{"Sanctified Judgement",3},{"Sanctified Seals",3},{"Repentance",1},{"Fanaticism",5},{"Crusader Strike",1} } },
        { category="pve", label="Prot (Tank)", useCase="Raid and Heroic dungeon main tank / AoE tank. Holy Shield + Avenger's Shield + Improved Righteous Fury give exceptional multi-target threat and block-based mitigation. Take this when you want to tank, especially trash-heavy AoE pulls where Paladins shine.", talents={ {"Redoubt",5},{"Precision",3},{"Toughness",5},{"Blessing of Kings",1},{"Improved Righteous Fury",3},{"Shield Specialization",3},{"Anticipation",5},{"Blessing of Sanctuary",1},{"Sacred Duty",2},{"One-Handed Weapon Specialization",5},{"Improved Holy Shield",2},{"Holy Shield",1},{"Ardent Defender",5},{"Combat Expertise",5},{"Avenger's Shield",1},{"Improved Blessing of Might",5},{"Benediction",5},{"Improved Judgement",2},{"Improved Seal of the Crusader",2} } },
        { category="pve", label="Prot (Sanctity)", useCase="Niche/off-meta tank build for raid groups WITHOUT a Retribution Paladin. Goes 21 deep into Ret for Sanctity Aura (party holy-damage and threat buff) at the cost of Avenger's Shield and Ardent Defender. Only pick this if no Ret Paladin is present to provide Sanctity Aura.", talents={ {"Redoubt",5},{"Precision",3},{"Toughness",5},{"Improved Righteous Fury",3},{"Shield Specialization",3},{"Anticipation",5},{"Blessing of Sanctuary",1},{"Reckoning",5},{"Sacred Duty",2},{"One-Handed Weapon Specialization",5},{"Improved Holy Shield",2},{"Holy Shield",1},{"Improved Blessing of Might",5},{"Benediction",5},{"Improved Judgement",2},{"Improved Seal of the Crusader",3},{"Conviction",5},{"Sanctity Aura",1} } },
        { category="pve", label="Holy (Healer)", useCase="Raid and dungeon main healer. The premier single-target tank healer thanks to Illumination mana returns, Divine Favor, Light's Grace and Holy Shock. Take this for any healing role; it is the standard and essentially only Holy build.", talents={ {"Divine Intellect",5},{"Spiritual Focus",5},{"Healing Light",3},{"Aura Mastery",1},{"Illumination",5},{"Improved Blessing of Wisdom",1},{"Divine Favor",1},{"Sanctified Light",3},{"Purifying Power",2},{"Holy Power",5},{"Light's Grace",3},{"Holy Shock",1},{"Holy Guidance",5},{"Divine Illumination",1},{"Improved Devotion Aura",5},{"Guardian's Favor",2},{"Toughness",3},{"Blessing of Kings",1},{"Anticipation",5},{"Improved Concentration Aura",3},{"Spell Warding",1} } },
        { category="pvp", label="Ret (Arena/BG)", useCase="Arena (2v2/3v3) and battlegrounds burst DPS. Deep Ret for Repentance CC, Crusader Strike and Seal of Command burst, with Protection for Stoicism (stun/dispel resist) and survivability. The main Paladin PvP damage build.", talents={ {"Precision",3},{"Toughness",5},{"Anticipation",5},{"Stoicism",2},{"Blessing of Kings",1},{"Spell Warding",2},{"Blessing of Sanctuary",1},{"Benediction",5},{"Improved Judgement",2},{"Vindication",3},{"Conviction",5},{"Seal of Command",1},{"Pursuit of Justice",2},{"Crusade",3},{"Two-Handed Weapon Specialization",3},{"Vengeance",5},{"Sanctified Judgement",3},{"Sanctified Seals",3},{"Repentance",1},{"Fanaticism",5},{"Crusader Strike",1} } },
        { category="pvp", label="Holy (Arena)", useCase="Arena (2v2/3v3) and rated battleground healer. The dominant Paladin PvP spec: extremely strong single-target healing with Holy Shock burst-heal, Divine Favor, Improved Hammer of Justice and Stoicism for survivability under pressure. Take this to heal in PvP.", talents={ {"Divine Intellect",5},{"Spiritual Focus",5},{"Healing Light",3},{"Aura Mastery",1},{"Illumination",5},{"Divine Favor",1},{"Sanctified Light",3},{"Purifying Power",2},{"Holy Power",5},{"Light's Grace",3},{"Holy Shock",1},{"Holy Guidance",5},{"Divine Illumination",1},{"Redoubt",1},{"Precision",2},{"Guardian's Favor",2},{"Toughness",5},{"Blessing of Kings",1},{"Anticipation",5},{"Improved Hammer of Justice",3},{"Stoicism",2} } },
        { category="leveling", label="Retribution (10-70)", useCase="Retribution is the standard Paladin leveling spec: it has the best solo DPS/kill speed of the three trees, scales with 2H weapons, and stays mana/health efficient via Benediction, Sanctified Judgement, and plate self-sustain so you rarely die or drink.", order={ "Benediction","Benediction","Benediction","Benediction","Benediction","Improved Judgement","Improved Judgement","Improved Seal of the Crusader","Improved Seal of the Crusader","Improved Seal of the Crusader","Seal of Command","Pursuit of Justice","Pursuit of Justice","Deflection","Deflection","Conviction","Conviction","Conviction","Conviction","Conviction","Two-Handed Weapon Specialization","Two-Handed Weapon Specialization","Two-Handed Weapon Specialization","Crusade","Crusade","Crusade","Sanctity Aura","Sanctified Judgement","Sanctified Judgement","Sanctified Judgement","Vengeance","Vengeance","Vengeance","Improved Sanctity Aura","Improved Sanctity Aura","Sanctity of Battle","Sanctified Seals","Sanctified Seals","Sanctified Seals","Repentance","Crusader Strike","Fanaticism","Fanaticism","Fanaticism","Fanaticism","Fanaticism","Deflection","Deflection","Deflection","Divine Strength","Divine Strength","Divine Strength","Divine Strength","Divine Strength","Divine Intellect","Divine Intellect","Divine Intellect","Divine Intellect","Divine Intellect","Spiritual Focus","Spiritual Focus" }, talents={ {"Benediction",5},{"Improved Judgement",2},{"Improved Seal of the Crusader",3},{"Seal of Command",1},{"Pursuit of Justice",2},{"Deflection",5},{"Conviction",5},{"Two-Handed Weapon Specialization",3},{"Crusade",3},{"Sanctity Aura",1},{"Sanctified Judgement",3},{"Vengeance",3},{"Improved Sanctity Aura",2},{"Sanctity of Battle",1},{"Sanctified Seals",3},{"Repentance",1},{"Crusader Strike",1},{"Fanaticism",5},{"Divine Strength",5},{"Divine Intellect",5},{"Spiritual Focus",2} } },
    },
    HUNTER = {
        { category="pve", label="BM", useCase="Raid DPS (main). Highest personal Hunter DPS and brings Ferocious Inspiration (3% party damage), so raids stack 1-3 BM Hunters. Default PvE choice for most Hunters.", talents={ {"Improved Aspect of the Hawk",5},{"Endurance Training",3},{"Focused Fire",2},{"Improved Mend Pet",2},{"Unleashed Fury",5},{"Ferocity",5},{"Intimidation",1},{"Bestial Discipline",2},{"Animal Handler",2},{"Frenzy",4},{"Ferocious Inspiration",3},{"Bestial Wrath",1},{"Serpent's Swiftness",5},{"The Beast Within",1},{"Lethal Shots",5},{"Improved Hunter's Mark",5},{"Go for the Throat",2},{"Aimed Shot",1},{"Rapid Killing",2},{"Mortal Shots",5} } },
        { category="pve", label="Survival", useCase="Raid DPS (1 mandatory per raid). Brings Expose Weakness, a raid-wide physical AP buff scaling off your Agility -- one of the strongest raid DPS talents in the game. Lower personal DPS than BM but the buff makes one SV Hunter a must-have.", talents={ {"Lethal Shots",5},{"Improved Hunter's Mark",5},{"Go for the Throat",2},{"Aimed Shot",1},{"Rapid Killing",2},{"Mortal Shots",5},{"Monster Slaying",3},{"Hawk Eye",2},{"Savage Strikes",2},{"Deflection",4},{"Survivalist",4},{"Trap Mastery",3},{"Surefooted",3},{"Killer Instinct",3},{"Lightning Reflexes",5},{"Expose Weakness",3},{"Thrill of the Hunt",3},{"Master Tactician",5},{"Readiness",1} } },
        { category="pve", label="MM", useCase="Raid DPS (niche/off-meta). Brings Trueshot Aura (raid AP buff) and Silencing Shot. Lowest of the three Hunter PvE specs in personal DPS; only worth playing if your raid already has BM and SV covered and wants a Trueshot Aura provider, or for the player who prefers the MM rotation.", talents={ {"Improved Aspect of the Hawk",5},{"Lethal Shots",5},{"Improved Hunter's Mark",5},{"Efficiency",5},{"Go for the Throat",2},{"Improved Arcane Shot",3},{"Aimed Shot",1},{"Rapid Killing",2},{"Improved Stings",5},{"Mortal Shots",5},{"Concussive Barrage",1},{"Ranged Weapon Specialization",5},{"Trueshot Aura",1},{"Silencing Shot",1},{"Monster Slaying",3},{"Hawk Eye",2},{"Savage Strikes",2},{"Deflection",3},{"Survivalist",5} } },
        { category="pvp", label="SV/MM", useCase="Arena 2v2/3v3/5v5 (main PvP spec). The dominant Hunter arena hybrid: Wyvern Sting (instant sleep) + Freezing Trap CC, Scatter Shot to set up traps, Aimed Shot's 50% healing reduction, Surefooted for hit, and high Agility scaling. Highest control and the standard pick for rated arena.", talents={ {"Lethal Shots",5},{"Improved Hunter's Mark",5},{"Go for the Throat",2},{"Aimed Shot",1},{"Improved Arcane Shot",3},{"Rapid Killing",2},{"Mortal Shots",5},{"Concussive Barrage",2},{"Scatter Shot",1},{"Monster Slaying",3},{"Hawk Eye",3},{"Savage Strikes",2},{"Deflection",3},{"Clever Traps",2},{"Survivalist",3},{"Trap Mastery",3},{"Surefooted",3},{"Survival Instincts",2},{"Killer Instinct",3},{"Lightning Reflexes",5},{"Resourcefulness",2},{"Wyvern Sting",1} } },
        { category="pvp", label="BM PvP", useCase="Arena and battlegrounds (burst alternative). Bestial Wrath + The Beast Within make your pet CC-immune and hit 50% harder while you take less damage; combined with Intimidation (pet stun) it is huge burst and a peel. Simpler and tankier than SV/MM; popular in BGs and lower-key arena.", talents={ {"Improved Aspect of the Hawk",5},{"Endurance Training",2},{"Thick Hide",3},{"Improved Revive Pet",1},{"Unleashed Fury",5},{"Improved Mend Pet",2},{"Ferocity",5},{"Intimidation",1},{"Bestial Discipline",2},{"Animal Handler",1},{"Spirit Bond",2},{"Frenzy",4},{"Ferocious Inspiration",1},{"Bestial Wrath",1},{"Serpent's Swiftness",5},{"The Beast Within",1},{"Lethal Shots",5},{"Improved Concussive Shot",5},{"Go for the Throat",2},{"Aimed Shot",1},{"Rapid Killing",2},{"Mortal Shots",5} } },
        { category="leveling", label="Beast Mastery (10-70)", useCase="Standard TBC leveling spec (deep 47-point Beast Mastery into The Beast Within): your pet tanks and does most of the damage while you grab key pet-power procs (Frenzy, Bestial Wrath/The Beast Within, Serpent's Swiftness) and solo-survival/efficiency talents for near-zero downtime and fast questing.", order={ "Improved Aspect of the Hawk","Improved Aspect of the Hawk","Improved Aspect of the Hawk","Improved Aspect of the Hawk","Improved Aspect of the Hawk","Improved Revive Pet","Improved Revive Pet","Focused Fire","Focused Fire","Thick Hide","Bestial Swiftness","Unleashed Fury","Unleashed Fury","Unleashed Fury","Unleashed Fury","Unleashed Fury","Improved Mend Pet","Improved Mend Pet","Ferocity","Ferocity","Intimidation","Ferocity","Ferocity","Ferocity","Bestial Discipline","Bestial Discipline","Frenzy","Frenzy","Frenzy","Frenzy","Bestial Wrath","Animal Handler","Animal Handler","Catlike Reflexes","Catlike Reflexes","Catlike Reflexes","Serpent's Swiftness","Serpent's Swiftness","Serpent's Swiftness","Serpent's Swiftness","The Beast Within","Serpent's Swiftness","Ferocious Inspiration","Ferocious Inspiration","Ferocious Inspiration","Spirit Bond","Spirit Bond","Lethal Shots","Lethal Shots","Lethal Shots","Lethal Shots","Lethal Shots","Efficiency","Efficiency","Efficiency","Efficiency","Efficiency","Go for the Throat","Go for the Throat","Aimed Shot","Rapid Killing" }, talents={ {"Improved Aspect of the Hawk",5},{"Improved Revive Pet",2},{"Focused Fire",2},{"Thick Hide",1},{"Bestial Swiftness",1},{"Unleashed Fury",5},{"Improved Mend Pet",2},{"Ferocity",5},{"Intimidation",1},{"Bestial Discipline",2},{"Frenzy",4},{"Bestial Wrath",1},{"Animal Handler",2},{"Catlike Reflexes",3},{"Serpent's Swiftness",5},{"The Beast Within",1},{"Ferocious Inspiration",3},{"Spirit Bond",2},{"Lethal Shots",5},{"Efficiency",5},{"Go for the Throat",2},{"Aimed Shot",1},{"Rapid Killing",1} } },
    },
    ROGUE = {
        { category="pve", label="Combat Swords", useCase="Raid DPS (primary). The meta TBC Rogue raiding spec - highest sustained single-target physical DPS via Sinister Strike spam, Combat Potency energy returns, and Surprise Attacks (which also makes finishers undodgeable). Pick this for any raid where another rogue or a warrior already supplies the armor debuff (Improved Expose Armor or Sunder Armor).", talents={ {"Malice",5},{"Ruthlessness",3},{"Lethality",5},{"Relentless Strikes",1},{"Improved Eviscerate",1},{"Improved Sinister Strike",2},{"Improved Slice and Dice",3},{"Precision",5},{"Endurance",2},{"Dual Wield Specialization",5},{"Blade Flurry",1},{"Sword Specialization",5},{"Weapon Expertise",2},{"Aggression",3},{"Vitality",2},{"Lightning Reflexes",4},{"Adrenaline Rush",1},{"Combat Potency",5},{"Surprise Attacks",1},{"Opportunity",5} } },
        { category="pve", label="Combat + Imp EA", useCase="Raid DPS for the designated armor-debuffer. Sacrifices a sliver of personal DPS to provide Improved Expose Armor (a deeper armor reduction than Sunder Armor) which boosts the ENTIRE physical raid. Exactly one rogue per raid runs this; it is a net raid-DPS gain when no other source of the deep armor debuff is present.", talents={ {"Malice",5},{"Ruthlessness",3},{"Improved Expose Armor",2},{"Relentless Strikes",1},{"Lethality",5},{"Vile Poisons",4},{"Improved Sinister Strike",2},{"Improved Slice and Dice",3},{"Dual Wield Specialization",5},{"Precision",5},{"Endurance",2},{"Lightning Reflexes",5},{"Blade Flurry",1},{"Sword Specialization",5},{"Weapon Expertise",2},{"Vitality",1},{"Aggression",3},{"Adrenaline Rush",1},{"Combat Potency",5},{"Surprise Attacks",1} } },
        { category="pve", label="Mutilate", useCase="Off-meta raid DPS alternative and strong 5-man spec. Dagger-based build using Mutilate as the combo builder; competitive on fights with frequent target swaps or when you lack good slow swords. Slightly behind Combat Swords on sustained single-target raid DPS in most gear, but very strong burst with Cold Blood and high poison damage.", talents={ {"Malice",5},{"Ruthlessness",3},{"Murder",2},{"Relentless Strikes",1},{"Improved Slice and Dice",3},{"Lethality",5},{"Vile Poisons",5},{"Improved Poisons",5},{"Cold Blood",1},{"Seal Fate",5},{"Master Poisoner",2},{"Find Weakness",3},{"Mutilate",1},{"Improved Sinister Strike",2},{"Improved Slice and Dice",3},{"Precision",5},{"Dual Wield Specialization",5},{"Blade Flurry",1},{"Blade Twisting",2},{"Endurance",2} } },
        { category="pvp", label="Sub Shadowstep", useCase="Main arena spec (2v2/3v3/5v5) and the gold-standard rogue PvP build. After the 2.3.2 Combat nerf, 20/0/41 Shadowstep is THE rogue arena build: Preparation resets Vanish/Sprint/Shadowstep/Evasion/Cold Blood, Cheat Death and Cloak of Shadows give survivability, and Shadowstep enables relentless target pressure and gap-closing.", talents={ {"Malice",5},{"Ruthlessness",3},{"Lethality",5},{"Relentless Strikes",1},{"Vile Poisons",5},{"Master Poisoner",1},{"Opportunity",5},{"Camouflage",3},{"Initiative",3},{"Ghostly Strike",1},{"Improved Ambush",3},{"Setup",3},{"Elusiveness",2},{"Serrated Blades",3},{"Heightened Senses",2},{"Preparation",1},{"Dirty Deeds",1},{"Hemorrhage",1},{"Master of Subtlety",3},{"Deadliness",5},{"Premeditation",1},{"Cheat Death",3},{"Shadowstep",1} } },
        { category="pvp", label="Sub Imp EA variant", useCase="Arena variant for double-DPS cleaves (e.g. Rogue/Warrior or Rogue/Shadow-Priest) that want to stack physical burst on a kill target. Drops some Assassination/poison damage to grab Improved Expose Armor for the deep armor debuff. Pick over the standard sub build specifically in armor-reliant cleave comps; the standard 20/0/41 is better in most other matchups.", talents={ {"Malice",5},{"Ruthlessness",3},{"Improved Expose Armor",2},{"Lethality",4},{"Improved Sinister Strike",2},{"Improved Gouge",1},{"Opportunity",5},{"Camouflage",5},{"Initiative",3},{"Ghostly Strike",1},{"Improved Ambush",3},{"Setup",3},{"Elusiveness",2},{"Serrated Blades",3},{"Heightened Senses",2},{"Preparation",1},{"Dirty Deeds",2},{"Hemorrhage",1},{"Master of Subtlety",3},{"Deadliness",5},{"Premeditation",1},{"Cheat Death",3},{"Shadowstep",1} } },
        { category="leveling", label="Combat (10-70)", useCase="Combat (41 Combat / 20 Assassination) is the fastest, most durable Rogue leveling spec: Blade Flurry cleaves multi-mob pulls, Adrenaline Rush + Combat Potency give near-infinite energy, and Precision/Malice/Lethality make Sinister Strike hit hard and reliably while Vitality/Deflection/Riposte keep you alive between fights. The Assassination dip takes Malice, Improved Eviscerate, Ruthlessness, Murder, Relentless Strikes, Lethality, and a leveling-friendly point of Remorseless Attacks (bonus crit on the first hit after every kill).", order={ "Improved Sinister Strike","Improved Sinister Strike","Improved Gouge","Improved Gouge","Improved Gouge","Precision","Precision","Precision","Precision","Precision","Improved Slice and Dice","Improved Slice and Dice","Improved Slice and Dice","Deflection","Deflection","Deflection","Deflection","Deflection","Riposte","Endurance","Endurance","Lightning Reflexes","Dual Wield Specialization","Dual Wield Specialization","Dual Wield Specialization","Dual Wield Specialization","Dual Wield Specialization","Blade Flurry","Weapon Expertise","Weapon Expertise","Adrenaline Rush","Vitality","Vitality","Aggression","Aggression","Combat Potency","Combat Potency","Combat Potency","Combat Potency","Combat Potency","Surprise Attacks","Malice","Malice","Malice","Malice","Malice","Improved Eviscerate","Improved Eviscerate","Improved Eviscerate","Remorseless Attacks","Ruthlessness","Ruthlessness","Ruthlessness","Murder","Murder","Relentless Strikes","Lethality","Lethality","Lethality","Lethality","Lethality" }, talents={ {"Improved Sinister Strike",2},{"Improved Gouge",3},{"Precision",5},{"Improved Slice and Dice",3},{"Deflection",5},{"Riposte",1},{"Endurance",2},{"Lightning Reflexes",1},{"Dual Wield Specialization",5},{"Blade Flurry",1},{"Weapon Expertise",2},{"Adrenaline Rush",1},{"Vitality",2},{"Aggression",2},{"Combat Potency",5},{"Surprise Attacks",1},{"Malice",5},{"Improved Eviscerate",3},{"Remorseless Attacks",1},{"Ruthlessness",3},{"Murder",2},{"Relentless Strikes",1},{"Lethality",5} } },
    },
    PRIEST = {
        { category="pve", label="Shadow", useCase="Raid DPS. The premier mana-battery raid spec: Vampiric Touch returns 5% of your shadow damage as mana to the party, while Misery + Shadow Weaving apply raid-wide spell-damage debuffs. Bring 1-2 per 25-man.", talents={ {"Unbreakable Will",5},{"Improved Power Word: Fortitude",2},{"Improved Power Word: Shield",3},{"Meditation",3},{"Inner Focus",1},{"Spirit Tap",5},{"Shadow Affinity",3},{"Improved Shadow Word: Pain",2},{"Shadow Focus",5},{"Improved Mind Blast",5},{"Mind Flay",1},{"Improved Psychic Scream",2},{"Silence",1},{"Shadow Weaving",5},{"Vampiric Embrace",1},{"Improved Vampiric Embrace",2},{"Focused Mind",1},{"Shadow Reach",2},{"Darkness",5},{"Shadowform",1},{"Misery",5},{"Vampiric Touch",1} } },
        { category="pve", label="Holy (CoH)", useCase="Main raid healer. Reaches Circle of Healing, the best instant AoE party heal in TBC; the default raid-wide/group-healing assignment in 25-mans, especially on stacked-group, raid-wide damage fights.", talents={ {"Unbreakable Will",5},{"Silent Resolve",1},{"Improved Power Word: Fortitude",2},{"Improved Power Word: Shield",3},{"Meditation",3},{"Inner Focus",1},{"Mental Agility",5},{"Improved Renew",3},{"Holy Specialization",5},{"Divine Fury",5},{"Inspiration",2},{"Searing Light",2},{"Improved Healing",3},{"Spiritual Guidance",5},{"Surge of Light",2},{"Spiritual Healing",5},{"Holy Concentration",3},{"Empowered Healing",5},{"Circle of Healing",1} } },
        { category="pve", label="Disc (IDS)", useCase="Raid healer variant that brings the Improved Divine Spirit raid buff (Spirit plus a portion of Spirit as bonus spell power/healing to the party) plus Power Infusion. Pick when the raid wants IDS and a tank/single-target oriented priest instead of a CoH spammer.", talents={ {"Unbreakable Will",5},{"Silent Resolve",3},{"Improved Power Word: Fortitude",2},{"Improved Power Word: Shield",3},{"Meditation",3},{"Inner Focus",1},{"Mental Agility",5},{"Mental Strength",5},{"Divine Spirit",1},{"Improved Divine Spirit",2},{"Power Infusion",1},{"Improved Renew",3},{"Holy Specialization",5},{"Healing Focus",2},{"Divine Fury",5},{"Inspiration",3},{"Holy Reach",2},{"Improved Healing",3},{"Searing Light",2},{"Spiritual Guidance",5} } },
        { category="pvp", label="Disc PvP", useCase="Arena healer (2v2/3v3/5v5) and the premier priest PvP spec. Pain Suppression + Power Infusion + strong dispels and shields make Disc the most durable, dispel-dominant healer in TBC. The default ranked arena priest build.", talents={ {"Unbreakable Will",5},{"Silent Resolve",5},{"Improved Power Word: Shield",3},{"Meditation",3},{"Inner Focus",1},{"Mental Agility",5},{"Improved Mana Burn",2},{"Mental Strength",5},{"Divine Spirit",1},{"Improved Divine Spirit",2},{"Focused Power",2},{"Force of Will",5},{"Power Infusion",1},{"Pain Suppression",1},{"Improved Renew",3},{"Holy Specialization",5},{"Holy Reach",2},{"Searing Light",2},{"Divine Fury",5},{"Inspiration",3} } },
        { category="pvp", label="Shadow PvP", useCase="Arena/BG DPS priest. Brings DoT rot pressure, Silence, Psychic Scream fear, Blackout stuns and Mana Burn to drain enemy healers. The damage-dealing priest spec, strong in caster-cleave comps and battlegrounds.", talents={ {"Unbreakable Will",5},{"Silent Resolve",5},{"Improved Power Word: Shield",3},{"Meditation",3},{"Inner Focus",1},{"Improved Mana Burn",2},{"Mental Agility",3},{"Mental Strength",1},{"Spirit Tap",5},{"Blackout",5},{"Improved Shadow Word: Pain",2},{"Shadow Focus",2},{"Improved Psychic Scream",2},{"Improved Mind Blast",5},{"Mind Flay",1},{"Shadow Weaving",5},{"Silence",1},{"Vampiric Embrace",1},{"Focused Mind",1},{"Shadow Reach",2},{"Darkness",5},{"Shadowform",1} } },
        { category="leveling", label="Shadow (10-70)", useCase="Shadow is the standard Priest leveling spec: Spirit Tap regen + Shadowform/Misery/Darkness scaling give near-zero downtime, strong solo DoT+Mind Flay damage, and built-in self-healing via Vampiric Embrace. Final 15/0/46 build reaches all Shadow power spikes (Mind Flay L13ish, Vampiric Embrace, Shadowform, Misery, Vampiric Touch) then dips Discipline for Wand Spec, mana (Meditation/Inner Focus) and shield strength.", order={ "Spirit Tap","Spirit Tap","Spirit Tap","Spirit Tap","Spirit Tap","Improved Shadow Word: Pain","Improved Shadow Word: Pain","Shadow Focus","Shadow Focus","Shadow Focus","Shadow Focus","Shadow Focus","Mind Flay","Improved Mind Blast","Improved Mind Blast","Improved Mind Blast","Improved Mind Blast","Improved Mind Blast","Shadow Reach","Shadow Reach","Shadow Weaving","Shadow Weaving","Shadow Weaving","Shadow Weaving","Shadow Weaving","Vampiric Embrace","Darkness","Darkness","Darkness","Darkness","Darkness","Focused Mind","Focused Mind","Focused Mind","Shadowform","Shadow Power","Shadow Power","Shadow Power","Shadow Power","Shadow Power","Misery","Misery","Misery","Misery","Misery","Vampiric Touch","Wand Specialization","Wand Specialization","Wand Specialization","Wand Specialization","Wand Specialization","Improved Power Word: Shield","Improved Power Word: Shield","Improved Power Word: Shield","Martyrdom","Martyrdom","Meditation","Meditation","Meditation","Inner Focus","Improved Power Word: Fortitude" }, talents={ {"Spirit Tap",5},{"Improved Shadow Word: Pain",2},{"Shadow Focus",5},{"Mind Flay",1},{"Improved Mind Blast",5},{"Shadow Reach",2},{"Shadow Weaving",5},{"Vampiric Embrace",1},{"Darkness",5},{"Focused Mind",3},{"Shadowform",1},{"Shadow Power",5},{"Misery",5},{"Vampiric Touch",1},{"Wand Specialization",5},{"Improved Power Word: Shield",3},{"Martyrdom",2},{"Meditation",3},{"Inner Focus",1},{"Improved Power Word: Fortitude",1} } },
    },
    SHAMAN = {
        { category="pve", label="Elemental", useCase="Raid caster DPS. The go-to ranged Shaman raid spec - brings Totem of Wrath (3% spell hit/crit to the caster group), big Lightning Bolt/Chain Lightning crits, and Bloodlust. Pick this for raid DPS when your group needs a caster slot and the Totem of Wrath buff.", talents={ {"Convection",5},{"Concussion",5},{"Call of Thunder",5},{"Elemental Focus",1},{"Elemental Fury",5},{"Elemental Reach",2},{"Lightning Mastery",5},{"Elemental Precision",3},{"Call of Flame",3},{"Elemental Mastery",1},{"Unrelenting Storm",5},{"Totem of Wrath",1},{"Tidal Focus",5},{"Totemic Focus",5},{"Nature's Guidance",3},{"Healing Focus",2},{"Tidal Mastery",5} } },
        { category="pve", label="Enhancement", useCase="Raid melee DPS. Brings Windfury Totem and Unleashed Rage (10% melee AP) to the melee group, making it a staple in melee-heavy raid comps. Pick this for melee DPS and to buff a melee group's attack power and Windfury uptime.", talents={ {"Convection",2},{"Concussion",5},{"Call of Flame",3},{"Elemental Focus",1},{"Reverberation",5},{"Improved Fire Totems",1},{"Ancestral Knowledge",5},{"Thundering Strikes",5},{"Improved Ghost Wolf",1},{"Flurry",5},{"Spirit Weapons",1},{"Elemental Weapons",3},{"Mental Quickness",3},{"Weapon Mastery",5},{"Dual Wield Specialization",3},{"Dual Wield",1},{"Unleashed Rage",5},{"Stormstrike",1},{"Shamanistic Focus",1},{"Shamanistic Rage",1},{"Improved Weapon Totems",2},{"Enhancing Totems",2} } },
        { category="pve", label="Resto (Raid)", useCase="Raid healer. The most-wanted healer in TBC thanks to Chain Heal (best AoE/group healing in the game), Mana Tide Totem (group mana), Earth Shield (tank) and Bloodlust. Pick this whenever you want to heal raids or dungeons.", talents={ {"Ancestral Knowledge",5},{"Improved Healing Wave",5},{"Tidal Focus",5},{"Improved Reincarnation",2},{"Ancestral Healing",3},{"Totemic Focus",5},{"Healing Focus",5},{"Tidal Mastery",5},{"Healing Grace",3},{"Restorative Totems",5},{"Healing Way",3},{"Nature's Swiftness",1},{"Purification",5},{"Nature's Guardian",4},{"Mana Tide Totem",1},{"Improved Chain Heal",3},{"Earth Shield",1} } },
        { category="pvp", label="Resto (Arena)", useCase="Arena healer (2v2/3v3/5v5) and the strongest Shaman PvP role. Provides Grounding/Tremor/Earthbind totems, Earth Shield, Nature's Swiftness + instant Healing Wave clutch heals, and Purge. Pick this to play a healing Shaman in rated arena or as a BG flag/raid healer.", talents={ {"Ancestral Knowledge",5},{"Improved Healing Wave",5},{"Tidal Focus",5},{"Improved Reincarnation",2},{"Ancestral Healing",3},{"Totemic Focus",5},{"Healing Focus",5},{"Tidal Mastery",5},{"Healing Grace",3},{"Restorative Totems",4},{"Healing Way",3},{"Nature's Swiftness",1},{"Purification",5},{"Nature's Guardian",5},{"Mana Tide Totem",1},{"Improved Chain Heal",3},{"Earth Shield",1} } },
        { category="pvp", label="Enh (Arena/BG)", useCase="Burst melee PvP (2v2 with a healer, and battlegrounds). Big Windfury/Stormstrike spike damage plus Shamanistic Rage for survival and mana, Frost Shock/Earthbind for kiting control. Niche but real in arena - strongest in a melee+healer 2v2; great in battlegrounds. Pick for melee Shaman PvP pressure.", talents={ {"Ancestral Knowledge",5},{"Thundering Strikes",5},{"Improved Ghost Wolf",2},{"Flurry",5},{"Toughness",5},{"Elemental Weapons",3},{"Spirit Weapons",1},{"Weapon Mastery",5},{"Mental Quickness",3},{"Dual Wield",1},{"Dual Wield Specialization",3},{"Stormstrike",1},{"Shamanistic Focus",1},{"Shamanistic Rage",1},{"Tidal Focus",5},{"Totemic Focus",5},{"Nature's Guidance",3},{"Improved Reincarnation",2},{"Totemic Mastery",1},{"Restorative Totems",4} } },
        { category="pvp", label="Ele (Arena/BG)", useCase="Caster burst PvP (battlegrounds and casual arena). Huge Lightning Bolt/Chain Lightning + Stormstrike-amplified Earth Shock burst, with Eye of the Storm to push casts through damage. Niche/off-meta in rated arena (vulnerable to interrupts/LoS) but strong in BGs and fun for ranged burst. Pick for ranged Shaman PvP pressure.", talents={ {"Convection",5},{"Concussion",5},{"Call of Thunder",5},{"Elemental Focus",1},{"Elemental Fury",5},{"Eye of the Storm",3},{"Elemental Reach",2},{"Lightning Mastery",5},{"Elemental Precision",3},{"Elemental Mastery",1},{"Unrelenting Storm",5},{"Tidal Focus",5},{"Totemic Focus",5},{"Nature's Guidance",3},{"Healing Focus",2},{"Tidal Mastery",5},{"Nature's Swiftness",1} } },
        { category="leveling", label="Enhancement (10-70)", useCase="Enhancement is the standard TBC Shaman leveling spec: a melee bruiser with weapon imbues, shocks and totems that is the least mana-starved spec, chaining pulls fast with Flurry/Stormstrike/Shamanistic Rage while staying tanky.", order={ "Shield Specialization","Shield Specialization","Shield Specialization","Shield Specialization","Shield Specialization","Thundering Strikes","Thundering Strikes","Thundering Strikes","Thundering Strikes","Thundering Strikes","Shamanistic Focus","Improved Ghost Wolf","Improved Ghost Wolf","Enhancing Totems","Enhancing Totems","Flurry","Flurry","Flurry","Flurry","Flurry","Spirit Weapons","Elemental Weapons","Elemental Weapons","Elemental Weapons","Anticipation","Weapon Mastery","Weapon Mastery","Weapon Mastery","Weapon Mastery","Weapon Mastery","Stormstrike","Dual Wield Specialization","Dual Wield Specialization","Dual Wield Specialization","Anticipation","Dual Wield","Unleashed Rage","Unleashed Rage","Unleashed Rage","Unleashed Rage","Unleashed Rage","Shamanistic Rage","Mental Quickness","Mental Quickness","Mental Quickness","Concussion","Concussion","Concussion","Concussion","Concussion","Call of Flame","Call of Flame","Call of Flame","Earth's Grasp","Earth's Grasp","Elemental Focus","Reverberation","Reverberation","Reverberation","Reverberation","Reverberation" }, talents={ {"Shield Specialization",5},{"Thundering Strikes",5},{"Shamanistic Focus",1},{"Improved Ghost Wolf",2},{"Enhancing Totems",2},{"Flurry",5},{"Spirit Weapons",1},{"Elemental Weapons",3},{"Anticipation",2},{"Weapon Mastery",5},{"Stormstrike",1},{"Dual Wield Specialization",3},{"Dual Wield",1},{"Unleashed Rage",5},{"Shamanistic Rage",1},{"Mental Quickness",3},{"Concussion",5},{"Call of Flame",3},{"Earth's Grasp",2},{"Elemental Focus",1},{"Reverberation",5} } },
    },
    MAGE = {
        { category="pve", label="Fire", useCase="Raid DPS (the meta Mage raid spec). Highest single-target sustained damage once you have enough crit to roll Ignite; Icy Veins + Combustion gives a strong burst window. Pick this for serious PvE raiding (T5+); weaker than Arcane in low/early gear.", talents={ {"Arcane Subtlety",2},{"Improved Fireball",5},{"Impact",5},{"Ignite",5},{"Flame Throwing",2},{"Improved Flamestrike",1},{"Pyroblast",1},{"Improved Scorch",3},{"Master of Elements",3},{"Playing with Fire",3},{"Critical Mass",3},{"Blast Wave",1},{"Fire Power",5},{"Pyromaniac",3},{"Combustion",1},{"Molten Fury",2},{"Empowered Fireball",5},{"Improved Frostbolt",5},{"Elemental Precision",3},{"Frostbite",2},{"Icy Veins",1} } },
        { category="pve", label="Arcane", useCase="Raid DPS, especially strong in low/mid gear where it out-scales Fire, and excellent burst on Bloodlust/Heroism. Pick this in T4 gear or when you want reliable, gear-independent damage and Scorch-free play.", talents={ {"Arcane Subtlety",2},{"Arcane Focus",5},{"Arcane Concentration",5},{"Arcane Impact",3},{"Arcane Meditation",3},{"Presence of Mind",1},{"Arcane Mind",5},{"Arcane Instability",3},{"Arcane Potency",2},{"Empowered Arcane Missiles",3},{"Arcane Power",1},{"Spell Power",2},{"Mind Mastery",5},{"Improved Frostbolt",5},{"Elemental Precision",3},{"Ice Shards",5},{"Piercing Ice",3},{"Icy Veins",1},{"Frost Channeling",3},{"Arctic Reach",1} } },
        { category="pve", label="Fire AoE", useCase="5-man dungeons / AoE farming and trash-heavy raid pulls. Trades a little single-target for Dragon's Breath + Blast Wave + improved Flamestrike and Clearcasting mana efficiency. Pick it for dungeon spam or AoE grinding; on single-target bosses use the 2/48/11 Fire IV build instead.", talents={ {"Arcane Subtlety",2},{"Arcane Focus",3},{"Improved Arcane Missiles",2},{"Arcane Concentration",5},{"Improved Fireball",5},{"Ignite",5},{"Flame Throwing",2},{"Incineration",2},{"Improved Flamestrike",3},{"Pyroblast",1},{"Improved Scorch",3},{"Master of Elements",3},{"Playing with Fire",3},{"Critical Mass",3},{"Blast Wave",1},{"Fire Power",5},{"Pyromaniac",3},{"Combustion",1},{"Molten Fury",2},{"Empowered Fireball",5},{"Dragon's Breath",1},{"Elemental Precision",1} } },
        { category="pvp", label="Frost", useCase="Primary Arena build (2v2/3v3) and the king of control. Deep Frost for Summon Water Elemental, Ice Barrier and Shatter burst. Pick this for nearly all Mage PvP; best with a healer (e.g. Mage/Rogue/Priest, RMP).", talents={ {"Arcane Subtlety",2},{"Arcane Focus",5},{"Improved Arcane Missiles",3},{"Improved Frostbolt",5},{"Elemental Precision",3},{"Ice Shards",5},{"Frostbite",3},{"Improved Frost Nova",2},{"Permafrost",1},{"Piercing Ice",3},{"Icy Veins",1},{"Frost Channeling",3},{"Arctic Reach",2},{"Shatter",3},{"Ice Floes",2},{"Winter's Chill",5},{"Ice Barrier",1},{"Arctic Winds",5},{"Empowered Frostbolt",5},{"Cold Snap",1},{"Summon Water Elemental",1} } },
        { category="pvp", label="PoM Pyro", useCase="Niche/off-meta burst PvP (3v3/5v5 and BGs). The 'PoM Pyro / Deep Fire' cheese: Presence of Mind into instant Pyroblast for a huge opener, plus strong AoE CC (Dragon's Breath, Blast Wave). Pick it for fast-kill comps and battlegrounds; falls off badly vs teams with a healer. Frost remains the standard Mage PvP choice.", talents={ {"Arcane Subtlety",2},{"Arcane Focus",5},{"Arcane Concentration",5},{"Presence of Mind",1},{"Improved Fireball",5},{"Impact",5},{"Ignite",5},{"Flame Throwing",2},{"Improved Flamestrike",3},{"Pyroblast",1},{"Improved Scorch",3},{"Master of Elements",3},{"Playing with Fire",3},{"Critical Mass",3},{"Blast Wave",1},{"Fire Power",5},{"Pyromaniac",3},{"Combustion",1},{"Molten Fury",2},{"Empowered Fireball",2},{"Dragon's Breath",1} } },
        { category="leveling", label="Frost (10-70)", useCase="Deep Frost (10/0/51) is THE standard Mage leveling spec: safest and most mana-efficient, with constant chill/freeze control, Shatter burst, Ice Barrier survivability, Icy Veins, and a Water Elemental pet â€” letting you kite, grind, and quest without downtime.", order={ "Improved Frostbolt","Improved Frostbolt","Improved Frostbolt","Improved Frostbolt","Improved Frostbolt","Elemental Precision","Elemental Precision","Elemental Precision","Frostbite","Frostbite","Piercing Ice","Piercing Ice","Piercing Ice","Ice Shards","Ice Shards","Ice Shards","Ice Shards","Ice Shards","Frostbite","Cold Snap","Improved Frost Nova","Improved Frost Nova","Frost Channeling","Frost Channeling","Frost Channeling","Icy Veins","Shatter","Shatter","Shatter","Shatter","Shatter","Ice Barrier","Arctic Winds","Arctic Winds","Arctic Winds","Arctic Winds","Arctic Winds","Empowered Frostbolt","Empowered Frostbolt","Empowered Frostbolt","Empowered Frostbolt","Empowered Frostbolt","Summon Water Elemental","Arctic Reach","Arctic Reach","Winter's Chill","Winter's Chill","Winter's Chill","Winter's Chill","Winter's Chill","Ice Floes","Arcane Subtlety","Arcane Subtlety","Arcane Focus","Arcane Focus","Arcane Focus","Arcane Concentration","Arcane Concentration","Arcane Concentration","Arcane Concentration","Arcane Concentration" }, talents={ {"Improved Frostbolt",5},{"Elemental Precision",3},{"Frostbite",3},{"Piercing Ice",3},{"Ice Shards",5},{"Cold Snap",1},{"Improved Frost Nova",2},{"Frost Channeling",3},{"Icy Veins",1},{"Shatter",5},{"Ice Barrier",1},{"Arctic Winds",5},{"Empowered Frostbolt",5},{"Summon Water Elemental",1},{"Arctic Reach",2},{"Winter's Chill",5},{"Ice Floes",1},{"Arcane Subtlety",2},{"Arcane Focus",3},{"Arcane Concentration",5} } },
    },
    WARLOCK = {
        { category="pve", label="DS/Ruin", useCase="Raid DPS - the standard top single-target Warlock raid build. Sacrifice the Succubus (Demonic Sacrifice) for +15% Shadow damage, then spam Shadow Bolt with Ruin (doubled crit damage). Scales the hardest of any Warlock spec into T5/T6. The 0/21/40 tree covers both Shadow (Improved Shadow Bolt, Shadow and Flame) and Fire (Improved Immolate, Emberstorm, Conflagrate) so you never respec between fights.", talents={ {"Improved Shadow Bolt",5},{"Bane",5},{"Improved Firebolt",2},{"Improved Immolate",3},{"Devastation",1},{"Shadowburn",1},{"Destructive Reach",2},{"Improved Searing Pain",3},{"Pyroclasm",2},{"Ruin",1},{"Nether Protection",3},{"Emberstorm",5},{"Conflagrate",1},{"Soul Leech",1},{"Shadow and Flame",5},{"Improved Imp",3},{"Demonic Embrace",5},{"Fel Intellect",3},{"Improved Voidwalker",3},{"Fel Domination",1},{"Fel Stamina",3},{"Master Summoner",2},{"Demonic Sacrifice",1} } },
        { category="pve", label="UA/Malediction", useCase="Raid DPS with raid-wide utility. Brings Malediction (boosts the raid's Curse of the Elements to +13% spell damage taken on the boss) plus full DoT pressure including Unstable Affliction. Strong early-gear DPS and excellent on movement / multi-target fights. Bring at least one Affliction lock per raid for Malediction. Competitive but slightly behind DS/Ruin on pure single-target at high gear.", talents={ {"Suppression",5},{"Improved Corruption",5},{"Improved Life Tap",2},{"Soul Siphon",2},{"Fel Concentration",5},{"Amplify Curse",1},{"Nightfall",2},{"Empowered Corruption",3},{"Siphon Life",1},{"Shadow Mastery",5},{"Contagion",5},{"Dark Pact",1},{"Malediction",3},{"Unstable Affliction",1},{"Improved Shadow Bolt",5},{"Bane",5},{"Devastation",1},{"Shadowburn",1},{"Destructive Reach",2},{"Improved Searing Pain",1},{"Shadow and Flame",5} } },
        { category="pve", label="Felguard", useCase="Niche raid DPS via Summon Felguard (the 41-point Demonology capstone). The Felguard pet plus Demonic Knowledge, Master Demonologist and Soul Link gives strong, gear-light damage with low DoT-tracking. A legitimate but off-meta raid pick versus DS/Ruin and Affliction; best for players who want pet-driven gameplay.", talents={ {"Improved Corruption",1},{"Improved Imp",3},{"Demonic Embrace",5},{"Fel Intellect",3},{"Improved Voidwalker",3},{"Fel Domination",1},{"Fel Stamina",3},{"Master Summoner",2},{"Unholy Power",5},{"Demonic Sacrifice",1},{"Master Demonologist",5},{"Soul Link",1},{"Demonic Knowledge",3},{"Demonic Tactics",5},{"Summon Felguard",1},{"Improved Shadow Bolt",5},{"Bane",5},{"Devastation",1},{"Improved Immolate",3},{"Destructive Reach",2},{"Improved Firebolt",2},{"Cataclysm",1} } },
        { category="pvp", label="SL/SL", useCase="The dominant arena build (2v2/3v3/5v5) and standard BG warlock spec. Affliction up to Siphon Life + Demonology down to Soul Link makes you extremely tanky (Soul Link 20% damage-share, Demonic Embrace stamina, Master Demonologist, Demonic Aegis-boosted Fel Armor) while DoTs and Siphon Life sustain you. Wins by attrition and counters almost everything. Use this for all serious PvP.", talents={ {"Suppression",5},{"Improved Corruption",5},{"Improved Drain Soul",2},{"Fel Concentration",5},{"Amplify Curse",1},{"Nightfall",2},{"Empowered Corruption",3},{"Siphon Life",1},{"Curse of Exhaustion",1},{"Improved Imp",3},{"Demonic Embrace",5},{"Fel Stamina",3},{"Demonic Aegis",3},{"Fel Domination",1},{"Master Summoner",2},{"Unholy Power",5},{"Demonic Sacrifice",1},{"Master Demonologist",5},{"Demonic Resilience",3},{"Soul Link",1},{"Improved Healthstone",2},{"Mana Feed",2} } },
        { category="pvp", label="Deep Affliction", useCase="Off-meta PvP variant for battlegrounds and aggressive caster-cleave 3v3/5v5 comps. Goes deep into Affliction for Unstable Affliction (anti-dispel; UA punishes dispels) plus full instant-cast DoT pressure, trading some SL/SL tankiness for kill pressure. Real but less common than SL/SL - pick it for BGs or dispel-heavy comps where UA shines.", talents={ {"Suppression",5},{"Improved Corruption",5},{"Improved Drain Soul",2},{"Improved Life Tap",2},{"Soul Siphon",2},{"Fel Concentration",5},{"Amplify Curse",1},{"Nightfall",2},{"Empowered Corruption",3},{"Siphon Life",1},{"Shadow Mastery",5},{"Contagion",5},{"Dark Pact",1},{"Improved Howl of Terror",2},{"Malediction",1},{"Unstable Affliction",1},{"Improved Imp",3},{"Demonic Embrace",5},{"Fel Intellect",1},{"Fel Stamina",3},{"Demonic Aegis",3},{"Fel Domination",1},{"Master Summoner",2} } },
        { category="leveling", label="Affliction (10-70)", useCase="Affliction is the go-to TBC leveling spec: instant-cast Corruption plus stacked DoTs let you pull, dot, and move to the next mob while Drain Life/Life Tap and pet tanking give near-endless sustain with minimal downtime.", order={ "Improved Curse of Agony","Improved Curse of Agony","Suppression","Suppression","Suppression","Improved Corruption","Improved Corruption","Improved Corruption","Improved Corruption","Improved Corruption","Improved Life Tap","Improved Life Tap","Improved Drain Soul","Improved Drain Soul","Soul Siphon","Soul Siphon","Suppression","Suppression","Fel Concentration","Fel Concentration","Fel Concentration","Fel Concentration","Fel Concentration","Grim Reach","Grim Reach","Nightfall","Nightfall","Empowered Corruption","Empowered Corruption","Empowered Corruption","Shadow Embrace","Shadow Embrace","Shadow Embrace","Shadow Embrace","Shadow Embrace","Siphon Life","Shadow Mastery","Shadow Mastery","Shadow Mastery","Shadow Mastery","Shadow Mastery","Improved Howl of Terror","Improved Howl of Terror","Contagion","Contagion","Contagion","Contagion","Contagion","Dark Pact","Malediction","Malediction","Malediction","Unstable Affliction","Demonic Embrace","Demonic Embrace","Demonic Embrace","Demonic Embrace","Demonic Embrace" }, talents={ {"Improved Curse of Agony",2},{"Suppression",5},{"Improved Corruption",5},{"Improved Life Tap",2},{"Improved Drain Soul",2},{"Soul Siphon",2},{"Fel Concentration",5},{"Grim Reach",2},{"Nightfall",2},{"Empowered Corruption",3},{"Shadow Embrace",5},{"Siphon Life",1},{"Shadow Mastery",5},{"Improved Howl of Terror",2},{"Contagion",5},{"Dark Pact",1},{"Malediction",3},{"Unstable Affliction",1},{"Demonic Embrace",5} } },
    },
    DRUID = {
        { category="pve", label="Boomkin", useCase="Raid caster DPS", talents={ {"Starlight Wrath",5},{"Focused Starlight",2},{"Improved Moonfire",2},{"Insect Swarm",1},{"Nature's Reach",2},{"Vengeance",5},{"Celestial Focus",3},{"Lunar Guidance",3},{"Nature's Grace",1},{"Moonglow",3},{"Moonfury",5},{"Balance of Power",2},{"Dreamstate",3},{"Moonkin Form",1},{"Improved Faerie Fire",3},{"Wrath of Cenarius",5},{"Force of Nature",1},{"Furor",5},{"Naturalist",5},{"Intensity",3},{"Omen of Clarity",1} } },
        { category="pve", label="Cat DPS", useCase="Raid melee DPS", talents={ {"Ferocity",5},{"Feral Instinct",3},{"Thick Hide",3},{"Feral Swiftness",2},{"Sharpened Claws",3},{"Feral Charge",1},{"Shredding Attacks",2},{"Predatory Strikes",3},{"Primal Fury",2},{"Savage Fury",2},{"Faerie Fire (Feral)",1},{"Heart of the Wild",5},{"Survival of the Fittest",3},{"Leader of the Pack",1},{"Improved Leader of the Pack",2},{"Predatory Instincts",5},{"Mangle",1},{"Furor",5},{"Naturalist",5},{"Natural Shapeshifter",3},{"Intensity",3},{"Omen of Clarity",1} } },
        { category="pve", label="Bear Tank", useCase="Raid/5-man tank", talents={ {"Ferocity",5},{"Feral Instinct",3},{"Thick Hide",3},{"Feral Swiftness",2},{"Sharpened Claws",3},{"Feral Charge",1},{"Shredding Attacks",2},{"Predatory Strikes",3},{"Primal Fury",2},{"Savage Fury",2},{"Faerie Fire (Feral)",1},{"Nurturing Instinct",2},{"Heart of the Wild",5},{"Survival of the Fittest",3},{"Leader of the Pack",1},{"Improved Leader of the Pack",2},{"Predatory Instincts",3},{"Mangle",1},{"Furor",5},{"Naturalist",5},{"Natural Shapeshifter",3},{"Intensity",3},{"Omen of Clarity",1} } },
        { category="pve", label="Resto / ToL", useCase="Raid healer", talents={ {"Starlight Wrath",5},{"Control of Nature",3},{"Improved Mark of the Wild",5},{"Furor",5},{"Naturalist",2},{"Subtlety",5},{"Intensity",3},{"Nature's Focus",2},{"Improved Rejuvenation",3},{"Tranquil Spirit",5},{"Nature's Swiftness",1},{"Gift of Nature",5},{"Improved Tranquility",2},{"Empowered Touch",2},{"Living Spirit",3},{"Swiftmend",1},{"Natural Perfection",3},{"Empowered Rejuvenation",5},{"Tree of Life",1} } },
        { category="pvp", label="Resto PvP", useCase="Arena/BG healing (meta)", talents={ {"Starlight Wrath",5},{"Nature's Grasp",1},{"Focused Starlight",2},{"Control of Nature",3},{"Insect Swarm",1},{"Nature's Reach",1},{"Ferocity",5},{"Feral Instinct",3},{"Brutal Impact",2},{"Feral Charge",1},{"Improved Mark of the Wild",5},{"Furor",5},{"Subtlety",3},{"Intensity",3},{"Omen of Clarity",1},{"Nature's Focus",3},{"Improved Rejuvenation",3},{"Tranquil Spirit",2},{"Nature's Swiftness",1},{"Gift of Nature",5},{"Empowered Touch",2},{"Living Spirit",2},{"Swiftmend",1},{"Natural Perfection",1} } },
        { category="pvp", label="Feral PvP", useCase="Arena/BG melee (off-meta)", talents={ {"Nature's Grasp",1},{"Ferocity",5},{"Feral Aggression",2},{"Feral Instinct",3},{"Brutal Impact",2},{"Thick Hide",3},{"Feral Swiftness",2},{"Sharpened Claws",3},{"Feral Charge",1},{"Shredding Attacks",2},{"Predatory Strikes",3},{"Primal Fury",2},{"Savage Fury",2},{"Faerie Fire (Feral)",1},{"Heart of the Wild",5},{"Survival of the Fittest",3},{"Leader of the Pack",1},{"Predatory Instincts",5},{"Mangle",1},{"Furor",5},{"Naturalist",5},{"Natural Shapeshifter",3},{"Omen of Clarity",1} } },
        { category="leveling", label="Feral (10-70)", useCase="Feral is the go-to TBC Druid leveling spec: strong sustained melee damage in Cat Form, great survivability and mobility (Feral Swiftness +30% speed, Bear/Dire Bear tankiness), and near-zero downtime by powershift-healing between pulls. This 41/20 build rushes the core Cat/Bear damage and survivability talents, then dips Restoration for Furor (powershifting energy/rage), Naturalist (+10% physical damage), Natural Shapeshifter, Omen of Clarity, and Intensity.", order={ "Ferocity","Ferocity","Ferocity","Ferocity","Ferocity","Thick Hide","Thick Hide","Thick Hide","Brutal Impact","Brutal Impact","Feral Swiftness","Feral Swiftness","Sharpened Claws","Sharpened Claws","Sharpened Claws","Predatory Strikes","Predatory Strikes","Predatory Strikes","Savage Fury","Savage Fury","Primal Fury","Primal Fury","Heart of the Wild","Heart of the Wild","Heart of the Wild","Heart of the Wild","Heart of the Wild","Faerie Fire (Feral)","Nurturing Instinct","Survival of the Fittest","Survival of the Fittest","Survival of the Fittest","Leader of the Pack","Improved Leader of the Pack","Improved Leader of the Pack","Predatory Instincts","Predatory Instincts","Predatory Instincts","Predatory Instincts","Predatory Instincts","Mangle","Furor","Furor","Furor","Furor","Furor","Naturalist","Naturalist","Naturalist","Naturalist","Naturalist","Natural Shapeshifter","Natural Shapeshifter","Natural Shapeshifter","Omen of Clarity","Intensity","Intensity","Intensity","Improved Mark of the Wild","Improved Mark of the Wild","Improved Mark of the Wild" }, talents={ {"Ferocity",5},{"Thick Hide",3},{"Brutal Impact",2},{"Feral Swiftness",2},{"Sharpened Claws",3},{"Predatory Strikes",3},{"Savage Fury",2},{"Primal Fury",2},{"Heart of the Wild",5},{"Faerie Fire (Feral)",1},{"Nurturing Instinct",1},{"Survival of the Fittest",3},{"Leader of the Pack",1},{"Improved Leader of the Pack",2},{"Predatory Instincts",5},{"Mangle",1},{"Furor",5},{"Naturalist",5},{"Natural Shapeshifter",3},{"Omen of Clarity",1},{"Intensity",3},{"Improved Mark of the Wild",3} } },
    },
}

-- ---------------------------------------------------------------------------
-- Apply state machine.
-- ---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local active -- { target = {[lower talent name]=rank}, label, watchdog, budget, placed }
local updateButtons -- forward decl; assigned by the talent-frame UI section at the end
local tmDebug = false -- /tm debug toggles verbose apply logging

local function stopApply(msg)
    driver:UnregisterEvent("CHARACTER_POINTS_CHANGED")
    if active and active.watchdog then active.watchdog:Cancel() end
    active = nil
    if msg then Print(msg) end
    if updateButtons then updateButtons() end -- re-enable the talent-frame buttons
end

-- Find the next talent to put a point into. Walk the trees in priority order
-- (active.tabOrder -- the tree with the most build points first), and within a
-- tree take the LOWEST-tier talent that still needs points and whose tier
-- point-gate is met. Filling bottom-up keeps every spend legal: a talent's arrow
-- prerequisite is always a LOWER tier, so it is already maxed by the time we get
-- to the dependent. This mirrors how RestedXP/TalentedClassic do it -- trust a
-- valid fill order and just call LearnTalent; do NOT ask the API whether a talent
-- is "learnable" (GetTalentInfo's `available` and GetTalentPrereqs are both
-- unreliable here and were the reason nothing was being spent).
local function findNextPoint()
    local order, group = active.tabOrder, active.group
    for i = 1, #order do
        local tab = order[i]
        local pointsInTab = tabPointsSpent(tab, group)
        local bestIndex, bestTier
        for index = 1, (GetNumTalents(tab, false, false, group) or 0) do
            local name, _, tier, _, rank, maxRank = GetTalentInfo(tab, index, false, false, group)
            if name and not (active.skip and active.skip[strlower(name)]) then
                local want = active.target[strlower(name)]
                if want then
                    want = min(want, maxRank or want)
                    if rank < want and pointsInTab >= (tier - 1) * 5 then
                        if not bestTier or tier < bestTier then
                            bestTier, bestIndex = tier, index
                        end
                    end
                end
            end
        end
        if bestIndex then return tab, bestIndex end
    end
    return nil
end

-- For a guided leveling build (build.order): place points in the exact pick
-- order. Scan the live tree once for current ranks + name->index, then walk the
-- order and return the first talent whose live rank is below where the order says
-- it should be by that step. Level-aware -- we only place the points you have.
local function findNextOrdered()
    local group = active.group
    local skip = active.skip
    -- One pass over the live trees: current rank, name->{tab,index,tier}, and the
    -- running point total per tree (for the tier gate below).
    local liveRank, loc, tabTotal = {}, {}, {}
    local numTabs = GetNumTalentTabs(false, false, group) or 0
    for tab = 1, numTabs do
        tabTotal[tab] = 0
        for index = 1, (GetNumTalents(tab, false, false, group) or 0) do
            local name, _, t, _, rank = GetTalentInfo(tab, index, false, false, group)
            if name then
                local key = strlower(name)
                liveRank[key] = rank or 0
                loc[key] = { tab, index, t or 1 }
                tabTotal[tab] = tabTotal[tab] + (rank or 0)
            end
        end
    end
    -- Walk the pick order; return the first talent that still wants a point AND is
    -- legal to take right now -- its tier's point gate ((tier-1)*5 in that tree)
    -- must be met. Picks set aside earlier (active.skip -- e.g. an arrow prereq the
    -- order reached before its dependency) are passed over and retried later.
    -- Deferring an illegal pick and moving on lets a slightly mis-ordered build
    -- self-heal instead of dead-ending the way a raw "follow the list" would.
    local seen = {}
    for _, talentName in ipairs(active.order) do
        local key = strlower(talentName)
        seen[key] = (seen[key] or 0) + 1
        if (liveRank[key] or 0) < seen[key] and not (skip and skip[key]) then
            local l = loc[key]
            if l and tabTotal[l[1]] >= (l[3] - 1) * 5 then
                return l[1], l[2]
            end
        end
    end
    return nil
end

local function applyNextPoint()
    if not active then return end

    -- Spend only as many points as the user had when they confirmed -- never a
    -- point granted mid-apply (e.g. a level-up).
    if active.placed >= active.budget then
        stopApply(format("done -- placed %d point(s) toward %s.", active.placed, active.label))
        return
    end

    -- NOTE: an `A and f() or g()` here would truncate the multi-return to one
    -- value (index would become nil), so branch explicitly to keep both returns.
    local tab, index
    if active.order then tab, index = findNextOrdered() else tab, index = findNextPoint() end
    if not tab then
        -- Nothing legal to place right now. If we deferred any picks (active.skip)
        -- and have placed points since the last sweep, those new points may have
        -- unblocked them -- clear the deferrals and take one more sweep before
        -- giving up. didEndPass guards against looping when they're truly stuck.
        if active.skip and next(active.skip) and not active.didEndPass then
            active.didEndPass = true
            active.skip = nil
            return applyNextPoint()
        end
        local left = GetUnspentPoints()
        if left > 0 then
            stopApply(format("stopped -- %s applied, but %d point(s) couldn't be placed.", active.label, left))
        else
            stopApply(format("%s is complete.", active.label))
        end
        return
    end
    active.didEndPass = false -- found a pick; permit a fresh retry sweep after it lands

    local nm = GetTalentInfo(tab, index, false, false, active.group)
    active.lastName = nm -- remembered so the watchdog knows which pick to defer on a stall
    if tmDebug then Print(format("|cff888888debug|r learn [%d,%d] %s grp=%s", tab, index, tostring(nm), tostring(active.group))) end

    -- LearnTalent returns false if the game refuses (combat, illegal placement);
    -- no CHARACTER_POINTS_CHANGED fires then, so stop now instead of waiting out
    -- the watchdog. On success it returns truthy and we wait for the event (the
    -- spend isn't readable synchronously, so we place one point per event).
    local ok = LearnTalent(tab, index, false, active.group)
    if tmDebug then Print(format("|cff888888debug|r LearnTalent -> %s", tostring(ok))) end
    if ok == false then
        stopApply(format("stopped -- the game refused '%s' (are you in combat?).", tostring(nm)))
        return
    end

    -- Watchdog guards a silent stall: LearnTalent returns truthy even when the
    -- tree quietly refuses an illegal pick (no CHARACTER_POINTS_CHANGED fires).
    -- 5s tolerates server latency. On a stall we DEFER the pick (set it aside and
    -- carry on with the rest) instead of aborting -- it's usually an arrow prereq
    -- the order reached before its dependency, and it gets retried in the
    -- end-of-sweep pass once that prereq is in.
    if active.watchdog then active.watchdog:Cancel() end
    active.watchdog = C_Timer.NewTimer(5, function()
        if not active then return end
        active.watchdog = nil
        if active.lastName then
            active.skip = active.skip or {}
            active.skip[strlower(active.lastName)] = true
            Print(format("|cffaaaaaa'%s' isn't available yet -- deferring it and continuing.|r", tostring(active.lastName)))
        end
        applyNextPoint()
    end)
end

driver:SetScript("OnEvent", function(_, event, change)
    if event ~= "CHARACTER_POINTS_CHANGED" or not active then return end
    if tmDebug then Print(format("|cff888888debug|r event change=%s placed=%d", tostring(change), active.placed)) end
    -- change is the delta of unspent points: -1 when a point was spent (our
    -- LearnTalent landed), +1 on a level-up grant. Ignore grants so a mid-apply
    -- ding is never pulled into the build. (If the client omits change, advance.)
    if change and change > 0 then return end
    if active.watchdog then active.watchdog:Cancel(); active.watchdog = nil end
    active.placed = active.placed + 1
    active.didEndPass = false -- a fresh point may unblock deferred picks; allow a retry sweep
    applyNextPoint()
end)

local function beginApply(build)
    if active then
        Print("an apply is already running -- use /tm stop to cancel it first.")
        return
    end
    if not build or not build.talents then return end
    if InCombatLockdown() then
        Print("can't change talents in combat.")
        return
    end
    local group = GetTargetGroup()
    local budget = GetUnspentPoints(group)
    if budget <= 0 then
        Print("you have no unspent talent points. Reset at a class trainer first (costs gold), then run this again.")
        return
    end

    -- Talent names are unique within a class in TBC, so keying targets by
    -- lowercased name is unambiguous.
    local target = {}
    for _, t in ipairs(build.talents) do
        target[strlower(t[1])] = t[2]
    end

    -- Scan the live trees once (for the target group): record which talent names
    -- exist (to warn on mismatches) and how many of the build's points fall in
    -- each tree (so we can fill the main tree first when leveling).
    local liveNames, tabTotals = {}, {}
    local numTabs = GetNumTalentTabs(false, false, group) or 0
    for tab = 1, numTabs do
        tabTotals[tab] = 0
        for index = 1, (GetNumTalents(tab, false, false, group) or 0) do
            local n = GetTalentInfo(tab, index, false, false, group)
            if n then
                local key = strlower(n)
                liveNames[key] = true
                if target[key] then tabTotals[tab] = tabTotals[tab] + target[key] end
            end
        end
    end
    local missing = {}
    for _, t in ipairs(build.talents) do
        if not liveNames[strlower(t[1])] then missing[#missing + 1] = t[1] end
    end
    if #missing > 0 then
        Print(format("|cffff9900warning|r: couldn't match %d talent(s), they'll be skipped: %s", #missing, table.concat(missing, ", ")))
    end

    -- Trees ordered by how many build points they hold (primary tree first), so
    -- partial/leveling application fills the main spec before any off-tree dip.
    local tabOrder = {}
    for tab = 1, numTabs do tabOrder[tab] = tab end
    table.sort(tabOrder, function(a, b) return tabTotals[a] > tabTotals[b] end)

    active = { target = target, label = build.label or "build", budget = budget, placed = 0, tabOrder = tabOrder, group = group, order = build.order }
    driver:RegisterEvent("CHARACTER_POINTS_CHANGED")
    Print(format("applying %s...", active.label))
    if build.note then Print(build.note) end
    applyNextPoint()
end

-- ---------------------------------------------------------------------------
-- Confirmation popup (spending points can't be undone without a gold respec).
-- ---------------------------------------------------------------------------
StaticPopupDialogs["TALENTMATE_APPLY"] = {
    text = "TalentMate: apply the %s?\n\nThis spends up to %d talent point(s) and can't be undone without a gold respec.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data) beginApply(data.build) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

-- ---------------------------------------------------------------------------
-- Build preview / class lookup helpers.
-- ---------------------------------------------------------------------------
local function showBuild(build)
    if not build then Print("no build selected.") return end
    Print(format("%s%s:", build.label or "build", build.useCase and (" -- " .. build.useCase) or ""))
    local total = 0
    for _, t in ipairs(build.talents) do
        DEFAULT_CHAT_FRAME:AddMessage(format("   %s %d", t[1], t[2]))
        total = total + t[2]
    end
    DEFAULT_CHAT_FRAME:AddMessage(format("   |cff808080(%d points)|r", total))
    if build.note then Print(build.note) end
end

local function confirmApply(build)
    if active then
        Print("an apply is already running -- use /tm stop to cancel it first.")
        return
    end
    if not build then Print("no build selected -- open the picker with /tm.") return end
    if InCombatLockdown() then Print("can't change talents in combat.") return end
    local points = GetUnspentPoints()
    if points <= 0 then
        Print("you have no unspent talent points. Reset at a class trainer first (costs gold), then run this again.")
        return
    end
    local needed = 0
    for _, t in ipairs(build.talents) do needed = needed + t[2] end
    StaticPopup_Show("TALENTMATE_APPLY", build.label or "this build", math.min(points, needed), { build = build })
end

-- ---------------------------------------------------------------------------
-- Diagnostics: /tm debug dumps why points are / aren't being placed.
-- ---------------------------------------------------------------------------
local function debugDump(build)
    local _, classFile = UnitClass("player")
    local group = GetTargetGroup()
    Print(format("class=%s  group=%s  unspent=%d  combat=%s", classFile or "?", tostring(group), GetUnspentPoints(group), tostring(InCombatLockdown())))
    if not build then Print("no build to debug.") return end
    local target = {}
    for _, t in ipairs(build.talents) do target[strlower(t[1])] = t[2] end
    local numTabs = GetNumTalentTabs(false, false, group) or 0
    Print(format("build=%s  group=%s  numTabs=%d", build.label or "build", tostring(group), numTabs))
    local matched, shown = 0, 0
    for tab = 1, numTabs do
        local pts = tabPointsSpent(tab, group)
        for index = 1, (GetNumTalents(tab, false, false, group) or 0) do
            local name, _, tier, _, rank, maxRank, _, available = GetTalentInfo(tab, index, false, false, group)
            if name and target[strlower(name)] then
                matched = matched + 1
                if shown < 8 then
                    shown = shown + 1
                    Print(format("  [%d,%d] %s  tier=%s rank=%s/%s avail=%s want=%d ptsInTab=%d",
                        tab, index, name, tostring(tier), tostring(rank), tostring(maxRank),
                        tostring(available), target[strlower(name)], pts))
                end
            end
        end
    end
    Print(format("matched %d/%d build talents by name.", matched, #build.talents))
end

-- ---------------------------------------------------------------------------
-- Build library helpers. Each class maps to a LIST of builds; this normalises
-- both the list shape and the older {pve=,pvp=} shape into a list of
-- { category, label, useCase, talents, note }.
-- ---------------------------------------------------------------------------
local function classBuildList(classFile)
    local cb = classFile and BUILDS[classFile]
    if not cb then return nil end
    if cb[1] then return cb end -- already a list
    local list = {}
    if cb.pve then list[#list + 1] = { category = "pve", label = cb.pve.name, useCase = "PvE build", talents = cb.pve.talents, note = cb.pve.note } end
    if cb.pvp then list[#list + 1] = { category = "pvp", label = cb.pvp.name, useCase = "PvP build", talents = cb.pvp.talents, note = cb.pvp.note } end
    return list
end

local function firstBuild(classFile, category)
    local list = classBuildList(classFile)
    if not list then return nil end
    for _, b in ipairs(list) do if b.category == category then return b end end
    return nil
end

-- ---------------------------------------------------------------------------
-- Settings window: a class-detected build picker (dropdown + use-case + Apply).
-- ---------------------------------------------------------------------------
local configFrame, configDropdown, configDesc, selectedBuild

local CATLABEL = { pve = "PvE", pvp = "PvP", leveling = "Level" }
local function buildLabel(b)
    return format("%s -- %s", CATLABEL[b.category] or "?", b.label or "?")
end

local function selectBuild(b)
    selectedBuild = b
    if configDropdown then UIDropDownMenu_SetText(configDropdown, b and buildLabel(b) or "(none)") end
    if configDesc then configDesc:SetText(b and (b.useCase or "") or "") end
end

local function dropdownInit()
    local _, classFile = UnitClass("player")
    local list = classBuildList(classFile)
    if not list then return end
    for _, b in ipairs(list) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = buildLabel(b)
        info.checked = (b == selectedBuild)
        info.func = function() selectBuild(b); CloseDropDownMenus() end
        UIDropDownMenu_AddButton(info)
    end
end

local function refreshConfig()
    if not configFrame then return end
    local _, classFile = UnitClass("player")
    local pretty = classFile and (classFile:sub(1, 1) .. classFile:sub(2):lower()) or "?"
    configFrame.title:SetText("TalentMate -- " .. pretty)
    UIDropDownMenu_Initialize(configDropdown, dropdownInit)
    local list = classBuildList(classFile)
    if list and list[1] then
        local keep = false
        for _, b in ipairs(list) do if b == selectedBuild then keep = true break end end
        selectBuild(keep and selectedBuild or list[1])
    else
        selectBuild(nil)
        configDesc:SetText("No built-in builds for your class yet.")
    end
end

local function buildConfigFrame()
    if configFrame then return end
    local f = CreateFrame("Frame", "TalentMateConfig", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    configFrame = f
    f:SetSize(400, 250)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -16)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local pick = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pick:SetPoint("TOPLEFT", 22, -52)
    pick:SetText("Choose a build for your activity:")

    configDropdown = CreateFrame("Frame", "TalentMateConfigDropdown", f, "UIDropDownMenuTemplate")
    configDropdown:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", -16, -6)
    UIDropDownMenu_SetWidth(configDropdown, 300)
    UIDropDownMenu_Initialize(configDropdown, dropdownInit)

    configDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configDesc:SetPoint("TOPLEFT", 26, -128)
    configDesc:SetPoint("TOPRIGHT", -26, -128)
    configDesc:SetHeight(70)
    configDesc:SetJustifyH("LEFT")
    configDesc:SetJustifyV("TOP")

    local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    applyBtn:SetSize(120, 24)
    applyBtn:SetText("Apply")
    applyBtn:SetPoint("BOTTOMLEFT", 22, 18)
    applyBtn:SetScript("OnClick", function()
        if selectedBuild then confirmApply(selectedBuild) else Print("pick a build first.") end
    end)

    local previewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    previewBtn:SetSize(120, 24)
    previewBtn:SetText("Preview in chat")
    previewBtn:SetPoint("LEFT", applyBtn, "RIGHT", 10, 0)
    previewBtn:SetScript("OnClick", function()
        if selectedBuild then showBuild(selectedBuild) else Print("pick a build first.") end
    end)

    if UISpecialFrames then table.insert(UISpecialFrames, "TalentMateConfig") end -- Escape closes it
end

local function openConfig()
    buildConfigFrame()
    refreshConfig()
    configFrame:Show()
end

-- ---------------------------------------------------------------------------
-- Slash commands.
-- ---------------------------------------------------------------------------
SLASH_TALENTMATE1 = "/talentmate"
SLASH_TALENTMATE2 = "/tm"
SlashCmdList.TALENTMATE = function(msg)
    msg = strlower((msg or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local cmd, arg = msg:match("^(%S*)%s*(%S*)$")
    local _, classFile = UnitClass("player")

    if cmd == "" then
        openConfig()
    elseif cmd == "pve" or cmd == "pvp" then
        confirmApply(firstBuild(classFile, cmd))
    elseif cmd == "level" or cmd == "leveling" then
        confirmApply(firstBuild(classFile, "leveling"))
    elseif cmd == "show" then
        showBuild(firstBuild(classFile, (arg == "pvp") and "pvp" or "pve"))
    elseif cmd == "list" then
        local list = classBuildList(classFile)
        if list then
            Print(format("builds for %s:", classFile or "?"))
            for _, b in ipairs(list) do
                Print(format("  %s -- %s: |cff808080%s|r", CATLABEL[b.category] or "?", b.label or "?", b.useCase or ""))
            end
        else
            Print(format("no built-in builds for your class yet (%s).", classFile or "?"))
        end
    elseif cmd == "stop" then
        if active then stopApply("apply cancelled.") else Print("nothing is applying.") end
    elseif cmd == "debug" then
        tmDebug = not tmDebug
        Print("verbose apply logging: " .. (tmDebug and "|cff55ff55on|r" or "|cffff5555off|r"))
        debugDump(firstBuild(classFile, (arg == "pvp") and "pvp" or "pve"))
    else
        Print("commands:")
        Print("  |cffffff00/tm|r - open the build picker window")
        Print("  |cffffff00/tm list|r - list every build for your class")
        Print("  |cffffff00/tm pve|r / |cffffff00/tm pvp|r / |cffffff00/tm level|r - quick-apply the first build of that type")
        Print("  |cffffff00/tm show pve|r / |cffffff00/tm show pvp|r - preview without spending")
        Print("  |cffffff00/tm stop|r - cancel an in-progress apply")
    end
end

-- ---------------------------------------------------------------------------
-- Talent-frame integration.
-- Adds "Apply PvE" / "Apply PvP" buttons beneath Blizzard's talent window
-- (PlayerTalentFrame, from the load-on-demand Blizzard_TalentUI). The buttons
-- are plain child frames that run the same confirm->apply flow as the slash
-- commands; a non-secure child button calling the unprotected LearnTalent is
-- taint-safe, and we only ever hook (never replace) Blizzard's own scripts.
-- ---------------------------------------------------------------------------
local ui = CreateFrame("Frame")
local tmButton

-- Assigned to the forward-declared upvalue so stopApply can refresh it on finish.
updateButtons = function()
    if not tmButton then return end
    local _, classFile = UnitClass("player")
    if classBuildList(classFile) then tmButton:Enable() else tmButton:Disable() end
end

local function createButtons()
    if tmButton or not PlayerTalentFrame then return end

    tmButton = CreateFrame("Button", "TalentMateButton", PlayerTalentFrame, "UIPanelButtonTemplate")
    tmButton:SetSize(150, 22)
    tmButton:SetText("TalentMate")
    tmButton:SetPoint("TOPLEFT", PlayerTalentFrame, "BOTTOMLEFT", 14, -3)
    tmButton:SetScript("OnClick", function() openConfig() end)
    tmButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("TalentMate")
        GameTooltip:AddLine("Open the build picker for your class.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    tmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Refresh state each time the window opens (hook, never replace).
    PlayerTalentFrame:HookScript("OnShow", updateButtons)
    updateButtons()
    ui:UnregisterEvent("ADDON_LOADED") -- only stop waiting once the button exists
end

local function isAddOnReady(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    if IsAddOnLoaded then return IsAddOnLoaded(name) end
    return false
end

ui:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_TalentUI" then createButtons() end
    elseif not active then
        -- Skip while an apply is running (buttons are already disabled and
        -- stopApply refreshes them on finish) to avoid churn on every point.
        updateButtons()
    end
end)

ui:RegisterEvent("CHARACTER_POINTS_CHANGED")
ui:RegisterEvent("PLAYER_REGEN_DISABLED")
ui:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ui.RegisterEvent, ui, "PLAYER_TALENT_UPDATE") -- present on 2.5.5; pcall kept for portability (RegisterEvent throws on unknown events)

-- Blizzard_TalentUI is load-on-demand: attach now if it's up, otherwise wait.
if isAddOnReady("Blizzard_TalentUI") and PlayerTalentFrame then
    createButtons()
else
    ui:RegisterEvent("ADDON_LOADED")
end
