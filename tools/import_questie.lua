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
local outDir     = arg[2] or "Data/Routes/Generated"

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
local Q = { name=1, startedBy=2, finishedBy=3, reqLevel=4, level=5, races=6, classes=7,
	objText=8, triggerEnd=9, objectives=10, sourceItemId=11, zone=17 }
local NPC_SPAWNS, OBJ_SPAWNS = 7, 4

-- Resolve a creature/object id to a coordinate, preferring a spawn in `zoneArea`.
local function firstSpawn(spawnTable, zoneArea)
	if type(spawnTable) ~= "table" then return nil end
	local z = zoneArea and spawnTable[zoneArea]
	if z and z[1] and z[1][1] then return zoneArea, z[1][1], z[1][2] end
	for aid, coords in pairs(spawnTable) do
		if coords[1] and coords[1][1] then return aid, coords[1][1], coords[1][2] end
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

-- finishedBy = { creatureEnd{}, objectEnd{} } — the quest turn-in location.
local function resolveEnd(finishedBy, zoneArea)
	if type(finishedBy) ~= "table" then return nil end
	local creatures, objs = finishedBy[1], finishedBy[2]
	if type(creatures) == "table" and creatures[1] and npcs[creatures[1]] then
		local a, x, y = firstSpawn(npcs[creatures[1]][NPC_SPAWNS], zoneArea)
		if x then return a, x, y end
	end
	if type(objs) == "table" and objs[1] and objects[objs[1]] then
		local a, x, y = firstSpawn(objects[objs[1]][OBJ_SPAWNS], zoneArea)
		if x then return a, x, y end
	end
end

-- The quest's objective location (where you go to DO it): the first resolvable
-- creature/object objective spawn, or an exploration trigger coordinate.
local function resolveObjective(quest, zoneArea)
	local obj = quest[Q.objectives]
	if type(obj) == "table" then
		local cre = obj[1]   -- creatureObjective {{creatureID, text, icon}, ...}
		if type(cre) == "table" and cre[1] and cre[1][1] and npcs[cre[1][1]] then
			local a, x, y = firstSpawn(npcs[cre[1][1]][NPC_SPAWNS], zoneArea)
			if x then return a, x, y end
		end
		local o = obj[2]     -- objectObjective {{objectID, text, icon}, ...}
		if type(o) == "table" and o[1] and o[1][1] and objects[o[1][1]] then
			local a, x, y = firstSpawn(objects[o[1][1]][OBJ_SPAWNS], zoneArea)
			if x then return a, x, y end
		end
	end
	local te = quest[Q.triggerEnd]   -- {text, {[zoneID] = {coordPair, ...}}}
	if type(te) == "table" and type(te[2]) == "table" then
		local z = zoneArea and te[2][zoneArea]
		if z and z[1] and z[1][1] then return zoneArea, z[1][1], z[1][2] end
		for aid, coords in pairs(te[2]) do
			if coords[1] and coords[1][1] then return aid, coords[1][1], coords[1][2] end
		end
	end
end

-- Name of the first creature this quest asks you to kill (for a target macro).
local function firstObjectiveCreature(quest)
	local obj = quest[Q.objectives]
	if type(obj) == "table" and type(obj[1]) == "table" and obj[1][1] and obj[1][1][1] then
		local id = obj[1][1][1]
		local npc = npcs[id]
		if npc and npc[1] then return npc[1] end
	end
end

local function round(v) return math.floor(v * 10 + 0.5) / 10 end

