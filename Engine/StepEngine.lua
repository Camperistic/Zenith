--[[ Engine/StepEngine.lua

     Owns the active route: the ordered list of steps, the current step pointer,
     and automatic step completion (by quest turn-in, level reached, or arrival
     at a coordinate). Broadcasts:

       ZENITH_ROUTE_LOADED          ()                 route swapped / first load
       ZENITH_STEP_CHANGED          (index, step)      current step moved
       ZENITH_STEP_COMPLETED        (index, step)      a step was marked done

     Step schema is documented in Data/Routes/*.lua.
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("StepEngine")

local activeSteps = {}     -- flat list for the current class+faction
ns.StepEngine = M

-- Build the active step list from the generated quest route for the player's
-- faction, keeping only quests available to this character's race. Consecutive
-- zone headers left empty by the race filter are collapsed.
function M:LoadRoute()
	wipe(activeSteps)
	local faction = U.PlayerFaction()
	local questRoute = ns.data.questRoute and ns.data.questRoute[faction]
	if not questRoute then return end   -- generated data missing → empty route

	local prevTravel = false
	for i, step in ipairs(questRoute) do
		if U.RaceAllowed(step.races) then
			if step.kind == "travel" and prevTravel then
				-- skip: previous step was also an (empty) zone header
			else
				step.id = step.id or ("q-" .. faction .. "-" .. i)
				activeSteps[#activeSteps + 1] = step
				prevTravel = (step.kind == "travel")
			end
		end
	end

	ns.char.stepIndex = U.Clamp(ns.char.stepIndex or 1, 1, math.max(1, #activeSteps))
	-- Position the cursor where the player actually is (forward past finished work,
	-- backward if a stale/ahead cursor was saved).
	M:Resync()
	ns:SendMessage("ZENITH_ROUTE_LOADED")
end

function M:Steps() return activeSteps end
function M:Count() return #activeSteps end

function M:StepAt(i) return activeSteps[i] end

function M:CurrentStep()
	return activeSteps[ns.char.stepIndex or 1]
end

-- The first step at/after the cursor that carries a waypoint coordinate (so a
-- coordinate-less "Travel to X" header still points the arrow at the next objective).
function M:NextCoordStep()
	for i = ns.char.stepIndex or 1, #activeSteps do
		local s = activeSteps[i]
		if s and s.mapID and s.x and s.y then return s end
	end
end

-- ── Batch-aware "questing loop" waypoint ──────────────────────────────────────
-- Groups the nearby quests around the cursor into one geographic batch (the hub
-- the importer already clustered) and walks you through it the way you actually
-- quest: accept everything nearby, do all the objectives, then loop back and turn
-- them all in. Phase = the lowest-priority action present in the batch
-- (accept < do < turn-in); within a phase, head to the nearest one.
local BATCH_R2 = 12 * 12          -- batch radius² (map %) around the anchor
local WINDOW = 40                 -- how far ahead to look for batch members

local function sq(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

-- priority, mapID, x, y, stage for a not-yet-finished quest step.
local function stepAction(s)
	if s.qid then
		if U.QuestReadyToTurnIn(s.qid) then return 3, s.tmap or s.mapID, s.tx or s.x, s.ty or s.y, "turn in" end
		if U.IsQuestInLog(s.qid)       then return 2, s.omap or s.mapID, s.ox or s.x, s.oy or s.y, "do" end
		return 1, s.mapID, s.x, s.y, "accept"
	end
	return 2, s.mapID, s.x, s.y, "do"
end

function M:NextWaypoint()
	local idx = ns.char.stepIndex or 1
	local cur = activeSteps[idx]
	if not cur then return nil end

	-- anchor on the first upcoming open quest with coordinates
	local ax, ay, azone
	for i = idx, math.min(#activeSteps, idx + WINDOW) do
		local s = activeSteps[i]
		if s.kind == "quest" and s.x and s.y and not M:IsStepComplete(s) then
			ax, ay, azone = s.x, s.y, s.zone; break
		end
	end
	if not ax then
		local s = M:NextCoordStep()
		if s then return s.mapID, s.x, s.y, s.zone, "go" end
		return M:WaypointFor(cur)
	end

	-- collect the batch: open quests in the same zone within radius of the anchor
	local batch = {}
	for i = idx, math.min(#activeSteps, idx + WINDOW) do
		local s = activeSteps[i]
		if s.kind == "quest" and not M:IsStepComplete(s) and s.zone == azone then
			if not (s.x and s.y) or sq(ax, ay, s.x, s.y) <= BATCH_R2 then
				batch[#batch + 1] = s
			end
		end
	end
	if #batch == 0 then return M:WaypointFor(cur) end

	-- lowest action priority present → that's the current phase
	local phase = 9
	for _, s in ipairs(batch) do local p = stepAction(s); if p < phase then phase = p end end

	-- nearest target within the phase (measure from the player when on-map, else anchor)
	local px, py, pmap = U.PlayerPosition()
	local best, bestD, bestStage, bestMap
	for _, s in ipairs(batch) do
		local p, mp, x, y, stage = stepAction(s)
		if p == phase and mp and x and y then
			local rx, ry = ax, ay
			if px and pmap == mp then rx, ry = px, py end
			local d = sq(rx, ry, x, y)
			if not bestD or d < bestD then
				bestD, best, bestStage, bestMap = d, { x = x, y = y }, stage, mp
			end
		end
	end
	if best then
		return bestMap, best.x, best.y, (azone or "") .. " (" .. bestStage .. ")", bestStage
	end
	return M:WaypointFor(cur)
end

-- Where the arrow should point for a step, stepping through the quest's life:
--   not accepted        → the giver
--   accepted, working   → the objective area (where to do it)
--   objectives complete → the turn-in NPC
-- Coordinate-less headers look ahead to the next objective.
-- Returns mapID, x, y, label, stage.
function M:WaypointFor(step)
	if not step then return nil end
	if step.qid then
		if step.tmap and step.tx and step.ty and U.QuestReadyToTurnIn(step.qid) then
			return step.tmap, step.tx, step.ty, (step.zone or "") .. " (turn in)", "turnin"
		end
		if step.omap and step.ox and step.oy and U.IsQuestInLog(step.qid) then
			return step.omap, step.ox, step.oy, (step.zone or "") .. " (do)", "objective"
		end
	end
	if step.mapID and step.x and step.y then
		return step.mapID, step.x, step.y, step.zone, "giver"
	end
	local s = M:NextCoordStep()
	if s then return s.mapID, s.x, s.y, s.zone, "giver" end
end

local GREY_GAP = 6   -- a quest this many levels below you is trivial → auto-skip

-- Stable completion key: prefer the Blizzard quest id so manual completions
-- survive route-data updates (array indices shift; quest ids don't).
local function stepKey(step)
	return step.qid and ("q" .. step.qid) or step.id
end

function M:IsStepComplete(step)
	if not step then return true end
	local key = stepKey(step)
	if key and ns.char.completed[key] then return true end

	-- Reliable, locale-independent completion: the quest is flagged complete
	-- (turned in at any point). This also auto-skips quests done before install.
	if step.qid and U.IsQuestComplete(step.qid) then return true end

	-- Travel/zone headers clear themselves once you're in the target zone.
	if (step.kind == "travel" or step.kind == "note") and step.mapID then
		if U.PlayerMapID() == step.mapID then return true end
	end

	-- Auto-skip out-leveled (grey) steps — quests AND zone headers — so a
	-- mid-level character isn't parked on early content they've out-grown.
	if ns.account.skipGrey ~= false and step.band and step.band[2] then
		if U.PlayerLevel() > step.band[2] + GREY_GAP then return true end
	end

	-- Quest-title objective steps (hand-authored turn-by-turn data, no qid).
	if step.quest and not step.qid then
		local title = step.quest
		if step.kind == "accept" then
			if U.QuestInLog(title) or U.QuestObjectivesDone(title) or U.QuestTurnedIn(title) then return true end
		elseif step.kind == "turnin" then
			if U.QuestTurnedIn(title) then return true end
		else -- "quest"/"do": done when objectives complete or already handed in
			if U.QuestObjectivesDone(title) or U.QuestTurnedIn(title) then return true end
		end
	end

	local c = step.complete
	if not c then return false end
	if c.level and U.PlayerLevel() >= c.level then return true end
	if c.quest then
		if type(c.quest) == "table" then
			for _, q in ipairs(c.quest) do
				if not U.IsQuestComplete(q) then return false end
			end
			return true
		elseif U.IsQuestComplete(c.quest) then
			return true
		end
	end
	if c.coord then
		local mapID, x, y, radius = c.coord[1], c.coord[2], c.coord[3], c.coord[4] or 1.5
		local dist = U.DistanceTo(mapID, x, y)
		if dist and dist <= radius then return true end
	end
	return false
end

-- Mark current (or given) step complete and move forward.
function M:CompleteStep(index)
	index = index or ns.char.stepIndex
	local step = activeSteps[index]
	if not step then return end
	local key = stepKey(step)
	if key then ns.char.completed[key] = true end
	ns:SendMessage("ZENITH_STEP_COMPLETED", index, step)
	if index == ns.char.stepIndex then
		M:Next()
	end
end

-- Advance to the next incomplete step. When none remain the cursor parks at
-- #activeSteps+1 (a terminal "route done" state) so the poll loop stops.
function M:Next()
	local i = ns.char.stepIndex or 1
	repeat
		i = i + 1
	until i > #activeSteps or not M:IsStepComplete(activeSteps[i])
	ns.char.stepIndex = math.max(1, math.min(i, #activeSteps + 1))
	ns:SendMessage("ZENITH_STEP_CHANGED", ns.char.stepIndex, M:CurrentStep())
end

function M:Prev()
	local i = (ns.char.stepIndex or 1) - 1
	ns.char.stepIndex = U.Clamp(i, 1, math.max(1, #activeSteps))
	ns:SendMessage("ZENITH_STEP_CHANGED", ns.char.stepIndex, M:CurrentStep())
end

function M:JumpTo(index)
	ns.char.stepIndex = U.Clamp(index, 1, math.max(1, #activeSteps))
	ns:SendMessage("ZENITH_STEP_CHANGED", ns.char.stepIndex, M:CurrentStep())
end

-- If the current step is already satisfied, walk forward to the next open one
-- (may park at #activeSteps+1 if the whole route is done).
function M:AdvancePastCompleted()
	local i = ns.char.stepIndex or 1
	while i <= #activeSteps and M:IsStepComplete(activeSteps[i]) do
		i = i + 1
	end
	ns.char.stepIndex = math.max(1, math.min(i, #activeSteps + 1))
end

-- Re-check the current step against the world and auto-advance if satisfied.
function M:Poll()
	local step = M:CurrentStep()
	if step and M:IsStepComplete(step) then
		local key = stepKey(step)
		if key then ns.char.completed[key] = true end
		ns:SendMessage("ZENITH_STEP_COMPLETED", ns.char.stepIndex, step)
		M:Next()
	end
end

local AHEAD_GAP = 3   -- a step needing more than this many levels above you is "ahead"

-- First step you can actually work right now, scanning from the top: not complete,
-- not grey, and not far above your level. Used to position the cursor.
function M:FirstActionable()
	local lvl = U.PlayerLevel()
	local fallback
	for i = 1, #activeSteps do
		local s = activeSteps[i]
		if not M:IsStepComplete(s) then
			fallback = fallback or i
			local tooHigh = s.band and s.band[1] and s.band[1] > lvl + AHEAD_GAP
			if not tooHigh then return i end
		end
	end
	return fallback or (#activeSteps + 1)
end

-- Position the cursor on where you actually are. Advances forward past anything
-- finished, AND corrects backward if the cursor has run ahead of your level
-- (e.g. a stale saved position, or a high-level quest sorted into a low zone).
function M:Resync()
	local lvl = U.PlayerLevel()
	local cur = M:CurrentStep()
	local ranAhead = cur and cur.band and cur.band[1] and cur.band[1] > lvl + AHEAD_GAP
	if not cur or ranAhead or M:IsStepComplete(cur) then
		ns.char.stepIndex = M:FirstActionable()
	end
	ns:SendMessage("ZENITH_STEP_CHANGED", ns.char.stepIndex, M:CurrentStep())
end

function M:OnEnable()
	M:LoadRoute()
	-- Events that can satisfy a step.
	ns:On("QUEST_TURNED_IN", function() U.RefreshQuestLog(); M:Resync() end)
	ns:On("QUEST_LOG_UPDATE", function() U.RefreshQuestLog(); M:Poll() end)
	ns:On("QUEST_ACCEPTED", function() U.RefreshQuestLog(); M:Poll() end)
	U.RefreshQuestLog()
	-- Level-up and zone changes re-anchor the cursor to where you actually are.
	ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.2, function() M:Resync() end) end)
	ns:On("ZONE_CHANGED_NEW_AREA", function() M:Resync() end)
	-- Quest-completion data can be empty on the first frame; resync shortly after.
	ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2.0, function() M:Resync() end) end)
	-- Coordinate arrival needs a periodic check.
	C_Timer.NewTicker(1.0, function() M:Poll() end)
end
