--[[ UI/ActionBar.lua

     A small movable bar with two SECURE buttons tied to the current step:
       • Target — /target the quest's objective mob
       • Use    — /use the quest-provided item (shown only when you have it)

     Secure attributes can't be changed in combat, so updates are deferred to
     PLAYER_REGEN_ENABLED. Built once at login (out of combat).
]]
local ADDON_NAME, ns = ...
local U = ns.U
local AC = ns.COLORS.accent
local M = ns:NewModule("ActionBar")

local frame, targetBtn, itemBtn
local current      -- the step the bar currently reflects
local pending      -- set when an update was blocked by combat

local function itemCount(id)
	local f = (C_Item and C_Item.GetItemCount) or GetItemCount
	return (f and f(id)) or 0
end
local function itemInfo(id)
	local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if not f then return nil end
	local name, _, _, _, _, _, _, _, _, tex = f(id)
	return name, tex
end

local function secureButton(parent, w)
	local b = CreateFrame("Button", "ZenithActionBtn" .. (parent.__n or 0), parent, "SecureActionButtonTemplate")
	parent.__n = (parent.__n or 0) + 1
	b:SetSize(w, 26)
	b:RegisterForClicks("AnyUp", "AnyDown")
	local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.11, 0.13, 0.11, 0.95)
	ns.W.Border(b, AC[1], AC[2], AC[3], 0.5, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 4, 0); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.label:SetPoint("LEFT", b.icon, "RIGHT", 5, 0); b.label:SetPoint("RIGHT", -4, 0); b.label:SetJustifyH("LEFT")
	b.label:SetTextColor(AC[1], AC[2], AC[3])
	b:SetScript("OnEnter", function() bg:SetColorTexture(AC[1]*0.28, AC[2]*0.28, AC[3]*0.28, 0.95) end)
	b:SetScript("OnLeave", function() bg:SetColorTexture(0.11, 0.13, 0.11, 0.95) end)
	return b
end

local function apply(step)
	current = step
	if InCombatLockdown() then pending = true; return end
	pending = false
	local shown = false

	if step and step.target then
		targetBtn:SetAttribute("type", "macro")
		targetBtn:SetAttribute("macrotext", "/cleartarget\n/target " .. step.target)
		targetBtn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
		targetBtn.label:SetText("Target: " .. step.target)
		targetBtn:Show(); shown = true
	else
		targetBtn:Hide()
	end

	if step and step.item and itemCount(step.item) > 0 then
		local name, tex = itemInfo(step.item)
		itemBtn:SetAttribute("type", "macro")
		itemBtn:SetAttribute("macrotext", "/use item:" .. step.item)
		itemBtn.icon:SetTexture(tex or 134400)
		itemBtn.label:SetText("Use: " .. (name or "quest item"))
		itemBtn:Show(); shown = true
	else
		itemBtn:Hide()
	end

	-- stack the visible buttons
	itemBtn:ClearAllPoints()
	if targetBtn:IsShown() then itemBtn:SetPoint("TOPLEFT", targetBtn, "BOTTOMLEFT", 0, -3)
	else itemBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0) end
	frame:SetShown(shown and ns.account.showActionBar ~= false)
end

function M:OnEnable()
	frame = CreateFrame("Frame", "ZenithActionBar", UIParent)
	frame:SetSize(210, 56)
	frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) if not ns.account.locked then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.account.actionBarPoint = { p, rp, x, y }
	end)
	local pt = ns.account.actionBarPoint
	if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
	else frame:SetPoint("CENTER", UIParent, "CENTER", 280, -120) end

	targetBtn = secureButton(frame, 210); targetBtn:SetPoint("TOPLEFT")
	itemBtn   = secureButton(frame, 210); itemBtn:SetPoint("TOPLEFT", targetBtn, "BOTTOMLEFT", 0, -3)
	frame:Hide()

	ns:RegisterMessage("ZENITH_STEP_CHANGED", function(_, _, step) apply(step) end)
	ns:On("PLAYER_REGEN_ENABLED", function() if pending then apply(current) end end)
	ns:On("BAG_UPDATE", function() if not InCombatLockdown() then apply(current) end end)

	local se = ns:GetModule("StepEngine")
	if se then apply(se:CurrentStep()) end
end
