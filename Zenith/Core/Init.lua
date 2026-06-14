--[[ Zenith — Guided ascent to 70, optimized every step.
     Core/Init.lua : addon namespace, lifecycle, module registry, saved variables.

     A TBC Classic (2.5.x) leveling + min-max companion addon.
     Flagship class implemented: Beast Mastery Hunter.

     File-shared namespace is passed as the 2nd vararg to every Lua file in the
     .toc, so all modules talk through `ns` without polluting _G.
]]

local ADDON_NAME, ns = ...

ns.ADDON  = ADDON_NAME
ns.NAME   = "Zenith"
ns.VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0"

-- Public color palette (fel-green TBC flavour) used across the UI.
ns.COLORS = {
	accent   = { 0.45, 0.86, 0.27 },          -- fel green
	accentHex = "ff73db45",
	gold     = { 1.00, 0.82, 0.00 },
	dim      = { 0.62, 0.62, 0.62 },
	bg       = { 0.05, 0.06, 0.05, 0.92 },
	done     = { 0.40, 0.78, 0.40 },
	active   = { 1.00, 0.96, 0.70 },
}

-- ---------------------------------------------------------------------------
-- Tiny module system. Each engine/UI file does:
--   local M = ns:NewModule("StepEngine")
--   function M:OnEnable() ... end          -- called once player is in world
-- ---------------------------------------------------------------------------
ns.modules = {}
local moduleOrder = {}

function ns:NewModule(name)
	assert(not self.modules[name], "Zenith: duplicate module " .. tostring(name))
	local m = { name = name }
	self.modules[name] = m
	moduleOrder[#moduleOrder + 1] = m
	return m
end

function ns:GetModule(name) return self.modules[name] end

-- ---------------------------------------------------------------------------
-- Data registries — Data/* files populate these tables at load time.
-- ---------------------------------------------------------------------------
ns.data = {
	questRoute = {},  -- [faction] = { quest steps... }    (generated from Questie DB)
	talents   = {},   -- [class] = { [specKey] = { order... } }
	gear      = {},   -- [class] = { milestones..., preraid... }
	rotations = {},   -- [class] = { [specKey] = { ... } }
	pets      = {},   -- [class] = { ... }
}

-- ---------------------------------------------------------------------------
-- Saved variables defaults (deep-copied on first login).
-- ---------------------------------------------------------------------------
ns.defaults = {
	account = {
		enabled       = true,
		locked        = false,
		scale         = 1.0,
		showArrow     = true,
		useTomTom     = true,
		showRotation  = true,
		showTalentPop = true,
		skipGrey      = true,    -- auto-skip out-leveled (grey) quests
		minimap       = { hide = false, angle = 215 },
		framePoint    = nil,   -- saved main-window position
		arrowPoint    = nil,
		rotationPoint = nil,
	},
	char = {
		stepIndex     = 1,      -- current step in the route
		completed     = {},     -- [stepId] = true (manual/auto completion)
		seenQuests    = {},     -- [questTitleLower] = true (for turn-in detection)
	},
}

-- ---------------------------------------------------------------------------
-- Event plumbing: a single hidden frame fans events out to listeners.
-- ---------------------------------------------------------------------------
local dispatcher = CreateFrame("Frame", "ZenithEventFrame")
local listeners = {}   -- [event] = { fn, fn, ... }

function ns:On(event, fn)
	if not listeners[event] then
		listeners[event] = {}
		dispatcher:RegisterEvent(event)
	end
	table.insert(listeners[event], fn)
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
	local fns = listeners[event]
	if not fns then return end
	for i = 1, #fns do
		local ok, err = pcall(fns[i], event, ...)
		if not ok then
			ns:Debug("error in handler for", event, "->", err)
		end
	end
end)

-- Internal message bus (addon-defined events, distinct from Blizzard events).
local messages = {}   -- [msg] = { fn, ... }
function ns:RegisterMessage(msg, fn)
	messages[msg] = messages[msg] or {}
	table.insert(messages[msg], fn)
end
function ns:SendMessage(msg, ...)
	local fns = messages[msg]
	if not fns then return end
	for i = 1, #fns do
		local ok, err = pcall(fns[i], msg, ...)
		if not ok then ns:Debug("msg handler error", msg, err) end
	end
end

function ns:Debug(...)
	if ns.account and ns.account.debug then
		print("|cff73db45Zenith|r [dbg]:", ...)
	end
end

function ns:Print(...)
	print("|cff73db45Zenith|r:", ...)
end

-- deep copy helper for defaults
local function copyInto(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyInto(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end
ns.CopyDefaults = copyInto

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
local enabled = false
local function enableModules()
	if enabled then return end
	enabled = true
	for _, m in ipairs(moduleOrder) do
		if m.OnEnable then
			local ok, err = pcall(m.OnEnable, m)
			if not ok then ns:Print("module", m.name, "failed:", err) end
		end
	end
end

ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON_NAME then return end

	ZenithDB     = ZenithDB or {}
	ZenithCharDB = ZenithCharDB or {}
	ns.account = copyInto(ZenithDB, ns.defaults.account)
	ns.char    = copyInto(ZenithCharDB, ns.defaults.char)

	for _, m in ipairs(moduleOrder) do
		if m.OnLoad then pcall(m.OnLoad, m) end
	end
end)

ns:On("PLAYER_LOGIN", enableModules)
ns:On("PLAYER_ENTERING_WORLD", function()
	if not enabled then enableModules() end
end)
