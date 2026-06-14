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

-- Build the flat step list: race-specific 1–~12 intro + shared faction spine.
function M:LoadRoute()
	wipe(activeSteps)
	local faction = U.PlayerFaction()
	local race                                        -- token: "Human","Orc","Scourge"...
	if UnitRace then local _; _, race = UnitRace("player") end

	-- Preferred: the comprehensive quest route generated from the Questie DB,
	-- filtered to quests available to this character's race. Falls back to the
	-- hand-authored race-start + zone spine if the generated data isn't present.
	local questRoute = ns.data.questRoute and ns.data.questRoute[faction]
	if questRoute then
		local prevTravel = false
		for i, step in ipairs(questRoute) do
			if U.RaceAllowed(step.races) then
				if step.kind == "travel" and prevTravel then
					-- collapse consecutive zone headers (race filtered the zone empty)
				else
					step.id = step.id or ("q-" .. faction .. "-" .. i)
					activeSteps[#activeSteps + 1] = step
					prevTravel = (step.kind == "travel")
				end
			end
		end
		ns.char.stepIndex = U.Clamp(ns.char.stepIndex or 1, 1, math.max(1, #activeSteps))
		M:AdvancePastCompleted()
		ns:SendMessage("ZENITH_ROUTE_LOADED")
		ns:SendMessage("ZENITH_STEP_CHANGED", ns.char.stepIndex, M:CurrentStep())
		return
	end

	local spine = ns.data.route and ns.data.route[faction]
	if not spine then return end

	local function add(list, tag)
		if not list then return end
		for i, step in ipairs(list) do
			step.id = step.id or (tag .. "-" .. i)
			activeSteps[#activeSteps + 1] = step
		end
	end
	-- Turn-by-turn detailed early game (race-specific) if we have it; otherwise the
	-- zone-level race intro. Either way, append the faction spine beyond the level
	-- the head already covers.
	local coverTo = 0
	local detailed = ns.data.detailed and ns.data.detailed[race]
	if detailed and detailed.steps then
		add(detailed.steps, "det-" .. (race or "x"))
		coverTo = detailed.coversTo or 0
	else
		add(ns.data.starts and ns.data.starts[race], "start-" .. (race or "x"))
	end
	for i, step in ipairs(spine) do
		local skip = coverTo > 0 and step.band and step.band[2] and step.band[2] <= coverTo
		if not skip then
			step.id = step.id or ("spine-" .. faction .. "-" .. i)
			activeSteps[#activeSteps + 1] = step
		end
	end

	ns.char.stepIndex = U.Clamp(ns.char.stepIndex or 1, 1, math.max(1, #activeSteps))
	-- Skip past anything already completed so a returning player resumes cleanly.
	M:AdvancePastCompleted()
	ns:SendMessage("ZENITH_ROUTE_LOADED")
	ns:SendMessage("ZENITH_STEP_CHANGED", ns.char.stepIndex, M:CurrentStep())
end

function M:Steps() return activeSteps end
function M:Count() return #activeSteps end

function M:StepAt(i) return activeSteps[i] end

function M:CurrentStep()
	return activeSteps[ns.char.stepIndex or 1]
end

function M:IsStepComplete(step)
	if not step then return true end
	if ns.char.completed[step.id] then return true end

	-- Quest-title objective steps (turn-by-turn data).
	if step.quest then
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
	ns.char.completed[step.id] = true
	ns:SendMessage("ZENITH_STEP_COMPLETED", index, step)
	if index == ns.char.stepIndex then
		M:Next()
	end
end

function M:Next()
	local i = ns.char.stepIndex or 1
	repeat
		i = i + 1
	until i > #activeSteps or not M:IsStepComplete(activeSteps[i])
	ns.char.stepIndex = U.Clamp(i, 1, math.max(1, #activeSteps))
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

-- If the current step is already satisfied, walk forward to the next open one.
function M:AdvancePastCompleted()
	local i = ns.char.stepIndex or 1
	while i <= #activeSteps and M:IsStepComplete(activeSteps[i]) do
		i = i + 1
	end
	ns.char.stepIndex = U.Clamp(i, 1, math.max(1, #activeSteps))
end

-- Re-check the current step against the world and auto-advance if satisfied.
function M:Poll()
	local step = M:CurrentStep()
	if step and M:IsStepComplete(step) then
		ns.char.completed[step.id] = true
		ns:SendMessage("ZENITH_STEP_COMPLETED", ns.char.stepIndex, step)
		M:Next()
	end
end

function M:OnEnable()
	M:LoadRoute()
	-- Events that can satisfy a step.
	ns:On("QUEST_TURNED_IN", function() U.RefreshQuestLog(); M:Poll() end)
	ns:On("QUEST_LOG_UPDATE", function() U.RefreshQuestLog(); M:Poll() end)
	ns:On("QUEST_ACCEPTED", function() U.RefreshQuestLog(); M:Poll() end)
	U.RefreshQuestLog()
	ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.1, function() M:Poll() end) end)
	ns:On("ZONE_CHANGED_NEW_AREA", function() M:Poll() end)
	-- Coordinate arrival needs a periodic check.
	C_Timer.NewTicker(1.0, function() M:Poll() end)
end
