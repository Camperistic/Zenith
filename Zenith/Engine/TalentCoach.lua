--[[ Engine/TalentCoach.lua

     Real-time "what do I put my next talent point in?" advisor.

     Counts how many points you've actually spent (sum of ranks across all tabs),
     then recommends order[spent + 1] from the spec's leveling path. Independent of
     locale (it counts points; it doesn't string-match talents), so it still gives
     sane guidance even if you deviated from the plan.
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("TalentCoach")
ns.TalentCoach = M

local function specData()
	local classData = ns.data.talents[U.PlayerClass()]
	if not classData then return nil end
	return classData[classData.default or "BM"]
end
M.SpecData = specData

-- Total talent points actually spent (across all three tabs).
function M:SpentPoints()
	local total = 0
	local tabs = GetNumTalentTabs and GetNumTalentTabs() or 0
	for tab = 1, tabs do
		local n = GetNumTalents(tab)
		for i = 1, n do
			local _, _, _, _, rank = GetTalentInfo(tab, i)
			total = total + (rank or 0)
		end
	end
	return total
end

-- Points earned for the current level (first point at L10).
function M:EarnedPoints()
	return math.max(0, U.PlayerLevel() - 9)
end

function M:UnspentPoints()
	return math.max(0, self:EarnedPoints() - self:SpentPoints())
end

-- The next 1–N recommended allocations from the leveling path.
function M:NextRecommendations(count)
	local data = specData()
	if not data then return {} end
	local spent = self:SpentPoints()
	local out = {}
	for i = spent + 1, math.min(#data.order, spent + (count or 1)) do
		out[#out + 1] = data.order[i]
	end
	return out
end

function M:NextRecommendation()
	return self:NextRecommendations(1)[1]
end

-- Fired when points may be available.
local function check()
	if not ns.account.showTalentPop then return end
	local unspent = M:UnspentPoints()
	if unspent > 0 then
		local rec = M:NextRecommendation()
		if rec then
			ns:Print(string.format("|cffffd100%d talent point%s available!|r Next: %s — %s",
				unspent, unspent > 1 and "s" or "",
				U.Accent(rec.talent),
				rec.note or (rec.tree .. " tree")))
			if rec.spike then
				UIErrorsFrame:AddMessage("Zenith: " .. rec.talent .. " — POWER SPIKE!", 0.45, 0.86, 0.27, 1, 3)
			end
		end
		ns:SendMessage("ZENITH_TALENT_AVAILABLE", unspent, rec)
	end
end

function M:OnEnable()
	if not specData() then return end   -- no data for this class yet
	ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, check) end)
	ns:On("CHARACTER_POINTS_CHANGED", function() C_Timer.After(0.2, check) end)
	ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2.0, check) end)
end
