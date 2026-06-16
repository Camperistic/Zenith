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

-- ── class filtering (Blizzard requiredClasses bits) ─────────────────────────────
local CLASS_BIT = { WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16,
	SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024 }
local function classBit() return CLASS_BIT[State:Class() or ""] or 0 end
local function classAllowed(mask)
	if not mask or mask == 0 then return true end
	local bit = classBit(); if bit == 0 then return true end
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

-- ── route mode (how many quests to include) ─────────────────────────────────────
-- A step carries optionality s.o: nil/1 = core chain, 2 = optional side quest,
-- 3 = completionist (repeatable/profession/rep/elite/group). The mode caps it.
local MODE_MAX = { fast = 1, balanced = 2, complete = 3 }
local function modeCap() return MODE_MAX[ns.db.profile.routeMode or "balanced"] or 2 end

-- ── load + cursor ───────────────────────────────────────────────────────────────
function Route:Load()
	wipe(active)
	local faction = State:Faction()
	local pf = routeFlavor()
	local r = routes[pf] and routes[pf][faction]
	if not r then return end
	local cap = modeCap()
	local prevTravel = false
	for i, s in ipairs(r) do
		if raceAllowed(s.races) and classAllowed(s.c) and (not s.o or s.o <= cap) then
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

-- Auto-catchup: walk the whole route, mark every step whose quest IsQuestFlagged-
-- Completed as done (persisted per-character), then re-anchor the cursor. Run once
-- after the quest log is primed, so a fresh install on a leveled character lands
-- on the first quest you actually still need to do — not back at step 1.
function Route:CatchUp()
	local n = 0
	for _, s in ipairs(active) do
		if s.qid and questComplete(s.qid) then
			local key = stepKey(s)
			if key and not rdb().completed[key] then
				rdb().completed[key] = true; n = n + 1
			end
		end
	end
	self:Resync()
	if ns and ns.Print and n > 0 then
		ns:Print(string.format("caught up: %d quest%s already done, you're on step %d / %d.",
			n, n == 1 and "" or "s", rdb().cursor or 1, #active))
	end
	return n
end

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

-- ── batch "questing loop" guidance (accept-all → do-all → turn-in-all) ──────────
-- Grab every quest clustered around the same spot, do them together, then turn them
-- all in — the efficient RestedXP-style loop. Guidance() returns the single next
-- action so the arrow and the Guide card stay in lockstep (accept this nearby quest →
-- … → do these → … → turn these in), one concrete step at a time.
local BATCH_R2, WINDOW = 144, 40        -- ~12-yd cluster radius; look-ahead window
local function sq(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end
local function action(s)                -- priority(low=do first), mapID, x, y, stage
	if s.qid then
		if readyTurnIn(s.qid) then return 3, s.tmap or s.mapID, s.tx or s.x, s.ty or s.y, "turn in" end
		if inLog(s.qid)       then return 2, s.omap or s.mapID, s.ox or s.x, s.oy or s.y, "do" end
		return 1, s.mapID, s.x, s.y, "accept"
	end
	return 2, s.mapID, s.x, s.y, "go"
end

-- { stage = "accept"|"do"|"turn in"|"go", step, mapID, x, y, label } or nil.
function Route:Guidance()
	local idx = rdb().cursor or 1
	local cur = active[idx]; if not cur then return nil end
	local function plain(s) return { stage = "go", step = s, mapID = s.mapID, x = s.x, y = s.y, label = s.zone or "" } end

	-- anchor on the first incomplete quest with coords inside the look-ahead window
	local ax, ay, az
	for i = idx, math.min(#active, idx + WINDOW) do
		local s = active[i]
		if s.kind == "quest" and s.x and s.y and not self:IsComplete(s) then ax, ay, az = s.x, s.y, s.zone; break end
	end
	if not ax then return plain(cur) end

	-- the cluster: incomplete quests in the same zone within BATCH_R2 of the anchor
	local batch = {}
	for i = idx, math.min(#active, idx + WINDOW) do
		local s = active[i]
		if s.kind == "quest" and not self:IsComplete(s) and s.zone == az then
			if not (s.x and s.y) or sq(ax, ay, s.x, s.y) <= BATCH_R2 then batch[#batch + 1] = s end
		end
	end
	if #batch == 0 then return plain(cur) end

	-- lowest active phase across the cluster → accept everything, then do, then turn in
	local phase = 9
	for _, s in ipairs(batch) do local p = action(s); if p < phase then phase = p end end
	-- pick the nearest cluster member in that phase (from the player if we know where)
	local px, py, pmap = State:Position()
	local best, bd
	for _, s in ipairs(batch) do
		local p, mp, x, y, st = action(s)
		if p == phase and mp and x and y then
			local rx, ry = ax, ay
			if px and pmap == mp then rx, ry = px, py end
			local d = sq(rx, ry, x, y)
			if not bd or d < bd then bd = d; best = { stage = st, step = s, mapID = mp, x = x, y = y,
				label = (s.zone or "") .. " (" .. st .. ")" } end
		end
	end
	return best or plain(cur)
end

function Route:NextWaypoint()
	local g = self:Guidance()
	if not g or not (g.mapID and g.x and g.y) then return nil end
	return g.mapID, g.x, g.y, g.label, g.stage
end

-- Plan(limit): a forward-simulated list of the next `limit` actions, batched.
-- For each cluster of nearby quests it emits accept-all → do-all → turn-in-all, so
-- UP NEXT reads like RestedXP: ACCEPT q1 / ACCEPT q2 / DO q1 / DO q2 / TURN IN q1 /
-- TURN IN q2 / ACCEPT next cluster …  Drives the Guide's UP NEXT list.
local PHASE_NEXT = { todo = "doing", doing = "ready", ready = "done" }
function Route:Plan(limit)
	limit = limit or 12
	local plan, sim = {}, {}                -- sim[qid]="todo|doing|ready|done", sim[stepKey]=true
	local function qstate(qid)
		if sim[qid] then return sim[qid] end
		if questComplete(qid) then return "done" end
		if readyTurnIn(qid)   then return "ready" end
		if inLog(qid)         then return "doing" end
		return "todo"
	end
	local function stepDone(s)
		local k = stepKey(s); if k and sim[k] then return true end
		return self:IsComplete(s)
	end

	local i = rdb().cursor or 1
	while #plan < limit and i <= #active do
		local s = active[i]
		if stepDone(s) then
			i = i + 1
		elseif s.kind ~= "quest" then
			plan[#plan + 1] = { stage = "go", step = s, label = s.text or s.zone or "" }
			local k = stepKey(s); if k then sim[k] = true end
			i = i + 1
		elseif not (s.x and s.y) or not s.qid then
			plan[#plan + 1] = { stage = "accept", step = s, label = s.text or s.quest or "" }
			local k = stepKey(s); if k then sim[k] = true end
			i = i + 1
		else
			-- form the cluster: incomplete quests in the same zone within BATCH_R2
			local az, ax, ay = s.zone, s.x, s.y
			local cluster, last = {}, i
			for j = i, math.min(#active, i + WINDOW) do
				local q = active[j]
				if q.kind == "quest" and not stepDone(q) and q.zone == az then
					if not (q.x and q.y) or sq(ax, ay, q.x, q.y) <= BATCH_R2 then
						cluster[#cluster + 1] = q; last = j
					end
				end
			end
			-- emit phases in order: accept everything, do everything, turn it all in
			for _, phase in ipairs({ "accept", "do", "turn in" }) do
				for _, q in ipairs(cluster) do
					if #plan >= limit then break end
					local cur = qstate(q.qid)
					local needed = (cur == "todo"  and "accept")
						or (cur == "doing" and "do")
						or (cur == "ready" and "turn in")
					if needed == phase then
						plan[#plan + 1] = { stage = phase, step = q, label = q.text or q.quest or "" }
						sim[q.qid] = PHASE_NEXT[cur]
						if phase == "turn in" then local k = stepKey(q); if k then sim[k] = true end end
					end
				end
				if #plan >= limit then break end
			end
			i = last + 1
		end
	end
	return plan
end

-- ── module ───────────────────────────────────────────────────────────────────────
ns.Registry:Add({
	name = "Route",
	IsFeatureEnabled = function() return next(routes) ~= nil end,
	OnEnable = function()
		Route:Load()
		Bus:On("LEVEL_CHANGED",   function() Route:Resync() end)
		Bus:On("ZONE_CHANGED",    function() Route:Resync() end)
		local caughtUp = false
		Bus:On("QUESTLOG_CHANGED",function()
			if not caughtUp then caughtUp = true; Route:CatchUp() end
			poll()
		end)
		Bus:On("SETTINGS_CHANGED",function(key) if key == "routeMode" then Route:Load() end end)
		Bus:On("SLASH", function(msg)
			if msg == "next" then Route:Next() elseif msg == "prev" then Route:Prev()
			elseif msg == "catchup" then Route:CatchUp()
			elseif msg == "reset" then rdb().cursor = 1; wipe(rdb().completed); Route:Load() end
		end)
	end,
})
