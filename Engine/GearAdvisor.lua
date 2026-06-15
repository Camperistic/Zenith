--[[ Engine/GearAdvisor.lua

     Surfaces the right gear targets for the player's level: the upcoming leveling
     milestone(s) while < 70, and the pre-raid BiS list at 70. Pops a reminder the
     first time you reach a milestone level.
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("GearAdvisor")
ns.GearAdvisor = M

local function gearData()
	return ns.data.gear[U.PlayerClass()]
end
M.Data = gearData

-- The milestone at-or-just-below the player's level (what to chase right now).
function M:CurrentMilestone()
	local data = gearData()
	if not data then return nil end
	local level = U.PlayerLevel()
	local best
	for _, ms in ipairs(data.milestones or {}) do
		if level <= ms.level then return ms end   -- next thing to aim for
		best = ms
	end
	return best
end

function M:IsMaxLevel() return U.PlayerLevel() >= 70 end

local notified = {}
local function check()
	local data = gearData()
	if not data then return end
	local level = U.PlayerLevel()
	for _, ms in ipairs(data.milestones or {}) do
		if level == ms.level and not notified[ms.level] then
			notified[ms.level] = true
			ns:Print("Gear check — " .. U.Gold(ms.title))
			for _, it in ipairs(ms.items or {}) do
				ns:Print("   • " .. U.Accent(it.name) .. " (" .. it.slot .. ") — " .. (it.note or ""))
			end
		end
	end
end

function M:OnEnable()
	if not gearData() then return end
	ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(1.0, check) end)
end
