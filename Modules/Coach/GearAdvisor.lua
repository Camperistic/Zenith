--[[ Modules/Coach/GearAdvisor.lua

     Real-time gear scoring — math, not a BiS database. On each item you acquire it:
       1. scans the tooltip and rejects anything with RED text (unmet level / class /
          armour / skill requirement — i.e. you can't use it),
       2. reads the item's actual stats (GetItemStats) + weapon DPS (tooltip),
       3. scores them against your spec's stat weights,
       4. compares to what's equipped in that slot (the lower of two for rings/
          trinkets/weapons),
       5. if it's a real upgrade, announces it in chat — and auto-equips it when you've
          turned that on (/zen autoequip; out of combat only — equipping is protected
          in combat, and auto-equipping a BoE binds it, so it's opt-in).

     Weights are per spec (leveling). Adjusting a spec is data, not code.
]]
local ADDON, ns = ...
local Bus, State, Theme, C = ns.Bus, ns.State, ns.Theme, ns.compat

local Gear = {}
ns.Gear = Gear

-- ── stat weights (GetItemStats keys → weight), per class leveling spec ──────────
local k = {
	STR="ITEM_MOD_STRENGTH_SHORT", AGI="ITEM_MOD_AGILITY_SHORT", STA="ITEM_MOD_STAMINA_SHORT",
	INT="ITEM_MOD_INTELLECT_SHORT", SPI="ITEM_MOD_SPIRIT_SHORT",
	AP="ITEM_MOD_ATTACK_POWER_SHORT", RAP="ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
	CRIT="ITEM_MOD_CRIT_RATING_SHORT", HIT="ITEM_MOD_HIT_RATING_SHORT", HASTE="ITEM_MOD_HASTE_RATING_SHORT",
	SP="ITEM_MOD_SPELL_POWER", SPDMG="ITEM_MOD_SPELL_DAMAGE_DONE",
	SPHIT="ITEM_MOD_SPELL_HIT_RATING_SHORT", SPCRIT="ITEM_MOD_SPELL_CRIT_RATING_SHORT",
	MP5="ITEM_MOD_POWER_REGEN0_SHORT", ARMOR="RESISTANCE0_NAME",
}
local function W(t) local o = {} for key, v in pairs(t) do o[k[key] or key] = v end return o end

-- dpsW = weight applied to weapon DPS (the dominant term for a weapon slot).
local WEIGHTS = {
	WARRIOR = { w = W{ STR=1, AGI=.5, STA=.3, AP=.5, CRIT=.6, HIT=.8, ARMOR=.02 }, dps = 6 },
	PALADIN = { w = W{ STR=1, STA=.3, AP=.5, CRIT=.6, HIT=.8, INT=.15, ARMOR=.02 }, dps = 6 },
	ROGUE   = { w = W{ AGI=1, AP=.4, CRIT=.5, HIT=.9, HASTE=.4 }, dps = 7 },
	HUNTER  = { w = W{ AGI=1, RAP=.5, AP=.35, CRIT=.7, HIT=1.0, STA=.3 }, dps = 5, ranged = true },
	SHAMAN  = { w = W{ AGI=.8, STR=.8, AP=.5, HIT=.8, CRIT=.5, INT=.2 }, dps = 5 },
	DRUID   = { w = W{ AGI=1, STR=.7, AP=.5, CRIT=.6, HIT=.7, STA=.2 }, dps = 5, feral = true },
	MAGE    = { w = W{ SP=1, SPDMG=1, SPHIT=.9, INT=.4, SPCRIT=.6, SPI=.15, STA=.2 }, dps = 0 },
	WARLOCK = { w = W{ SP=1, SPDMG=1, SPHIT=.9, STA=.4, INT=.3, SPCRIT=.5, SPI=.1 }, dps = 0 },
	PRIEST  = { w = W{ SP=1, SPDMG=1, SPHIT=.9, INT=.4, SPCRIT=.6, SPI=.3, STA=.2 }, dps = 0 },
}
local function weights() return WEIGHTS[State:Class() or ""] end

-- ── hidden scanning tooltip: usability (red text) + weapon DPS ──────────────────
local scan = CreateFrame("GameTooltip", "ZenithScanTip", nil, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

local function scanBagItem(bag, slot)
	scan:ClearLines()
	scan:SetBagItem(bag, slot)
	local usable, dps = true, nil
	for i = 2, scan:NumLines() do
		local line = _G["ZenithScanTipTextLeft" .. i]
		if line then
			local r, g, b = line:GetTextColor()
			if r and r > 0.9 and g < 0.2 and b < 0.2 then usable = false end   -- red = requirement not met
			local txt = line:GetText()
			if txt then local d = txt:match("%(([%d%.]+) damage per second%)"); if d then dps = tonumber(d) end end
		end
	end
	return usable, dps
end

-- ── equip-slot mapping ──────────────────────────────────────────────────────────
local SLOTS = {
	INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5},
	INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8},
	INVTYPE_WRIST = {9}, INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
	INVTYPE_CLOAK = {15}, INVTYPE_WEAPON = {16, 17}, INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_2HWEAPON = {16},
	INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17}, INVTYPE_RANGED = {18},
	INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18}, INVTYPE_RELIC = {18},
}

