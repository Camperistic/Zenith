--[[ Modules/Route/Route.lua

     The route engine. Consumes route packs (ns.RegisterRoute) and tracks where the
     player is on the curated path, reacting to StateModel/EventBus changes (level,
     zone, quest log) rather than polling. Race/level applicability is filtered at
     load. The batch "questing loop" planner powers the arrow.

     Public:
       ns.RegisterRoute(flavor, faction, steps)
       ns.Route:Current() / :Count() / :StepAt(i)
       ns.Route:Next() / :Prev() / :Complete() / :Resync()
       ns.Route:NextWaypoint() -> mapID, x, y, label, stage   (batch-aware)
     Fires Bus "ROUTE_CHANGED" (cursor moved) and "ROUTE_LOADED".
]]
local ADDON, ns = ...
local C = ns.compat
local State, Bus = ns.State, ns.Bus

local Route = {}
ns.Route = Route

local routes = {}        -- [flavor][faction] = { steps }
local active = {}        -- flat filtered step list for this character

function ns.RegisterRoute(flavor, faction, steps)
	routes[flavor] = routes[flavor] or {}
	routes[flavor][faction] = steps
	ns.dataPacks[flavor] = true   -- mark the flavour so DataFlavor() can resolve it
end

-- The flavour whose route pack is actually loaded (mirrors ns:DataFlavor(); the
-- loaded TOC is authoritative even if WOW_PROJECT_ID doesn't map to our id).
local function routeFlavor()
	if routes[ns.flavor.id] then return ns.flavor.id end
	local df = ns:DataFlavor(); if routes[df] then return df end
	for fid in pairs(routes) do return fid end
	return ns.flavor.id
end

-- ── race filtering (Blizzard requiredRaces bits) ────────────────────────────────
local RACE_BIT = { Human=1, Orc=2, Dwarf=4, NightElf=8, Scourge=16, Tauren=32,
	Gnome=64, Troll=128, BloodElf=512, Draenei=1024 }
local function raceBit() return RACE_BIT[State:Race() or ""] or 0 end
local function raceAllowed(mask)
	if not mask or mask == 0 then return true end
	local bit = raceBit(); if bit == 0 then return true end
	return math.floor(mask / bit) % 2 == 1
end

-- per-character persisted cursor/completions
local function rdb() return ns.db.char.route end
local function stepKey(s) return s.qid and ("q" .. s.qid) or s.id end

-- ── completion / grey-skip ──────────────────────────────────────────────────────
local GREY_GAP, AHEAD_GAP = 6, 3

local function questComplete(qid)
	return qid and C.IsQuestFlaggedCompleted and C.IsQuestFlaggedCompleted(qid)
end
local function inLog(qid)
	return qid and C.GetLogIndexForQuestID and C.GetLogIndexForQuestID(qid) ~= nil
end
local function readyTurnIn(qid)
	return inLog(qid) and C.IsQuestComplete and C.IsQuestComplete(qid)
end

function Route:IsComplete(s)
	if not s then return true end
	local key = stepKey(s)
	if key and rdb().completed[key] then return true end
	if s.qid and questComplete(s.qid) then return true end
	if (s.kind == "travel" or s.kind == "note") and s.mapID and State:MapID() == s.mapID then return true end
	if ns.db.profile.skipGrey ~= false and s.band and s.band[2] and State:Level() > s.band[2] + GREY_GAP then
		return true
	end
	return false
end

-- ── load + cursor ───────────────────────────────────────────────────────────────
function Route:Load()
	wipe(active)
	local faction = State:Faction()
	local pf = routeFlavor()
	local r = routes[pf] and routes[pf][faction]
	if not r then return end
	local prevTravel = false
	for i, s in ipairs(r) do
		if raceAllowed(s.races) then
			if s.kind == "travel" and prevTravel then
				-- collapse empty consecutive headers
			else
				s.id = s.id or ("q-" .. faction .. "-" .. i)
				active[#active + 1] = s
				prevTravel = (s.kind == "travel")
			end
		end
	end
	rdb().cursor = math.max(1, math.min(rdb().cursor or 1, #active))
	self:Resync()
	Bus:Fire("ROUTE_LOADED")
end

function Route:Count() return #active end
function Route:StepAt(i) return active[i] end
function Route:Current() return active[rdb().cursor or 1] end

function Route:FirstActionable()
	local lvl = State:Level()
	local fallback
	for i = 1, #active do
		local s = active[i]
		if not self:IsComplete(s) then
			fallback = fallback or i
			if not (s.band and s.band[1] and s.band[1] > lvl + AHEAD_GAP) then return i end
		end
	end
	return fallback or (#active + 1)
end

-- Anchor the cursor to where the player actually is (forward past finished work,
-- backward if it ran ahead of the player's level).
function Route:Resync()
	local cur = self:Current()
	local ahead = cur and cur.band and cur.band[1] and cur.band[1] > State:Level() + AHEAD_GAP
	if not cur or ahead or self:IsComplete(cur) then
		rdb().cursor = self:FirstActionable()
	end
	Bus:Fire("ROUTE_CHANGED", self:Current())
end

function Route:Next()
	local i = rdb().cursor or 1
	repeat i = i + 1 until i > #active or not self:IsComplete(active[i])
	rdb().cursor = math.max(1, math.min(i, #active + 1))
	Bus:Fire("ROUTE_CHANGED", self:Current())
end

function Route:Prev()
	rdb().cursor = math.max(1, (rdb().cursor or 1) - 1)
	Bus:Fire("ROUTE_CHANGED", self:Current())
end

function Route:Complete(i)
	i = i or rdb().cursor
	local s = active[i]; if not s then return end
	local key = stepKey(s); if key then rdb().completed[key] = true end
	if i == rdb().cursor then self:Next() else Bus:Fire("ROUTE_CHANGED", self:Current()) end
end

local function poll()
	local s = Route:Current()
	if s and Route:IsComplete(s) then
		local key = stepKey(s); if key then rdb().completed[key] = true end
		Route:Next()
	end
end

-- ── batch "questing loop" waypoint (accept-all → do-all → turn-in-all) ──────────
local BATCH_R2, WINDOW = 144, 40
local function sq(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end
local function action(s)            -- priority, mapID, x, y, stage
	if s.qid then
		if readyTurnIn(s.qid) then return 3, s.tmap or s.mapID, s.tx or s.x, s.ty or s.y, "turn in" end
		if inLog(s.qid)       then return 2, s.omap or s.mapID, s.ox or s.x, s.oy or s.y, "do" end
		return 1, s.mapID, s.x, s.y, "accept"
	end
	return 2, s.mapID, s.x, s.y, "do"
end

function Route:NextWaypoint()
	local idx = rdb().cursor or 1
	local cur = active[idx]; if not cur then return nil end
	local ax, ay, az
	for i = idx, math.min(#active, idx + WINDOW) do
		local s = active[i]
		if s.kind == "quest" and s.x and s.y and not self:IsComplete(s) then ax, ay, az = s.x, s.y, s.zone; break end
	end
	if not ax then
		if cur.mapID and cur.x and cur.y then return cur.mapID, cur.x, cur.y, cur.zone, "go" end
		return nil
	end
	local batch = {}
	for i = idx, math.min(#active, idx + WINDOW) do
		local s = active[i]
		if s.kind == "quest" and not self:IsComplete(s) and s.zone == az then
			if not (s.x and s.y) or sq(ax, ay, s.x, s.y) <= BATCH_R2 then batch[#batch + 1] = s end
		end
	end
	if #batch == 0 then return cur.mapID, cur.x, cur.y, cur.zone, "go" end
	local phase = 9
	for _, s in ipairs(batch) do local p = action(s); if p < phase then phase = p end end
	local px, py, pmap = State:Position()
	local best, bd, bs, bm
	for _, s in ipairs(batch) do
		local p, mp, x, y, st = action(s)
		if p == phase and mp and x and y then
			local rx, ry = ax, ay
			if px and pmap == mp then rx, ry = px, py end
			local d = sq(rx, ry, x, y)
			if not bd or d < bd then bd, best, bs, bm = d, { x = x, y = y }, st, mp end
		end
	end
	if best then return bm, best.x, best.y, (az or "") .. " (" .. bs .. ")", bs end
	return cur.mapID, cur.x, cur.y, cur.zone, "go"
end

-- ── module ───────────────────────────────────────────────────────────────────────
ns.Registry:Add({
	name = "Route",
	IsFeatureEnabled = function() return next(routes) ~= nil end,
	OnEnable = function()
		Route:Load()
		Bus:On("LEVEL_CHANGED",   function() Route:Resync() end)
		Bus:On("ZONE_CHANGED",    function() Route:Resync() end)
		Bus:On("QUESTLOG_CHANGED",function() poll() end)
		Bus:On("SLASH", function(msg)
			if msg == "next" then Route:Next() elseif msg == "prev" then Route:Prev()
			elseif msg == "reset" then rdb().cursor = 1; wipe(rdb().completed); Route:Load() end
		end)
	end,
})
