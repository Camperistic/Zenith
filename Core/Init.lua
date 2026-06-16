--[[ Core/Init.lua  ──────────────────────────────────────────────────────────────
     Ties the core together: builds the AceAddon, wires the StateModel and module
     registry, and friendly-fails (never a Lua error) if the running client has no
     data pack. Loaded after the libraries and the rest of Core.
]]
local ADDON, ns = ...
local C = ns.compat

local Zenith = LibStub("AceAddon-3.0"):NewAddon("Zenith", "AceConsole-3.0", "AceEvent-3.0")
ns.addon = Zenith
ns.NAME = "Zenith"
ns.VERSION = (C.GetAddOnMetadata and C.GetAddOnMetadata(ADDON, "Version")) or "2.0.0-dev"

-- ── logging helpers ─────────────────────────────────────────────────────────────
local TAG = "|cff73db45Zenith|r: "
function ns:Print(...) print(TAG .. strjoin(" ", tostringall(...))) end
function ns:Debug(...)
	if ns.db and ns.db.profile and ns.db.profile.debug then
		print("|cff73db45Zenith|r |cffaaaaaa[dbg]|r " .. strjoin(" ", tostringall(...)))
	end
end

-- ── lifecycle ───────────────────────────────────────────────────────────────────
function Zenith:OnInitialize()
	ns:SetupDB()
	self:RegisterChatCommand("zenith", function(msg) ns:Slash(msg) end)
	self:RegisterChatCommand("zen", function(msg) ns:Slash(msg) end)
end

function Zenith:OnEnable()
	ns.State:Prime()

	if not ns:HasDataPack() then
		ns:Print(string.format(
			"loaded on |cffffd100%s|r (%s, build %s), but no data pack ships for this client yet. "
			.. "Core is active; route/quest features need the matching data pack.",
			ns.flavor.id, ns.flavor.version, tostring(ns.flavor.build)))
	end

	-- Enable feature modules (each decides via IsFeatureEnabled / profile toggles).
	ns.Registry:EnableAll()
	ns.Bus:Fire("ADDON_ENABLED")
end

-- ── slash ────────────────────────────────────────────────────────────────────────
function ns:Slash(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "status" or msg == "" then
		ns:Print(string.format("v%s · client: %s %s (build %s, iface %s) · data pack: %s",
			ns.VERSION, ns.flavor.id, ns.flavor.version, tostring(ns.flavor.build),
			tostring(ns.flavor.interface), ns:HasDataPack() and "|cff40c040yes|r" or "|cffd04040none|r"))
		ns:Print("modules: " .. (function()
			local t = {}
			for _, m in ipairs(ns.Registry:All()) do t[#t + 1] = m.name .. (m._enabled and "+" or "-") end
			return #t > 0 and table.concat(t, ", ") or "none"
		end)())
		ns:Print("settings: |cffffd100/zen config|r (or right-click the minimap button)")
	elseif msg == "debug" then
		ns.db.profile.debug = not ns.db.profile.debug
		ns:Print("debug " .. (ns.db.profile.debug and "on" or "off"))
	else
		ns.Bus:Fire("SLASH", msg)
	end
end