-- ── scoring (the math) ──────────────────────────────────────────────────────────
function Gear:Score(link, dps)
	local wt = weights(); if not (wt and link) then return 0 end
	local s, stats = 0, C.GetItemStats and C.GetItemStats(link)
	if stats then for stat, val in pairs(stats) do s = s + (val * (wt.w[stat] or 0)) end end
	if dps and dps > 0 and wt.dps > 0 then s = s + dps * wt.dps end
	return s
end

local function equippedScore(slotID)
	local link = GetInventoryItemLink("player", slotID)
	if not link then return 0, nil end
	scan:ClearLines(); scan:SetInventoryItem("player", slotID)
	local dps
	for i = 2, scan:NumLines() do
		local t = _G["ZenithScanTipTextLeft" .. i]; local txt = t and t:GetText()
		if txt then local d = txt:match("%(([%d%.]+) damage per second%)"); if d then dps = tonumber(d) end end
	end
	return Gear:Score(link, dps), link
end

-- ── evaluate one bag item ───────────────────────────────────────────────────────
local MARGIN = 1.0   -- must beat the equipped score by more than this to count
local function evaluate(bag, slot)
	local link = C.GetContainerItemLink and C.GetContainerItemLink(bag, slot)
	if not link then return end
	-- GetItemInfoInstant is the cheap, always-available path for equipLoc
	local equipLoc
	if C.GetItemInfoInstant then local _, _, _, eloc = C.GetItemInfoInstant(link); equipLoc = eloc end
	if not equipLoc and C.GetItemInfo then local _, _, _, el = C.GetItemInfo(link); equipLoc = el end
	local slots = equipLoc and SLOTS[equipLoc]
	if not slots then return end                       -- not equippable gear

	local usable, dps = scanBagItem(bag, slot)
	if not usable then return end                      -- red text → can't use it

	local newScore = Gear:Score(link, dps)
	-- compare to the WORSE-scored of the candidate slots (that's the one to replace)
	local worstScore, worstSlot, worstLink = math.huge, nil, nil
	for _, sid in ipairs(slots) do
		local es, el = equippedScore(sid)
		if es < worstScore then worstScore, worstSlot, worstLink = es, sid, el end
	end
	if newScore > worstScore + MARGIN then
		return { link = link, slot = worstSlot, newScore = newScore, oldScore = worstScore, oldLink = worstLink, bag = bag, bslot = slot }
	end
end

-- ── act on found upgrades ───────────────────────────────────────────────────────
local pendingEquip
local function announce(up)
	local pct = up.oldScore > 0 and string.format(" (+%d%%)", math.floor((up.newScore / up.oldScore - 1) * 100)) or ""
	ns:Print(Theme:Color("gold", "Upgrade") .. ": " .. (up.link or "?")
		.. (up.oldLink and (" over " .. up.oldLink) or " (empty slot)") .. Theme:Color("dim", pct))
end

local function tryEquip(up)
	if not ns.db.profile.autoEquip then return false end
	if InCombatLockdown() then pendingEquip = pendingEquip or {}; pendingEquip[#pendingEquip + 1] = up; return false end
	EquipItemByName(up.link, up.slot)
	ns:Print(Theme:Color("accent", "Equipped") .. " " .. up.link .. (up.oldLink and (" (replaced " .. up.oldLink .. ")") or ""))
	return true
end

local seenAutoHint = false
function Gear:ScanBags()
	if not weights() then return end
	local first = C.FIRST_BAG or 0
	for bag = first, (C.LAST_BAG or 4) do
		for s = 1, (C.GetContainerNumSlots and C.GetContainerNumSlots(bag) or 0) do
			local up = evaluate(bag, s)
			if up then
				announce(up)
				if not tryEquip(up) and not ns.db.profile.autoEquip and not seenAutoHint then
					seenAutoHint = true
					ns:Print(Theme:Color("dim", "Type ") .. "/zen autoequip" .. Theme:Color("dim", " to auto-equip upgrades."))
				end
			end
		end
	end
end

local pending
local function debounced() if pending then return end; pending = true; C_Timer.After(0.5, function() pending = nil; Gear:ScanBags() end) end

ns.Registry:Add({
	name = "GearAdvisor",
	OnEnable = function()
		Bus:On("BAGS_CHANGED", debounced)
		local f = CreateFrame("Frame"); f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function()
			if pendingEquip then for _, up in ipairs(pendingEquip) do tryEquip(up) end; pendingEquip = nil end
		end)
		Bus:On("SLASH", function(msg)
			if msg == "autoequip" then
				ns.db.profile.autoEquip = not ns.db.profile.autoEquip
				ns:Print("auto-equip " .. (ns.db.profile.autoEquip and Theme:Color("accent", "ON") or "off")
					.. (ns.db.profile.autoEquip and " (out of combat; BoEs will bind)" or ""))
			elseif msg == "gear" then ns:Print("scanning bags for upgrades…"); Gear:ScanBags() end
		end)
	end,
})
