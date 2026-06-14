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

-- Build the flat step list for the player's chosen route + faction.
function M:LoadRoute()
	wipe(activeSteps)
	local key = ns.char.routeKey or U.PlayerClass()
	local faction = U.PlayerFaction()
	local routes = ns.data.routes[key]
	if not routes then return end

	-- Route data is organized as { Both = {...}, Alliance = {...}, Horde = {...} }
	-- We merge the faction-appropriate chain. Most data authors a single ordered
	-- table keyed by faction; "Both" is the shared Outland spine.
	local chain = routes[faction] or routes.steps or routes.Both
	if not chain then return end

	for i, step in ipairs(chain) do
		step.id = step.id or (key .. "-" .. faction .. "-" .. i)
		activeSteps[#activeSteps + 1] = step
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
	ns:On("QUEST_TURNED_IN", function() M:Poll() end)
	ns:On("QUEST_LOG_UPDATE", function() M:Poll() end)
	ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.1, function() M:Poll() end) end)
	ns:On("ZONE_CHANGED_NEW_AREA", function() M:Poll() end)
	-- Coordinate arrival needs a periodic check.
	C_Timer.NewTicker(1.0, function() M:Poll() end)
end
