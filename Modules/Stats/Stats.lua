--[[ Modules/Stats/Stats.lua

     Leveling tracker: active played-time per level, total, and a live ETA-to-ding
     from the current XP rate. Adds a Stats tab to the window. Stored per character
     (ns.db.char.tracker). Active seconds = persisted total + this session's elapsed.
]]
local ADDON, ns = ...
local Bus, State, Theme = ns.Bus, ns.State, ns.Theme

local Stats = {}
ns.Stats = Stats
local loginTime = 0

local function t() return ns.db.char.tracker end

function Stats:ActiveSeconds() return (t().activeTotal or 0) + (GetTime() - loginTime) end

function Stats:LevelDuration(lvl)
	local s = t().splits
	if s[lvl] and s[lvl + 1] then return s[lvl + 1] - s[lvl] end
	if s[lvl] and lvl == State:Level() then return self:ActiveSeconds() - s[lvl] end
end

function Stats:Format(sec)
	sec = math.floor(sec or 0)
	local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
	if h > 0 then return string.format("%dh %02dm", h, m) end
	return string.format("%dm %02ds", m, sec % 60)
end

function Stats:ETA()
	if State:Level() >= 70 then return nil end
	local maxXP = UnitXPMax("player") or 0; if maxXP <= 0 then return nil end
	local frac = (UnitXP("player") or 0) / maxXP
	local el = self:LevelDuration(State:Level())
	if not el or el < 30 or frac <= 0.02 then return nil end
	return (1 - frac) / (frac / el)
end

local function buildPane(pane)
	local sf = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT"); sf:SetPoint("BOTTOMRIGHT", -26, 0)
	local content = CreateFrame("Frame", nil, sf); content:SetSize(10, 10); sf:SetScrollChild(content)
	local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT"); fs:SetWidth((pane:GetWidth() or 330) - 30); fs:SetJustifyH("LEFT"); fs:SetSpacing(2)

	function pane:Refresh()
		local lvl, out = State:Level(), {}
		out[#out+1] = Theme:Color("accent", "Total played (active): ") .. Stats:Format(Stats:ActiveSeconds())
		out[#out+1] = Theme:Color("accent", "Level: ") .. lvl
		local cur = Stats:LevelDuration(lvl); if cur then out[#out+1] = Theme:Color("accent", "This level: ") .. Stats:Format(cur) end
		local eta = Stats:ETA(); if eta then out[#out+1] = Theme:Color("accent", "ETA to ding: ") .. Theme:Color("gold", "~" .. Stats:Format(eta)) end
		out[#out+1] = "\n" .. Theme:Color("gold", "LEVEL SPLITS")
		local any = false
		for L = math.max(2, lvl - 11), lvl do
			local d = Stats:LevelDuration(L - 1)
			if d then any = true; out[#out+1] = string.format("L%d → %d   %s", L - 1, L, Stats:Format(d)) end
		end
		if not any then out[#out+1] = Theme:Color("dim", "Level up while Zenith is loaded to record splits.") end
		fs:SetText(table.concat(out, "\n")); content:SetHeight((fs:GetStringHeight() or 10) + 12)
	end
end

ns.Registry:Add({
	name = "Stats",
	OnEnable = function()
		loginTime = GetTime()
		if not t().splits[State:Level()] then t().splits[State:Level()] = Stats:ActiveSeconds() end
		Bus:On("LEVEL_CHANGED", function(lvl) t().splits[lvl] = Stats:ActiveSeconds(); if ns.UI then ns.UI:RefreshActive() end end)
		local f = CreateFrame("Frame"); f:RegisterEvent("PLAYER_LOGOUT")
		f:SetScript("OnEvent", function() t().activeTotal = Stats:ActiveSeconds() end)
		if ns.UI then ns.UI:AddTab("Stats", buildPane) end
	end,
})