local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- Travel-optimized within-zone order: group quests into hubs by giver proximity,
-- then visit hubs via a level-banded nearest-neighbour tour (keeps broad level
-- progression in wide zones while doing nearby quests together). Returns an ordered
-- list of { e=entry, x, y, mapID }. Quests whose giver is out-of-zone or has no
-- coordinate are appended at the end (by level).
local HUB_RADIUS, BAND = 6, 3
local function clusterOrder(list, zoneArea, zoneUi)
	local items, others = {}, {}
	for _, e in ipairs(list) do
		local ca, x, y = resolveStart(e.q[Q.startedBy], zoneArea)
		if x and ca == zoneArea then
			items[#items + 1] = { e = e, x = x, y = y, lvl = e.q[Q.level], mapID = zoneUi, starter = e.starter }
		else
			others[#others + 1] = { e = e, lvl = e.q[Q.level],
				x = x, y = y, mapID = (ca and areaInfo[ca] and areaInfo[ca].ui) or zoneUi }
		end
	end
	table.sort(items, function(a, b) return a.lvl < b.lvl end)

	-- build hubs greedily (nearby givers share a hub)
	local hubs = {}
	for _, it in ipairs(items) do
		local h
		for _, hub in ipairs(hubs) do
			if dist(it.x, it.y, hub.cx, hub.cy) <= HUB_RADIUS then h = hub; break end
		end
		if not h then h = { cx = it.x, cy = it.y, items = {}, minLvl = it.lvl }; hubs[#hubs + 1] = h end
		h.items[#h.items + 1] = it
		h.hasStarter = h.hasStarter or it.starter
		local n = #h.items
		h.cx = h.cx + (it.x - h.cx) / n           -- running centroid
		h.cy = h.cy + (it.y - h.cy) / n
		h.minLvl = math.min(h.minLvl, it.lvl)
	end

	local zoneMin = items[1] and items[1].lvl or 1
	for _, h in ipairs(hubs) do h.band = math.floor((h.minLvl - zoneMin) / BAND) end
	table.sort(hubs, function(a, b)
		if a.band ~= b.band then return a.band < b.band end
		return a.minLvl < b.minLvl
	end)

	-- nearest-neighbour the hubs within each level band, carrying the last position
	local ordered, lastx, lasty, i = {}, nil, nil, 1
	while i <= #hubs do
		local band, group = hubs[i].band, {}
		while i <= #hubs and hubs[i].band == band do group[#group + 1] = hubs[i]; i = i + 1 end
		while #group > 0 do
			local bestIdx = 1
			if lastx then
				local bestD = math.huge
				for j, h in ipairs(group) do
					local d = dist(lastx, lasty, h.cx, h.cy)
					if d < bestD then bestD, bestIdx = d, j end
				end
			else
				-- start the zone tour at its racial-start (spawn) hub when there is one
				for j, h in ipairs(group) do if h.hasStarter then bestIdx = j; break end end
			end
			local h = table.remove(group, bestIdx)
			ordered[#ordered + 1] = h
			lastx, lasty = h.cx, h.cy
		end
	end

	-- flatten hubs (within a hub, by level then name)
	local result = {}
	for _, h in ipairs(ordered) do
		table.sort(h.items, function(a, b)
			if a.lvl ~= b.lvl then return a.lvl < b.lvl end
			return (a.e.q[Q.name] or "") < (b.e.q[Q.name] or "")
		end)
		for _, it in ipairs(h.items) do result[#result + 1] = it end
	end
	table.sort(others, function(a, b) return a.lvl < b.lvl end)
	for _, o in ipairs(others) do result[#result + 1] = o end
	return result
end

-- ── Race / faction masks ──────────────────────────────────────────────────────
-- Blizzard requiredRaces bits: Human 1, Orc 2, Dwarf 4, NightElf 8, Undead 16,
-- Tauren 32, Gnome 64, Troll 128, BloodElf 512, Draenei 1024.
local ALLY = { 1, 4, 8, 64, 1024 }             -- Human, Dwarf, NightElf, Gnome, Draenei
local HORDE = { 2, 16, 32, 128, 512 }          -- Orc, Undead, Tauren, Troll, BloodElf
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
	["Northshire Valley"] = 1, ["Elwynn Forest"] = 1,               -- Human
	["Coldridge Valley"] = 68, ["Dun Morogh"] = 68,                 -- Dwarf(4)+Gnome(64)
	["Shadowglen"] = 8, ["Teldrassil"] = 8, ["Darkshore"] = 8,      -- NightElf
	["Ammen Vale"] = 1024, ["Azuremyst Isle"] = 1024, ["Bloodmyst Isle"] = 1024, -- Draenei
	-- Horde
	["Valley of Trials"] = 130, ["Durotar"] = 130,                  -- Orc(2)+Troll(128)
	["Camp Narache"] = 32, ["Mulgore"] = 32,                        -- Tauren
	["Deathknell"] = 16, ["Tirisfal Glades"] = 16, ["Silverpine Forest"] = 16, -- Undead
	["Sunstrider Isle"] = 512, ["Eversong Woods"] = 512, ["Ghostlands"] = 512,  -- BloodElf
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
		-- Racial starter sub-zones (Northshire=9, Coldridge Valley, Shadowglen, Ammen
		-- Vale, Valley of Trials, Deathknell, Sunstrider Isle, …) carry a zoneOrSort
		-- areaID that Questie's areaId→uiMapId table doesn't list, so these level-1
		-- spawn quests would be dropped entirely. Fall back to the giver's spawn area
		-- (whose coords already live on the parent zone's map), and remember it's a
		-- starter quest so its hub leads that zone's tour (you begin where you log in).
		local starter = false
		if not (type(zoneArea) == "number" and areaInfo[zoneArea]) then
			local ca = resolveStart(q[Q.startedBy])
			if ca and areaInfo[ca] then zoneArea = ca; starter = true end
		end
		local zoneName = type(zoneArea) == "number" and areaInfo[zoneArea] and areaInfo[zoneArea].name
		if starter and not ZONE_OWNER[zoneName] then starter = false end   -- only racial starts lead
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
			table.insert(byZone[zoneArea], { qid = qid, q = q, starter = starter })
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
		local ui = areaInfo[z.area].ui
		local owner = ZONE_OWNER[z.name]
		steps[#steps + 1] = { kind = "travel", zone = z.name, mapID = ui, band = { z.minLvl, z.minLvl + 3 },
			text = "Travel to " .. z.name, races = owner }
		for _, it in ipairs(clusterOrder(z.list, z.area, ui)) do
			local q = it.e.q
			local lvl = q[Q.level]
			local reqL = q[Q.reqLevel] and q[Q.reqLevel] > 0 and q[Q.reqLevel] or lvl
			local detail = type(q[Q.objText]) == "table" and q[Q.objText][1] or nil
			-- In a racial start zone, force the owner mask; elsewhere keep the quest's own.
			local races = owner or ((q[Q.races] and q[Q.races] ~= 0) and q[Q.races] or nil)
			local st = {
				kind = "quest", zone = z.name, mapID = it.mapID, qid = it.e.qid,
				x = it.x and round(it.x) or nil,
				y = it.y and round(it.y) or nil,
				band = { reqL, lvl }, quest = q[Q.name], text = q[Q.name], detail = detail,
				races = races,
			}
			-- Objective coordinate (where to go DO the quest), stored when meaningfully
			-- far from the giver so the arrow can step giver → objective → turn-in.
			local oca, ox, oy = resolveObjective(q, z.area)
			if ox then
				local omap = (oca and areaInfo[oca] and areaInfo[oca].ui) or it.mapID
				local far = it.x and it.y and (math.abs(ox - it.x) + math.abs(oy - it.y) > 4)
				if omap ~= st.mapID or far or not it.x then
					st.ox, st.oy, st.omap = round(ox), round(oy), omap
				end
			end
			-- Turn-in coordinate (where to hand the quest in), stored only when it's
			-- meaningfully different from the giver — so the arrow can switch to it
			-- once objectives are complete.
			local fca, fx, fy = resolveEnd(q[Q.finishedBy], z.area)
			if fx then
				local fmap = (fca and areaInfo[fca] and areaInfo[fca].ui) or it.mapID
				local far = it.x and it.y and (math.abs(fx - it.x) + math.abs(fy - it.y) > 4)
				if fmap ~= st.mapID or far or not it.x then
					st.tx, st.ty, st.tmap = round(fx), round(fy), fmap
				end
			end
			-- Quest-provided item to use (e.g. an orb), and the mob to target.
			local item = q[Q.sourceItemId]
			if type(item) == "number" and item > 0 then st.item = item end
			st.target = firstObjectiveCreature(q)
			steps[#steps + 1] = st
		end
	end
	return steps
end

-- ── Serialize ─────────────────────────────────────────────────────────────────
-- Quote a string for a Lua source literal: escape backslash, quote, and any
-- control chars (a literal newline/tab inside "..." is a Lua syntax error).
local function q(s)
	s = tostring(s):gsub("\\", "\\\\"):gsub("\"", "\\\"")
		:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
	return "\"" .. s .. "\""
end

local function writeFaction(faction, steps)
	local out = {}
	out[#out+1] = "-- AUTO-GENERATED from the Questie TBC database by tools/import_questie.lua"
	out[#out+1] = "-- Quest facts in Zenith's format; data © upstream (CMaNGOS/Questie), GPL. See CREDITS.md."
	out[#out+1] = "local ADDON, ns = ..."
	out[#out+1] = "ns.RegisterRoute(\"tbc\", \"" .. faction .. "\", {"
	for _, s in ipairs(steps) do
		local parts = { "kind=" .. q(s.kind), "zone=" .. q(s.zone) }
		if s.qid then parts[#parts+1] = "qid=" .. s.qid end
		if s.mapID then parts[#parts+1] = "mapID=" .. s.mapID end
		if s.x then parts[#parts+1] = "x=" .. s.x end
		if s.y then parts[#parts+1] = "y=" .. s.y end
		if s.ox then parts[#parts+1] = "ox=" .. s.ox end
		if s.oy then parts[#parts+1] = "oy=" .. s.oy end
		if s.omap then parts[#parts+1] = "omap=" .. s.omap end
		if s.tx then parts[#parts+1] = "tx=" .. s.tx end
		if s.ty then parts[#parts+1] = "ty=" .. s.ty end
		if s.tmap then parts[#parts+1] = "tmap=" .. s.tmap end
		if s.band then parts[#parts+1] = "band={" .. s.band[1] .. "," .. s.band[2] .. "}" end
		if s.quest then parts[#parts+1] = "quest=" .. q(s.quest) end
		if s.text then parts[#parts+1] = "text=" .. q(s.text) end
		if s.detail then parts[#parts+1] = "detail=" .. q(s.detail) end
		if s.target then parts[#parts+1] = "target=" .. q(s.target) end
		if s.item then parts[#parts+1] = "item=" .. s.item end
		if s.races then parts[#parts+1] = "races=" .. s.races end
		out[#out+1] = "{" .. table.concat(parts, ",") .. "},"
	end
	out[#out+1] = "})"
	local f = assert(io.open(outDir .. "/Route_" .. faction .. ".lua", "w"))
	f:write(table.concat(out, "\n")); f:write("\n"); f:close()
	return #steps
end

os.execute("mkdir -p " .. outDir)
local aSteps = buildFaction(ALLIANCE_ORDER, ALLY)
local hSteps = buildFaction(HORDE_ORDER, HORDE)
local na = writeFaction("Alliance", aSteps)
local nh = writeFaction("Horde", hSteps)
print(string.format("Generated Alliance: %d steps, Horde: %d steps", na, nh))
