--[[ Core/Util.lua : small shared helpers (color, class/faction, map coords). ]]
local ADDON_NAME, ns = ...

local U = {}
ns.U = U

-- Wrap text in a |cAARRGGBB...|r escape.
function U.Color(text, r, g, b)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
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
