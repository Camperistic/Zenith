--[[ Modules/UI/Options.lua

     The real settings home: an AceConfig options table registered into the game's
     own Settings window, under AddOns → Zenith (plus a Profiles sub-page). This is
     where configuration lives now — slash verbs still work as shortcuts, but nobody
     has to memorise them.

     Every control reads/writes ns.db.profile and applies live where it cheaply can
     (scale, minimap button, map pins, arrow, gear auto-equip). The theme change is
     the one thing that needs a UI rebuild, so it offers a Reload button right there.
]]
local ADDON, ns = ...
local AceConfig       = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBOptions    = LibStub("AceDBOptions-3.0", true)

-- ── live application of a changed setting ───────────────────────────────────────
local function onChange(key)
	local p = ns.db.profile
	if key == "scale" or key == "locked" then
		if ns.UI and ns.UI.ApplySettings then ns.UI:ApplySettings() end
	elseif key == "minimap" then
		local DBIcon = LibStub("LibDBIcon-1.0", true)
		if DBIcon and DBIcon:IsRegistered("Zenith") then
			if p.minimap.hide then DBIcon:Hide("Zenith") else DBIcon:Show("Zenith") end
		end
	elseif key == "pinMode" then
		if ns.Pins then ns.Pins:Redraw() end
	elseif key == "showArrow" then
		if ns.Arrow then ns.Arrow:Retarget() end
	end
	ns.Bus:Fire("SETTINGS_CHANGED", key)
end

-- small get/set factories bound to a profile key
local function get(key) return function() return ns.db.profile[key] end end
local function set(key) return function(_, v) ns.db.profile[key] = v; onChange(key) end end

-- ── options table ───────────────────────────────────────────────────────────────
local function themeValues()
	local v = {}
	if ns.Theme then for _, t in ipairs(ns.Theme:List()) do v[t[1]] = t[2] end end
	return v
end

local function buildOptions()
	return {
		type = "group",
		name = "Zenith",
		args = {
			header = {
				type = "description", order = 0, fontSize = "medium",
				name = "The one addon a leveler runs from 1 to cap — route, quest map, "
					.. "class coaching, gear advisor and leveling stats in one.\n",
			},
			ver = {
				type = "description", order = 1, fontSize = "small",
				name = "|cff808080Version " .. (ns.VERSION or "?") .. "|r\n",
			},

			-- ── General ────────────────────────────────────────────────────────────
			general = {
				type = "group", inline = true, order = 10, name = "General",
				args = {
					theme = {
						type = "select", order = 1, name = "Theme",
						desc = "Colour scheme for Zenith's window and arrow. Takes full effect after a UI reload.",
						values = themeValues, get = get("theme"), set = set("theme"),
					},
					reload = {
						type = "execute", order = 2, name = "Reload UI", width = "half",
						desc = "Reload the interface to fully apply a theme change.",
						func = function() ReloadUI() end,
					},
					scale = {
						type = "range", order = 3, name = "Window scale",
						min = 0.7, max = 1.5, step = 0.05, isPercent = true,
						get = get("scale"), set = set("scale"),
					},
					locked = {
						type = "toggle", order = 4, name = "Lock window",
						desc = "Prevent dragging the main window.",
						get = get("locked"), set = set("locked"),
					},
					minimap = {
						type = "toggle", order = 5, name = "Minimap button",
						desc = "Show the Zenith button on the minimap.",
						get = function() return not ns.db.profile.minimap.hide end,
						set = function(_, v) ns.db.profile.minimap.hide = not v; onChange("minimap") end,
					},
				},
			},

			-- ── Quest map ──────────────────────────────────────────────────────────
			map = {
				type = "group", inline = true, order = 20, name = "Quest Map",
				args = {
					pinMode = {
						type = "select", order = 1, name = "Map pins", width = "double",
						desc = "Full world shows every nearby quest; Route only shows pins for "
							.. "your current route window; Off hides them.",
						values = { full = "Full quest world", route = "Route only", off = "Off" },
						get = get("pinMode"), set = set("pinMode"),
					},
				},
			},

			-- ── Route & arrow ──────────────────────────────────────────────────────
			route = {
				type = "group", inline = true, order = 30, name = "Route & Arrow",
				args = {
					showArrow = {
						type = "toggle", order = 1, name = "Waypoint arrow",
						desc = "Show the on-screen directional arrow to the next route step.",
						get = function() return ns.db.profile.showArrow ~= false end,
						set = function(_, v) ns.db.profile.showArrow = v; onChange("showArrow") end,
					},
				},
			},

			-- ── Gear advisor ───────────────────────────────────────────────────────
			gear = {
				type = "group", inline = true, order = 40, name = "Gear Advisor",
				args = {
					blurb = {
						type = "description", order = 0,
						name = "Scores each item you pick up from its real stats (weighted for your "
							.. "class/spec), skips anything you can't use, and flags upgrades in chat.",
					},
					autoEquip = {
						type = "toggle", order = 1, width = "full",
						name = "Auto-equip upgrades",
						desc = "Automatically equip an item that scores higher than what you're wearing. "
							.. "Out of combat only, and note this will BIND bind-on-equip items.",
						confirm = function() return not ns.db.profile.autoEquip end,
						confirmText = "Auto-equip will BIND bind-on-equip upgrades to you. Enable it?",
						get = get("autoEquip"), set = set("autoEquip"),
					},
				},
			},

			-- ── Advanced ───────────────────────────────────────────────────────────
			advanced = {
				type = "group", inline = true, order = 90, name = "Advanced",
				args = {
					debug = {
						type = "toggle", order = 1, name = "Debug messages",
						get = get("debug"), set = set("debug"),
					},
				},
			},
		},
	}
end

-- ── open helper (used by /zen config and the launcher) ──────────────────────────
function ns:OpenSettings()
	if Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(ns._optionsCategory or "Zenith")
	elseif InterfaceOptionsFrame_OpenToCategory and ns._optionsFrame then
		-- legacy path: call twice (a known Blizzard quirk) so it lands on the panel
		InterfaceOptionsFrame_OpenToCategory(ns._optionsFrame)
		InterfaceOptionsFrame_OpenToCategory(ns._optionsFrame)
	else
		ns:Print("Open the game menu → Options → AddOns → Zenith.")
	end
end

ns.Registry:Add({
	name = "Options",
	IsFeatureEnabled = function() return AceConfig ~= nil and AceConfigDialog ~= nil end,
	OnEnable = function()
		AceConfig:RegisterOptionsTable("Zenith", buildOptions)
		local frame, name = AceConfigDialog:AddToBlizOptions("Zenith", "Zenith")
		ns._optionsFrame = frame
		ns._optionsCategory = name or "Zenith"

		-- Profiles sub-page (account/character profile management).
		if AceDBOptions then
			AceConfig:RegisterOptionsTable("Zenith-Profiles", AceDBOptions:GetOptionsTable(ns.db))
			AceConfigDialog:AddToBlizOptions("Zenith-Profiles", "Profiles", "Zenith")
		end

		ns.Bus:On("SLASH", function(msg)
			if msg == "config" or msg == "options" or msg == "settings" then ns:OpenSettings() end
		end)
	end,
})
