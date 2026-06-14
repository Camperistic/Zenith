--[[ tools/import_questie.lua

   Generates Zenith's comprehensive quest-route data from the open Questie TBC
   database (quest/NPC/object DBs + the areaId→uiMapId map). Extracts only factual
   game data (quest name, level, race availability, and the giver's coordinates)
   and re-emits it in Zenith's own step format. Questie data is community-sourced
   game data; Zenith credits Questie (see README).

   Usage:
     lua5.1 tools/import_questie.lua <questie_dir> <out_dir>

   Produces <out_dir>/Gen_Alliance.lua and <out_dir>/Gen_Horde.lua, each setting
   ns.data.questRoute[faction] = { ordered quest steps with per-step race masks }.
]]

local questieDir = arg[1] or "/tmp/questie"
local outDir     = arg[2] or "Zenith/Data/Routes/Generated"

local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end

-- Pull a `<name> = [[return {...}]]` block out of a file and evaluate it.
local function extractTable(text, marker)
	local i = assert(text:find(marker, 1, true), "marker not found: " .. marker)
	local b = assert(text:find("%[%[", i))
	local e = assert(text:find("%]%]", b))
	local inner = text:sub(b + 2, e - 1)            -- "return {...}"
	return assert(loadstring(inner))()
end

-- ── Load databases ────────────────────────────────────────────────────────────
local qText  = slurp(questieDir .. "/Database/TBC/tbcQuestDB.lua")
local nText  = slurp(questieDir .. "/Database/TBC/tbcNpcDB.lua")
local oText  = slurp(questieDir .. "/Database/TBC/tbcObjectDB.lua")
local aText  = slurp(questieDir .. "/Database/Zones/data/areaIdToUiMapId.lua")

local quests  = extractTable(qText, "QuestieDB.questData")
local npcs    = extractTable(nText, "QuestieDB.npcData")
local objects = extractTable(oText, "QuestieDB.objectData")

-- areaID → { ui = uiMapID, name = "Zone Name" }  (parsed from the commented table)
local areaInfo, name2area = {}, {}
for line in aText:gmatch("[^\n]+") do
	local aid, uid, name = line:match("%[(%d+)%]%s*=%s*(%d+),%s*%-%-%s*(.+)")
	if aid then
		aid, uid = tonumber(aid), tonumber(uid)
		name = name:gsub("%s+$", "")
		areaInfo[aid] = { ui = uid, name = name }
		if not name2area[name] then name2area[name] = aid end
	end
end

-- Quest field indices (Questie questKeys) and NPC/object spawn indices.
local Q = { name=1, startedBy=2, finishedBy=3, reqLevel=4, level=5, races=6, classes=7, objText=8, zone=17 }
local NPC_SPAWNS, OBJ_SPAWNS = 7, 4

-- Resolve a creature/object id to a coordinate, preferring a spawn in `zoneArea`.
local function firstSpawn(spawnTable, zoneArea)
	if type(spawnTable) ~= "table" then return nil end
	if zoneArea and spawnTable[zoneArea] and spawnTable[zoneArea][1] then
		return zoneArea, spawnTable[zoneArea][1][1], spawnTable[zoneArea][1][2]
	end
	for aid, coords in pairs(spawnTable) do
		if coords[1] then return aid, coords[1][1], coords[1][2] end
	end
end

local function resolveStart(startedBy, zoneArea)
	if type(startedBy) ~= "table" then return nil end
	local creatures, objs = startedBy[1], startedBy[2]
	if type(creatures) == "table" and creatures[1] and npcs[creatures[1]] then
		local a, x, y = firstSpawn(npcs[creatures[1]][NPC_SPAWNS], zoneArea)
		if x then return a, x, y end
	end
	if type(objs) == "table" and objs[1] and objects[objs[1]] then
		local a, x, y = firstSpawn(objects[objs[1]][OBJ_SPAWNS], zoneArea)
		if x then return a, x, y end
	end
end

-- ── Race / faction masks ──────────────────────────────────────────────────────
local ALLY = { 1, 2, 4, 8, 1024 }              -- Human, Dwarf, NightElf, Gnome, Draenei
local HORDE = { 16, 32, 64, 128, 512 }         -- Orc, Undead, Tauren, Troll, BloodElf
local function hasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end
local function availableTo(races, bits)
	if not races or races == 0 then return true end
	for _, b in ipairs(bits) do if hasBit(races, b) then return true end end
	return false
end

-- ── Faction zone order (by name) + level bands ────────────────────────────────
-- Anything not listed but present is appended, ordered by its lowest quest level.
local ALLIANCE_ORDER = {
	"Northshire Valley","Elwynn Forest","Coldridge Valley","Dun Morogh","Shadowglen","Teldrassil",
	"Ammen Vale","Azuremyst Isle","Bloodmyst Isle","Westfall","Loch Modan","Darkshore","Redridge Mountains",
	"Duskwood","Ashenvale","Hillsbrad Foothills","Wetlands","Stonetalon Mountains","Thousand Needles",
	"Stranglethorn Vale","Arathi Highlands","Desolace","Dustwallow Marsh","Tanaris","Feralas","The Hinterlands",
	"Searing Gorge","Badlands","Swamp of Sorrows","Un'Goro Crater","Felwood","Western Plaguelands","Winterspring",
	"Eastern Plaguelands","Silithus","Blasted Lands","Burning Steppes",
	"Hellfire Peninsula","Zangarmarsh","Terokkar Forest","Nagrand","Blade's Edge Mountains","Netherstorm","Shadowmoon Valley",
}
local HORDE_ORDER = {
	"Valley of Trials","Durotar","Camp Narache","Mulgore","Deathknell","Tirisfal Glades","Sunstrider Isle",
	"Eversong Woods","Ghostlands","The Barrens","Silverpine Forest","Stonetalon Mountains","Ashenvale",
	"Hillsbrad Foothills","Thousand Needles","Desolace","Stranglethorn Vale","Arathi Highlands","Dustwallow Marsh",
	"Tanaris","Feralas","The Hinterlands","Searing Gorge","Badlands","Swamp of Sorrows","Un'Goro Crater","Felwood",
	"Western Plaguelands","Winterspring","Eastern Plaguelands","Silithus","Blasted Lands","Burning Steppes",
	"Hellfire Peninsula","Zangarmarsh","Terokkar Forest","Nagrand","Blade's Edge Mountains","Netherstorm","Shadowmoon Valley",
}

-- Racial starting zones → owning race bitmask. Steps in these zones are tagged so
-- a character only sees its own start chain (other-race start zones are filtered
-- out at runtime). Mid/shared zones keep each quest's own race requirement.
local ZONE_OWNER = {
	-- Alliance
	["Northshire Valley"] = 1, ["Elwynn Forest"] = 1,
	["Coldridge Valley"] = 10, ["Dun Morogh"] = 10,                 -- Dwarf+Gnome
	["Shadowglen"] = 4, ["Teldrassil"] = 4, ["Darkshore"] = 4,      -- NightElf
	["Ammen Vale"] = 1024, ["Azuremyst Isle"] = 1024, ["Bloodmyst Isle"] = 1024,
	-- Horde
	["Valley of Trials"] = 144, ["Durotar"] = 144,                  -- Orc+Troll
	["Camp Narache"] = 64, ["Mulgore"] = 64,                        -- Tauren
	["Deathknell"] = 32, ["Tirisfal Glades"] = 32, ["Silverpine Forest"] = 32,
	["Sunstrider Isle"] = 512, ["Eversong Woods"] = 512, ["Ghostlands"] = 512,
}

-- Exclude cities / instances / battlegrounds from the field-leveling route.
local EXCLUDE = {}
for _, n in ipairs({
	"Stormwind City","Orgrimmar","Ironforge","Darnassus","Undercity","Thunder Bluff","Silvermoon City",
	"The Exodar","Shattrath City","Booty Bay","Ratchet","Gadgetzan","Everlook","Warsong Gulch","Arathi Basin",
	"Alterac Valley","Eye of the Storm","Deeprun Tram",
}) do EXCLUDE[n] = true end

-- ── Build per-faction routes ──────────────────────────────────────────────────
local function buildFaction(orderList, bits)
	-- group valid quests by zone areaID
	local byZone = {}
	for qid, q in pairs(quests) do
		local name, zoneArea, lvl = q[Q.name], q[Q.zone], q[Q.level] or 0
		local zoneName = type(zoneArea) == "number" and areaInfo[zoneArea] and areaInfo[zoneArea].name
		local isInstance = zoneName and (zoneName:find("%- Dungeon") or zoneName:find("%- Raid")
			or zoneName:find("%- Battleground"))
		local valid = name and #name > 0
			and not name:find("%(") and not name:lower():find("deprecated")   -- skip test/placeholder
			and zoneName and not isInstance
			and areaInfo[zoneArea].ui and areaInfo[zoneArea].ui > 0          -- skip "fail safe"
			and lvl > 0 and lvl <= 70
			and availableTo(q[Q.races], bits)
			and not EXCLUDE[zoneName]
		if valid then
			byZone[zoneArea] = byZone[zoneArea] or {}
			table.insert(byZone[zoneArea], { qid = qid, q = q })
		end
	end

	-- order index per zone name
	local orderIndex = {}
	for i, n in ipairs(orderList) do orderIndex[n] = i end

	-- assemble ordered zone list
	local zoneList = {}
	for zoneArea, list in pairs(byZone) do
		local nm = areaInfo[zoneArea].name
		local minLvl = 999
		for _, e in ipairs(list) do minLvl = math.min(minLvl, e.q[Q.level]) end
		zoneList[#zoneList + 1] = {
			area = zoneArea, name = nm, list = list, minLvl = minLvl,
			order = orderIndex[nm] or (100 + minLvl),
		}
	end
	table.sort(zoneList, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.minLvl < b.minLvl
	end)

	-- emit steps
	local steps = {}
	for _, z in ipairs(zoneList) do
		table.sort(z.list, function(a, b)
			local la, lb = a.q[Q.level], b.q[Q.level]
			if la ~= lb then return la < lb end
			return (a.q[Q.name] or "") < (b.q[Q.name] or "")
		end)
		local ui = areaInfo[z.area].ui
		local owner = ZONE_OWNER[z.name]
		steps[#steps + 1] = { kind = "travel", zone = z.name, mapID = ui, band = { z.minLvl, z.minLvl + 3 },
			text = "Travel to " .. z.name, races = owner }
		for _, e in ipairs(z.list) do
			local q = e.q
			local ca, x, y = resolveStart(q[Q.startedBy], z.area)
			local mapID = (ca and areaInfo[ca] and areaInfo[ca].ui) or ui
			local lvl = q[Q.level]
			local reqL = q[Q.reqLevel] and q[Q.reqLevel] > 0 and q[Q.reqLevel] or lvl
			local detail = type(q[Q.objText]) == "table" and q[Q.objText][1] or nil
			-- In a racial start zone, force the owner mask; elsewhere keep the quest's own.
			local races = owner or ((q[Q.races] and q[Q.races] ~= 0) and q[Q.races] or nil)
			steps[#steps + 1] = {
				kind = "quest", zone = z.name, mapID = mapID,
				x = x and math.floor(x * 10 + 0.5) / 10 or nil,
				y = y and math.floor(y * 10 + 0.5) / 10 or nil,
				band = { reqL, lvl }, quest = q[Q.name], text = q[Q.name], detail = detail,
				races = races,
			}
		end
	end
	return steps
end

-- ── Serialize ─────────────────────────────────────────────────────────────────
local function q(s) return "\"" .. tostring(s):gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"" end

local function writeFaction(faction, steps)
	local out = {}
	out[#out+1] = "-- AUTO-GENERATED from the Questie TBC database by tools/import_questie.lua"
	out[#out+1] = "-- Do not edit by hand. Quest data © the Questie project (community game data)."
	out[#out+1] = "local ADDON_NAME, ns = ..."
	out[#out+1] = "ns.data.questRoute = ns.data.questRoute or {}"
	out[#out+1] = "ns.data.questRoute." .. faction .. " = {"
	for _, s in ipairs(steps) do
		local parts = { "kind=" .. q(s.kind), "zone=" .. q(s.zone) }
		if s.mapID then parts[#parts+1] = "mapID=" .. s.mapID end
		if s.x then parts[#parts+1] = "x=" .. s.x end
		if s.y then parts[#parts+1] = "y=" .. s.y end
		if s.band then parts[#parts+1] = "band={" .. s.band[1] .. "," .. s.band[2] .. "}" end
		if s.quest then parts[#parts+1] = "quest=" .. q(s.quest) end
		if s.text then parts[#parts+1] = "text=" .. q(s.text) end
		if s.detail then parts[#parts+1] = "detail=" .. q(s.detail) end
		if s.races then parts[#parts+1] = "races=" .. s.races end
		out[#out+1] = "{" .. table.concat(parts, ",") .. "},"
	end
	out[#out+1] = "}"
	local f = assert(io.open(outDir .. "/Gen_" .. faction .. ".lua", "w"))
	f:write(table.concat(out, "\n")); f:write("\n"); f:close()
	return #steps
end

os.execute("mkdir -p " .. outDir)
local aSteps = buildFaction(ALLIANCE_ORDER, ALLY)
local hSteps = buildFaction(HORDE_ORDER, HORDE)
local na = writeFaction("Alliance", aSteps)
local nh = writeFaction("Horde", hSteps)
print(string.format("Generated Alliance: %d steps, Horde: %d steps", na, nh))
