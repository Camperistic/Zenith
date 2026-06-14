--[[ UI/MainFrame.lua

     The main Zenith window: a movable, tabbed panel.
       • Guide   — the live leveling route (current step + what's next)
       • Talents — next recommended talent point + the full leveling path
       • Gear    — current gear milestone, pre-raid BiS, pet tips
       • Help    — rotation/aspects, commands, data sources

     Built entirely in Lua with plain textures (no Backdrop/XML dependency) so it
     loads cleanly across TBC Classic builds.
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("MainFrame")
ns.UI = M

local AC = ns.COLORS.accent
local frame, panes, tabs
local activeTab = "Guide"

-- ── small widget helpers ──────────────────────────────────────────────────────
local function panel(parent, r, g, b, a)
	local t = parent:CreateTexture(nil, "BACKGROUND")
	t:SetColorTexture(r, g, b, a)
	return t
end

local function fs(parent, template, x, y, anchor)
	local t = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
	t:SetPoint(anchor or "TOPLEFT", x or 0, y or 0)
	return t
end

local function button(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, h); b:SetText(text)
	return b
end

-- ── header / chrome ───────────────────────────────────────────────────────────
local function buildChrome()
	local f = CreateFrame("Frame", "ZenithFrame", UIParent)
	f:SetSize(360, 460)
	f:SetClampedToScreen(true)
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetFrameStrata("MEDIUM")
	f:SetScript("OnDragStart", function(self) if not ns.account.locked then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.account.framePoint = { p, rp, x, y }
	end)

	-- backplate + accent edges
	panel(f, 0.04, 0.05, 0.04, 0.94):SetAllPoints()
	local top = panel(f, AC[1], AC[2], AC[3], 0.9); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(2)
	local hdr = panel(f, AC[1] * 0.25, AC[2] * 0.25, AC[3] * 0.25, 0.6)
	hdr:SetPoint("TOPLEFT", 0, -2); hdr:SetPoint("TOPRIGHT", 0, -2); hdr:SetHeight(28)

	local title = fs(f, "GameFontNormalLarge", 12, -7)
	title:SetText(U.Accent("Zenith") .. U.Dim("  v" .. ns.VERSION))

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() M:Hide() end)

	local lock = button(f, "Lock", 46, 18)
	lock:SetPoint("TOPRIGHT", -26, -5)
	lock:SetScript("OnClick", function()
		ns.account.locked = not ns.account.locked
		lock:SetText(ns.account.locked and "Unlock" or "Lock")
		ns:Print(ns.account.locked and "Frames locked." or "Frames unlocked — drag to move.")
	end)
	lock:SetText(ns.account.locked and "Unlock" or "Lock")

	f.title = title
	return f
end

-- ── tabs ──────────────────────────────────────────────────────────────────────
local TAB_ORDER = { "Guide", "Talents", "Gear", "Help" }

local function buildTabs(f)
	tabs = {}
	local x = 8
	for _, name in ipairs(TAB_ORDER) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(82, 22)
		b:SetPoint("TOPLEFT", x, -32)
		local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetAllPoints(); label:SetText(name)
		b.label = label
		local underline = panel(b, AC[1], AC[2], AC[3], 1)
		underline:SetPoint("BOTTOMLEFT", 4, 0); underline:SetPoint("BOTTOMRIGHT", -4, 0); underline:SetHeight(2)
		b.underline = underline
		b:SetScript("OnClick", function() M:SelectTab(name) end)
		tabs[name] = b
		x = x + 86
	end
end

function M:SelectTab(name)
	activeTab = name
	for n, b in pairs(tabs) do
		local on = (n == name)
		b.underline:SetShown(on)
		b.label:SetTextColor(on and AC[1] or 0.7, on and AC[2] or 0.7, on and AC[3] or 0.7)
	end
	for n, p in pairs(panes) do p:SetShown(n == name) end
	if panes[name] and panes[name].Refresh then panes[name]:Refresh() end
end

-- ── content area factory ──────────────────────────────────────────────────────
local function makePane(f)
	local p = CreateFrame("Frame", nil, f)
	p:SetPoint("TOPLEFT", 8, -58)
	p:SetPoint("BOTTOMRIGHT", -8, 8)
	return p
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────
function M:Toggle() if frame and frame:IsShown() then M:Hide() else M:Show() end end
function M:Show() if frame then frame:Show(); M:SelectTab(activeTab) end end
function M:Hide() if frame then frame:Hide() end end
function M:IsShown() return frame and frame:IsShown() end

function M:RefreshActive()
	if panes[activeTab] and panes[activeTab].Refresh then panes[activeTab]:Refresh() end
end

function M:OnEnable()
	frame = buildChrome()
	buildTabs(frame)
	panes = {}
	-- Pane builders live in their own files and register here.
	for _, name in ipairs(TAB_ORDER) do
		panes[name] = makePane(frame)
		if ns.PaneBuilders and ns.PaneBuilders[name] then
			ns.PaneBuilders[name](panes[name])
		end
	end

	local pt = ns.account.framePoint
	if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
	else frame:SetPoint("CENTER", UIParent, "CENTER", 280, 0) end

	M:SelectTab("Guide")
	frame:SetShown(ns.account.enabled ~= false)

	-- Live refresh on state changes.
	ns:RegisterMessage("ZENITH_STEP_CHANGED",  function() M:RefreshActive() end)
	ns:RegisterMessage("ZENITH_STEP_COMPLETED",function() M:RefreshActive() end)
	ns:RegisterMessage("ZENITH_ROUTE_LOADED",  function() M:RefreshActive() end)
	ns:RegisterMessage("ZENITH_TALENT_AVAILABLE", function() M:RefreshActive() end)
	ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.3, function() M:RefreshActive() end) end)

	-- Slash commands.
	SLASH_ZENITH1, SLASH_ZENITH2 = "/zenith", "/zen"
	SlashCmdList.ZENITH = function(msg)
		msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if msg == "lock" then ns.account.locked = true; ns:Print("Frames locked.")
		elseif msg == "unlock" then ns.account.locked = false; ns:Print("Frames unlocked.")
		elseif msg == "arrow" then ns.account.showArrow = not ns.account.showArrow
			ns:GetModule("Waypoint"):Refresh(); ns:Print("Arrow " .. (ns.account.showArrow and "on" or "off"))
		elseif msg == "rotation" or msg == "dps" then ns.account.showRotation = not ns.account.showRotation
			ns:Print("Rotation helper " .. (ns.account.showRotation and "on" or "off"))
		elseif msg == "reset" then ns.char.stepIndex = 1; wipe(ns.char.completed)
			ns:GetModule("StepEngine"):LoadRoute(); ns:Print("Route progress reset.")
		elseif msg == "next" then ns:GetModule("StepEngine"):Next()
		elseif msg == "prev" then ns:GetModule("StepEngine"):Prev()
		else M:Toggle() end
	end
end
