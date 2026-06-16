--[[ Modules/UI/Launcher.lua — one LibDataBroker launcher + minimap button. ]]
local ADDON, ns = ...
local LDB = LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub("LibDBIcon-1.0", true)

ns.Registry:Add({
	name = "Launcher",
	IsFeatureEnabled = function() return LDB ~= nil end,
	OnEnable = function()
		local obj = LDB:NewDataObject("Zenith", {
			type = "launcher",
			icon = "Interface\\Icons\\INV_Misc_Map_01",
			label = "Zenith",
			OnClick = function(_, button)
				if button == "RightButton" then ns.Bus:Fire("SLASH", "arrow") else ns.UI:Toggle() end
			end,
			OnTooltipShow = function(tt)
				tt:AddLine("|cff73db45Zenith|r")
				tt:AddLine("Left-click: window", 1, 1, 1)
				tt:AddLine("Right-click: toggle arrow", 1, 1, 1)
			end,
		})
		if DBIcon and not DBIcon:IsRegistered("Zenith") then
			DBIcon:Register("Zenith", obj, ns.db.profile.minimap)
		end
	end,
})
