--[[ tools/build_pack.lua

   Transforms the open Questie TBC database into Zenith's own compact, ID-keyed,
   ZONE-grouped, LAZY-PARSED quest pack. Each zone's quests are serialized to a
   Lua string and only parsed (loadstring) when that zone is first needed, so the
   full database never sits parsed in memory at login — the perf discipline Pillar 1
   requires. (No Questie code is shipped; only extracted facts in Zenith's format.)

   Output: Data/packs/tbc/QuestData.lua  →  ns.RegisterZonePack("tbc", { [uiMapID] = "<serialized>" })

   Usage: lua5.1 tools/build_pack.lua <questie_dir> <out_file>
   Quest record (compact, per quest id):
     { name, level, reqLevel, races, gm,gx,gy, tm,tx,ty, item, target, obj={ {m,x,y}, ... } }
]]
local questieDir = arg[1] or "/tmp/questie"
local outFile    = arg[2] or "Data/packs/tbc/QuestData.lua"

local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function extractTable(text, marker)
	local i = assert(text:find(marker, 1, true), "marker: " .. marker)
	local b = assert(text:find("%[%[", i)); local e = assert(text:find("%]%]", b))
	return assert(loadstring(text:sub(b + 2, e - 1)))()
end

local quests  = extractTable(slurp(questieDir .. "/Database/TBC/tbcQuestDB.lua"), "QuestieDB.questData")
local npcs    = extractTable(slurp(questieDir .. "/Database/TBC/tbcNpcDB.lua"), "QuestieDB.npcData")
local objects = extractTable(slurp(questieDir .. "/Database/TBC/tbcObjectDB.lua"), "QuestieDB.objectData")

local areaUi, areaName = {}, {}
for line in slurp(questieDir .. "/Database/Zones/data/areaIdToUiMapId.lua"):gmatch("[^\n]+") do
	local aid, uid, name = line:match("%[(%d+)%]%s*=%s*(%d+),%s*%-%-%s*(.+)")
	if aid then areaUi[tonumber(aid)] = tonumber(uid); areaName[tonumber(aid)] = (name:gsub("%s+$", "")) end
end

local Q = { name=1, startedBy=2, finishedBy=3, reqLevel=4, level=5, races=6, objText=8,
	triggerEnd=9, objectives=10, sourceItemId=11, zone=17 }
local NPC_SPAWNS, OBJ_SPAWNS = 7, 4
local function round(v) return v and math.floor(v * 10 + 0.5) / 10 or nil end

local function firstSpawn(spawns, zone)
	if type(spawns) ~= "table" then return nil end
	local z = zone and spawns[zone]
	if z and z[1] and z[1][1] then return zone, z[1][1], z[1][2] end
	for aid, c in pairs(spawns) do if c[1] and c[1][1] then return aid, c[1][1], c[1][2] end end
end
local function resolve(ref, zone)        -- ref = {creatures, objects}
	if type(ref) ~= "table" then return nil end
	local cr, ob = ref[1], ref[2]
	if type(cr) == "table" and cr[1] and npcs[cr[1]] then
		local a, x, y = firstSpawn(npcs[cr[1]][NPC_SPAWNS], zone); if x then return a, x, y end
	end
	if type(ob) == "table" and ob[1] and objects[ob[1]] then
		local a, x, y = firstSpawn(objects[ob[1]][OBJ_SPAWNS], zone); if x then return a, x, y end
	end
end
local function objectiveCreatureName(qd)
	local o = qd[Q.objectives]
	if type(o) == "table" and type(o[1]) == "table" and o[1][1] and o[1][1][1] then
		local n = npcs[o[1][1][1]]; return n and n[1]
	end
end
local function objectiveCoords(qd, zone)
	local list, o = {}, qd[Q.objectives]
	if type(o) == "table" then
		for _, sub in ipairs({ o[1], o[2] }) do
			if type(sub) == "table" then
				for _, e in ipairs(sub) do
					local id = e[1]
					local db = (sub == o[1]) and npcs or objects
					local sp = db[id] and db[id][(sub == o[1]) and NPC_SPAWNS or OBJ_SPAWNS]
					local a, x, y = firstSpawn(sp, zone)
					if x then list[#list + 1] = { areaUi[a] or areaUi[zone], round(x), round(y) }; break end
				end
			end
		end
	end
	return #list > 0 and list or nil
end

-- ── serialize one quest record compactly ──────────────────────────────────────
local function qstr(s) return string.format("%q", s) end
local function recordStr(id, qd)
	local zone = qd[Q.zone]
	local gm, gx, gy = resolve(qd[Q.startedBy], zone)
	local tm, tx, ty = resolve(qd[Q.finishedBy], zone)
	local parts = { "name=" .. qstr(qd[Q.name]), "lvl=" .. (qd[Q.level] or 0) }
	if qd[Q.reqLevel] and qd[Q.reqLevel] > 0 then parts[#parts+1] = "req=" .. qd[Q.reqLevel] end
	if qd[Q.races] and qd[Q.races] ~= 0 then parts[#parts+1] = "races=" .. qd[Q.races] end
	if gx then parts[#parts+1] = string.format("gm=%d,gx=%s,gy=%s", areaUi[gm] or 0, round(gx), round(gy)) end
	if tx then parts[#parts+1] = string.format("tm=%d,tx=%s,ty=%s", areaUi[tm] or 0, round(tx), round(ty)) end
	if type(qd[Q.sourceItemId]) == "number" and qd[Q.sourceItemId] > 0 then parts[#parts+1] = "item=" .. qd[Q.sourceItemId] end
	local tgt = objectiveCreatureName(qd); if tgt then parts[#parts+1] = "target=" .. qstr(tgt) end
	local oc = objectiveCoords(qd, zone)
	if oc then
		local segs = {}
		for _, c in ipairs(oc) do segs[#segs+1] = string.format("{%d,%s,%s}", c[1] or 0, c[2], c[3]) end
		parts[#parts+1] = "obj={" .. table.concat(segs, ",") .. "}"
	end
	return "[" .. id .. "]={" .. table.concat(parts, ",") .. "}"
end

-- ── group quests by zone uiMapID, skip instances/no-coord ──────────────────────
local byZone = {}
for id, qd in pairs(quests) do
	local zone, name, lvl = qd[Q.zone], qd[Q.name], qd[Q.level] or 0
	local zname = type(zone) == "number" and areaName[zone]
	local inst = zname and (zname:find("%- Dungeon") or zname:find("%- Raid") or zname:find("%- Battleground"))
	if name and #name > 0 and not name:find("%(") and zname and not inst
		and areaUi[zone] and areaUi[zone] > 0 and lvl > 0 and lvl <= 70 then
		local ui = areaUi[zone]
		byZone[ui] = byZone[ui] or {}
		byZone[ui][#byZone[ui] + 1] = recordStr(id, qd)
	end
end

-- ── write the pack: one serialized string per zone (lazy-parsed at runtime) ────
local out = {
	"-- AUTO-GENERATED by tools/build_pack.lua from the Questie TBC database.",
	"-- Quest facts in Zenith's own format; data © upstream (CMaNGOS/Questie), GPL. See CREDITS.md.",
	"local ADDON, ns = ...",
	"ns.RegisterZonePack(\"tbc\", {",
}
local zones = {}
for ui in pairs(byZone) do zones[#zones + 1] = ui end
table.sort(zones)
local total = 0
for _, ui in ipairs(zones) do
	local recs = byZone[ui]; total = total + #recs
	out[#out + 1] = string.format("[%d]=[[return {%s}]],", ui, table.concat(recs, ",\n"))
end
out[#out + 1] = "})"

local f = assert(io.open(outFile, "w"))
f:write(table.concat(out, "\n")); f:write("\n"); f:close()
print(string.format("Wrote %s — %d zones, %d quests", outFile, #zones, total))
