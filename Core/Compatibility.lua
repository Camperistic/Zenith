--[[ Core/Compatibility.lua  ──────────────────────────────────────────────────
     Loaded FIRST (before LibStub). Normalises cross-flavour API differences into
     a single ns.compat table so the rest of the addon never branches on client
     version. Add a shim here, not an `if WOW_PROJECT_ID` scattered in a module.

     No LibStub / Ace usage in this file — it runs before the libraries load.
]]
local ADDON, ns = ...
ns = ns or {}
local C = {}
ns.compat = C

local _G = _G

-- Addon metadata (moved to C_AddOns on the 11.x-based clients).
C.GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata

-- Spell APIs (C_Spell on modern clients; the globals still exist on Classic).
C.GetSpellCooldown = _G.GetSpellCooldown or (C_Spell and C_Spell.GetSpellCooldown and function(id)
	local info = C_Spell.GetSpellCooldown(id)
	if info then return info.startTime, info.duration, info.isEnabled, info.modRate end
end)
C.GetSpellTexture = _G.GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture)
C.GetSpellInfo    = _G.GetSpellInfo or (C_Spell and C_Spell.GetSpellInfo and function(id)
	local info = C_Spell.GetSpellInfo(id)
	if info then return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID end
end)
C.IsSpellKnown    = _G.IsSpellKnown
C.IsPlayerSpell   = _G.IsPlayerSpell
C.IsSpellInRange  = _G.IsSpellInRange

-- Item APIs (C_Item / C_Container on modern clients).
C.GetItemInfo  = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
C.GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
C.GetItemStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats
C.GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
C.GetContainerItemID   = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
C.GetContainerItemInfo = (C_Container and C_Container.GetContainerItemInfo) or _G.GetContainerItemInfo
C.GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
C.GetItemInfoInstant   = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

-- Quest log (C_QuestLog is the modern surface; provide stable wrappers).
C.IsQuestFlaggedCompleted = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or _G.IsQuestFlaggedCompleted
C.GetLogIndexForQuestID   = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
C.GetQuestObjectives      = C_QuestLog and C_QuestLog.GetQuestObjectives
C.IsQuestComplete         = C_QuestLog and C_QuestLog.IsComplete

-- Map (present on every supported client via C_Map).
C.GetBestMapForUnit    = C_Map and C_Map.GetBestMapForUnit
C.GetPlayerMapPosition = C_Map and C_Map.GetPlayerMapPosition
C.GetMapInfo           = C_Map and C_Map.GetMapInfo

-- Bag iteration bounds (KEYRING only exists on Classic).
C.FIRST_BAG = _G.BACKPACK_CONTAINER or 0
C.LAST_BAG  = _G.NUM_BAG_SLOTS or 4
