--[[ Modules/QuestData/QuestData.lua

     Owns the quest database. Receives zone packs as *serialized strings* and only
     parses a zone (loadstring) the first time it's needed, caching the result — so
     the full DB never sits parsed in memory at login (the Pillar 1 perf discipline).

     Public:
       ns.RegisterZonePack(flavor, { [uiMapID] = "<serialized>" })  -- called by data packs
       ns.QuestData:QuestsForMap(uiMapID)  -> { [questId] = record } or nil
       ns.QuestData:HasZone(uiMapID)       -> bool
       ns.QuestData:ZoneList()             -> sorted array of uiMapIDs we have data for

     A record: { name, lvl, req, races, gm,gx,gy, tm,tx,ty, item, target, obj={{m,x,y},..} }
]]
local ADDON, ns = ...

local QuestData = {}
ns.QuestData = QuestData

local rawZones = {}    -- [flavor] = { [uiMapID] = serialized string }
local parsed = {}      -- [uiMapID] = table (or false if parse failed)

-- Called by a generated data pack at load. Cheap: just stores strings.
function ns.RegisterZonePack(flavor, zones)
	rawZones[flavor] = rawZones[flavor] or {}
	local n = 0
	for ui, s in pairs(zones) do rawZones[flavor][ui] = s; n = n + 1 end
	ns.dataPacks[flavor] = true
	if ns.Debug then ns:Debug(string.format("zone pack '%s' registered (%d zones)", flavor, n)) end
end

local function zonesForFlavor()
	return rawZones[ns.flavor.id]
end

function QuestData:HasZone(ui)
	local z = zonesForFlavor()
	return z and z[ui] ~= nil
end

-- Lazy-parse + cache a single zone.
function QuestData:QuestsForMap(ui)
	if parsed[ui] ~= nil then return parsed[ui] or nil end
	local z = zonesForFlavor()
	local s = z and z[ui]
	if not s then return nil end
	local fn = loadstring(s)
	local ok, t = pcall(fn)
	parsed[ui] = (ok and type(t) == "table" and t) or false
	if not parsed[ui] and ns.Debug then ns:Debug("failed to parse zone " .. tostring(ui)) end
	return parsed[ui] or nil
end

function QuestData:ZoneList()
	local z, out = zonesForFlavor(), {}
	if z then for ui in pairs(z) do out[#out + 1] = ui end end
	table.sort(out)
	return out
end

-- Drop a parsed zone from the cache (e.g. on memory pressure / far from zone).
function QuestData:Unload(ui) parsed[ui] = nil end

ns.Registry:Add({
	name = "QuestData",
	IsFeatureEnabled = function() return ns:HasDataPack() end,
	OnEnable = function()
		ns:Debug("QuestData online — " .. #QuestData:ZoneList() .. " zones available")
	end,
})
