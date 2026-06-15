--[[ UI/MiniButton.lua : a self-contained minimap button (no LibDBIcon dependency). ]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("MiniButton")

local function updatePosition(btn)
	local angle = math.rad(ns.account.minimap.angle or 215)
	local r = 80
	btn:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
end

function M:OnEnable()
	if ns.account.minimap.hide then return end
	local btn = CreateFrame("Button", "ZenithMiniButton", Minimap)
	btn:SetSize(31, 31); btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)

	local overlay = btn:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53); overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local icon = btn:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")  -- neutral map icon
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetScript("OnClick", function(_, mouseBtn)
		if mouseBtn == "RightButton" then
			ns.account.showArrow = not ns.account.showArrow
			ns:GetModule("Waypoint"):Refresh()
			ns:Print("Arrow " .. (ns.account.showArrow and "on" or "off"))
		else
			ns.UI:Toggle()
		end
	end)

	-- drag around the minimap ring
	btn:RegisterForDrag("LeftButton")
	btn:SetMovable(true)
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			ns.account.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
			updatePosition(self)
		end)
	end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(U.Accent("Zenith"))
		GameTooltip:AddLine("Left-click: open guide", 1, 1, 1)
		GameTooltip:AddLine("Right-click: toggle arrow", 1, 1, 1)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	updatePosition(btn)
end
