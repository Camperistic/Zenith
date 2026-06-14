--[[ UI/Options.lua — a panel in ESC → Interface → AddOns for the main toggles. ]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("Options")

local function checkbox(parent, label, tooltip, get, set)
	local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	cb.Text:SetText(label)
	cb.tooltipText = tooltip
	cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	return cb
end

function M:OnEnable()
	local panel = CreateFrame("Frame", "ZenithOptionsPanel", UIParent)
	panel.name = "Zenith"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(U.Accent("Zenith") .. "  " .. U.Dim("v" .. ns.VERSION))

	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetText("Guided ascent to 70 — leveling + min-max coaching.  /zenith")

	local boxes = {
		{ "Show the waypoint arrow", "Directional arrow to the current step.",
			function() return ns.account.showArrow end,
			function(v) ns.account.showArrow = v; ns:GetModule("Waypoint"):Refresh() end },
		{ "Show the rotation helper", "On-screen next-ability suggestion in combat.",
			function() return ns.account.showRotation end,
			function(v) ns.account.showRotation = v end },
		{ "Talent point pop-ups", "Remind me where to spend points on level-up.",
			function() return ns.account.showTalentPop end,
			function(v) ns.account.showTalentPop = v end },
		{ "Lock frames", "Prevent dragging the window, arrow, and helper.",
			function() return ns.account.locked end,
			function(v) ns.account.locked = v end },
		{ "Hide minimap button", "Remove the Zenith button from the minimap.",
			function() return ns.account.minimap.hide end,
			function(v) ns.account.minimap.hide = v
				ns:Print("Reload UI (/reload) to apply the minimap change.") end },
	}
	local anchor = sub
	for i, b in ipairs(boxes) do
		local cb = checkbox(panel, b[1], b[2], b[3], b[4])
		cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", i == 1 and 0 or 0, i == 1 and -14 or -6)
		anchor = cb
	end

	-- Register with the Interface Options (Classic API, with Dragonflight fallback).
	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	elseif Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(cat)
		M._cat = cat
	end
	M.panel = panel
end

function M:Open()
	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(M.panel)
		InterfaceOptionsFrame_OpenToCategory(M.panel)  -- twice: known Blizzard quirk
	elseif Settings and Settings.OpenToCategory and M._cat then
		Settings.OpenToCategory(M._cat:GetID())
	end
end
