--[[ Core/Util.lua : small shared helpers (color, class/faction, map coords). ]]
local ADDON_NAME, ns = ...

local U = {}
ns.U = U

-- Wrap text in a |cAARRGGBB...|r escape. (Round to ints — Lua 5.1 %x wants integers.)
function U.Color(text, r, g, b)
	return string.format("|cff%02x%02x%02x%s|r",
		math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

function U.Accent(text)
	local c = ns.COLORS.accent
	return U.Color(text, c[1], c[2], c[3])
end

function U.Gold(text)
	local c = ns.COLORS.gold
	return U.Color(text, c[1], c[2], c[3])
end

function U.Dim(text)
	local c = ns.COLORS.dim
	return U.Color(text, c[1], c[2], c[3])
end

-- "Hunter" etc. (locale-independent class file token) + faction token.
function U.PlayerClass()
	local _, classFile = UnitClass("player")
	return classFile
end

function U.PlayerFaction()
	return UnitFactionGroup("player")    -- "Alliance" | "Horde"
end

function U.PlayerLevel()
	return UnitLevel("player")
end

-- Race bitmask (matches Questie/Blizzard requiredRaces) for filtering quest steps.
local RACE_BIT = {
	Human = 1, Dwarf = 2, NightElf = 4, Gnome = 8, Draenei = 1024,
	Orc = 16, Scourge = 32, Tauren = 64, Troll = 128, BloodElf = 512,
}
function U.PlayerRaceBit()
	local _, token = UnitRace("player")
	return RACE_BIT[token] or 0
end

-- Is a quest with this requiredRaces mask available to the player? (nil/0 = all)
function U.RaceAllowed(mask)
	if not mask or mask == 0 then return true end
	local bit = U.PlayerRaceBit()
	if bit == 0 then return true end
	return math.floor(mask / bit) % 2 == 1
end

-- Current player position on its map, as 0-100 numbers, or nil.
function U.PlayerPosition()
	local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not mapID then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return nil, nil, mapID end
	local x, y = pos:GetXY()
	if not x or x == 0 and y == 0 then return nil, nil, mapID end
	return x * 100, y * 100, mapID
end

-- The uiMapID the player is currently on (nil if unavailable).
function U.PlayerMapID()
	return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

-- Map name from uiMapID.
function U.MapName(mapID)
	if not mapID or not C_Map then return "" end
	local info = C_Map.GetMapInfo(mapID)
	return info and info.name or ""
end

-- Distance (in map %) between player and a coord on the same map. nil if off-map.
function U.DistanceTo(targetMapID, tx, ty)
	local px, py, mapID = U.PlayerPosition()
	if not px or mapID ~= targetMapID then return nil end
	local dx, dy = tx - px, ty - py
	return math.sqrt(dx * dx + dy * dy), dx, dy
end

-- Has the player completed this quest? (safe across TBC Classic builds)
function U.IsQuestComplete(questID)
	if not questID then return false end
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		return C_QuestLog.IsQuestFlaggedCompleted(questID)
	end
	if IsQuestFlaggedCompleted then
		return IsQuestFlaggedCompleted(questID)
	end
	return false
end

-- Quest is in the log and its objectives are complete (ready to hand in).
function U.QuestReadyToTurnIn(questID)
	if not questID then return false end
	if C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.GetLogIndexForQuestID then
		return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil and C_QuestLog.IsComplete(questID)
	end
	return false
end

-- Is the quest currently in the player's log?
function U.IsQuestInLog(questID)
	if not questID then return false end
	if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
		return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
	end
	if GetQuestLogIndexByID then
		return (GetQuestLogIndexByID(questID) or 0) > 0
	end
	return false
end

-- Round to n decimals.
function U.Round(v, n)
	local m = 10 ^ (n or 0)
	return math.floor(v * m + 0.5) / m
end

-- Clamp.
function U.Clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

-- Expand a compact grouped talent plan into a per-point order list (1 point per
-- level, starting at L10). Each group: { tree, talent, n=points, spike=bool, note }.
-- The spike/note attach to the point that COMPLETES the talent (last of the group).
function U.TalentPath(groups)
	local order, level = {}, 10
	for _, g in ipairs(groups) do
		for i = 1, (g.n or 1) do
			local last = (i == (g.n or 1))
			order[#order + 1] = {
				level  = level,
				tree   = g.tree,
				talent = g.talent,
				spike  = g.spike and last or false,
				note   = last and g.note or nil,
			}
			level = level + 1
			if level > 70 then return order end
		end
	end
	return order
end

-- ── Quest-log tracking (title-based; locale enUS/enGB) ─────────────────────────
-- We track quests by TITLE rather than hard-coding quest IDs, so the route data
-- stays readable and we never ship a wrong ID. A small cache is rebuilt on
-- QUEST_LOG_UPDATE. `seen` (persisted per-char) lets us detect turn-ins: a quest
-- that was in the log and now isn't was almost certainly handed in.
local qInLog, qDone = {}, {}

function U.RefreshQuestLog()
	wipe(qInLog); wipe(qDone)
	local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
		or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
	for i = 1, n do
		local title, isHeader, isComplete, qID
		if C_QuestLog and C_QuestLog.GetInfo then
			local info = C_QuestLog.GetInfo(i)
			if info then
				title, isHeader, qID = info.title, info.isHeader, info.questID
				isComplete = info.isComplete
				if not isComplete and qID and C_QuestLog.IsComplete then
					isComplete = C_QuestLog.IsComplete(qID)
				end
			end
		elseif GetQuestLogTitle then
			local t, _, _, header, _, complete = GetQuestLogTitle(i)
			title, isHeader, isComplete = t, header, (complete == 1 or complete == true)
		end
		if title and not isHeader then
			local key = title:lower()
			qInLog[key] = true
			if isComplete then qDone[key] = true end
			if ns.char and ns.char.seenQuests then ns.char.seenQuests[key] = true end
		end
	end
end

function U.QuestInLog(title)
	return title and qInLog[title:lower()] == true
end

function U.QuestObjectivesDone(title)
	return title and qDone[title:lower()] == true
end

-- Was the quest seen in the log earlier and is now gone? (turned in)
function U.QuestTurnedIn(title)
	if not title then return false end
	local key = title:lower()
	return ns.char and ns.char.seenQuests and ns.char.seenQuests[key] and not qInLog[key]
end
