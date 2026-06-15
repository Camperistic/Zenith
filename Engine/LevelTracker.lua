--[[ Engine/LevelTracker.lua

     Tracks active (logged-in) time spent per level and overall, plus a live
     "time to next level" estimate from your current XP rate. Stored per character.

     We use monotonic GetTime() deltas accumulated into ns.char.tracker.activeTotal
     across sessions, so it measures real played time without relying on the
     /played request (no chat spam). splits[L] = active seconds when you dinged
     into level L; the per-level duration is splits[L+1] - splits[L].
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("LevelTracker")
ns.LevelTracker = M

local loginTime = 0

local function tracker()
	ns.char.tracker = ns.char.tracker or { splits = {}, activeTotal = 0 }
	ns.char.tracker.splits = ns.char.tracker.splits or {}
	return ns.char.tracker
end

-- Total active seconds played on this character (across sessions).
function M:ActiveSeconds()
	return (tracker().activeTotal or 0) + (GetTime() - loginTime)
end

-- Seconds spent at a given level (nil if not fully tracked).
function M:LevelDuration(level)
	local s = tracker().splits
	if s[level] and s[level + 1] then return s[level + 1] - s[level] end
	if s[level] and level == U.PlayerLevel() then return M:ActiveSeconds() - s[level] end
end

-- "1h 23m" / "12m 04s"
function M:Format(sec)
	sec = math.floor(sec or 0)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	if h > 0 then return string.format("%dh %02dm", h, m) end
	return string.format("%dm %02ds", m, sec % 60)
end

-- Estimated seconds to the next ding from the current XP rate, or nil.
function M:ETANextLevel()
	if U.PlayerLevel() >= 70 then return nil end
	local maxXP = UnitXPMax and UnitXPMax("player") or 0
	if maxXP <= 0 then return nil end
	local frac = (UnitXP("player") or 0) / maxXP
	local elapsed = M:LevelDuration(U.PlayerLevel())
	if not elapsed or elapsed < 30 or frac <= 0.02 then return nil end
	local rate = frac / elapsed          -- fraction of the level per second
	if rate <= 0 then return nil end
	return (1 - frac) / rate
end

function M:OnEnable()
	loginTime = GetTime()
	local t = tracker()
	-- Mark the start of the current level if we've never seen it.
	if not t.splits[U.PlayerLevel()] then t.splits[U.PlayerLevel()] = M:ActiveSeconds() end

	ns:On("PLAYER_LEVEL_UP", function(_, level)
		level = tonumber(level) or U.PlayerLevel()
		t.splits[level] = M:ActiveSeconds()      -- dinged into this level now
		ns:SendMessage("ZENITH_LEVEL_TRACKED", level)
	end)
	-- Persist accumulated active time on logout/reload.
	ns:On("PLAYER_LOGOUT", function() t.activeTotal = M:ActiveSeconds() end)
end
