--[[ Core/StateModel.lua  ──────────────────────────────────────────────────────
     The single source of truth. Owns the player's current spec, level, zone,
     position, quest log, bags and equipped gear. Listens to Blizzard events,
     updates its fields, and publishes *semantic* events on the EventBus so every
     subsystem reacts instead of polling.

     Read it via ns.State.* and ns.State:Get*(); never read the raw API in modules.
]]
local ADDON, ns = ...
local C = ns.compat
local Bus = ns.Bus

local State = {
	classFile = nil, race = nil, faction = nil,
	level = 0, xp = 0, xpMax = 0,
	mapID = nil, x = nil, y = nil,
}
ns.State = State

-- ── accessors ─────────────────────────────────────────────────────────────────
function State:Level()   return self.level end
function State:Class()   return self.classFile end
function State:Race()    return self.race end
function State:Faction() return self.faction end
function State:MapID()   return self.mapID end

-- Player position on the current map as 0–100, plus the uiMapID (or nils).
function State:Position()
	local mapID = C.GetBestMapForUnit and C.GetBestMapForUnit("player")
	if not mapID then return nil, nil, nil end
	local pos = C.GetPlayerMapPosition and C.GetPlayerMapPosition(mapID, "player")
	if not pos then return nil, nil, mapID end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then return nil, nil, mapID end
	return x * 100, y * 100, mapID
end

-- ── update + publish ────────────────────────────────────────────────────────────
local function refreshStatic()
	local _, classFile = UnitClass("player")
	local _, race = UnitRace("player")
	State.classFile = classFile
	State.race = race
	State.faction = UnitFactionGroup("player")
end

local function onLevel()
	local lvl = UnitLevel("player")
	if lvl ~= State.level then State.level = lvl; Bus:Fire("LEVEL_CHANGED", lvl) end
end

local function onXP()
	State.xp, State.xpMax = UnitXP("player"), UnitXPMax("player")
	Bus:Fire("XP_CHANGED")
end

local function onZone()
	local mapID = C.GetBestMapForUnit and C.GetBestMapForUnit("player")
	if mapID ~= State.mapID then State.mapID = mapID; Bus:Fire("ZONE_CHANGED", mapID) end
end

local frame = CreateFrame("Frame", "ZenithStateFrame")
local handlers = {
	PLAYER_LEVEL_UP        = onLevel,
	PLAYER_XP_UPDATE       = onXP,
	ZONE_CHANGED_NEW_AREA  = onZone,
	ZONE_CHANGED           = onZone,
	QUEST_LOG_UPDATE       = function() Bus:Fire("QUESTLOG_CHANGED") end,
	QUEST_TURNED_IN        = function() Bus:Fire("QUESTLOG_CHANGED") end,
	BAG_UPDATE_DELAYED     = function() Bus:Fire("BAGS_CHANGED") end,
	PLAYER_EQUIPMENT_CHANGED = function() Bus:Fire("EQUIPMENT_CHANGED") end,
	ACTIVE_TALENT_GROUP_CHANGED = function() Bus:Fire("SPEC_CHANGED") end,
}
for ev in pairs(handlers) do pcall(frame.RegisterEvent, frame, ev) end

frame:SetScript("OnEvent", function(_, event, ...)
	local h = handlers[event]
	if h then local ok, err = pcall(h, ...); if not ok then ns:Debug("State " .. event .. ": " .. tostring(err)) end end
end)

-- Called once by Init after the world is loaded.
function State:Prime()
	refreshStatic()
	self.level = UnitLevel("player")
	self.xp, self.xpMax = UnitXP("player"), UnitXPMax("player")
	self.mapID = C.GetBestMapForUnit and C.GetBestMapForUnit("player")
	Bus:Fire("STATE_READY")
end
