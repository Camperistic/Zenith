--[[ Modules/QuestData/Pins.lua

     The visible quest layer: pooled world-map + minimap pins for the current zone,
     from QuestData. Color/shape by type, tooltips, and a route-only ⇄ full-world ⇄
     off filter so density never becomes clutter. Pins are POOLED (acquire/release,
     never created in a loop) and redrawn on zone/quest changes (debounced).
]]
local ADDON, ns = ...
local Bus, State, C = ns.Bus, ns.State, ns.compat
local HBDP = LibStub("HereBeDragons-Pins-2.0", true)

local Pins = {}
ns.Pins = Pins

local RACE_BIT = { Human=1, Orc=2, Dwarf=4, NightElf=8, Scourge=16, Tauren=32, Gnome=64, Troll=128, BloodElf=512, Draenei=1024 }
local function raceOK(mask)
	if not mask or mask == 0 then return true end
	local b = RACE_BIT[State:Race() or ""] or 0
	return b == 0 or math.floor(mask / b) % 2 == 1
end

local MAX_PINS = 120
local ICON = {
	giver  = "Interface\\GossipFrame\\AvailableQuestIcon",
	turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
	obj    = "Interface\\Minimap\\Tracking\\None",
}

-- ── pin pool ──────────────────────────────────────────────────────────────────
local pool, used = {}, {}
local function acquire()
	local p = table.remove(pool)
	if not p then
		p = CreateFrame("Button", nil, UIParent)
		p:SetSize(14, 14)
		p.tex = p:CreateTexture(nil, "OVERLAY"); p.tex:SetAllPoints()
		p:SetScript("OnEnter", function(self)
			if not self.info then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.info.name or "?")
			if self.info.lvl then GameTooltip:AddLine("Level " .. self.info.lvl, 1, 1, 1) end
			GameTooltip:AddLine(self.info.kind, 0.6, 0.8, 0.6)
			GameTooltip:Show()
		end)
		p:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	p:Show()
	used[#used + 1] = p
	return p
end

function Pins:Clear()
	if HBDP then HBDP:RemoveAllWorldMapIcons(self); HBDP:RemoveAllMinimapIcons(self) end
	for i = #used, 1, -1 do local p = used[i]; p:Hide(); p.info = nil; pool[#pool + 1] = p; used[i] = nil end
end

local function addPin(mapID, x, y, kind, info)
	if not HBDP then return end
	local p = acquire()
	p.tex:SetTexture(ICON[kind] or ICON.giver)
	p.info = info; p.info.kind = kind
	HBDP:AddWorldMapIconMap(Pins, p, mapID, x / 100, y / 100, 3)   -- 3 = show on continent/world
	-- minimap pin reuses the same frame is not allowed; a second light frame:
	local mp = acquire()
	mp.tex:SetTexture(ICON[kind] or ICON.giver); mp.info = info; mp.info.kind = kind
	HBDP:AddMinimapIconMap(Pins, mp, mapID, x / 100, y / 100, true, true)
end

-- ── draw ──────────────────────────────────────────────────────────────────────
function Pins:Redraw()
	self:Clear()
	local mode = ns.db.profile.pinMode or "full"
	if mode == "off" or not HBDP or not ns.QuestData then return end
	local mapID = State:MapID(); if not mapID then return end
	local quests = ns.QuestData:QuestsForMap(mapID); if not quests then return end

	-- route-only: restrict to quest ids in the active route window
	local allow
	if mode == "route" and ns.Route then
		allow = {}
		for i = 1, ns.Route:Count() do local s = ns.Route:StepAt(i); if s and s.qid then allow[s.qid] = true end end
	end

	local lvl, n = State:Level(), 0
	for qid, q in pairs(quests) do
		if n >= MAX_PINS then break end
		local done = C.IsQuestFlaggedCompleted and C.IsQuestFlaggedCompleted(qid)
		local grey = q.lvl and lvl > q.lvl + 6
		local tooHigh = (q.req or q.lvl or 0) > lvl + 4
		if not done and not grey and not tooHigh and raceOK(q.races) and (not allow or allow[qid]) then
			local inLog = C.GetLogIndexForQuestID and C.GetLogIndexForQuestID(qid)
			if inLog and q.tm and q.tx then
				addPin(q.tm, q.tx, q.ty, "turnin", { name = q.name, lvl = q.lvl })
			elseif not inLog and q.gm and q.gx then
				addPin(q.gm, q.gx, q.gy, "giver", { name = q.name, lvl = q.lvl })
			end
			n = n + 1
		end
	end
end

-- debounce quest-log spam
local pending
local function debouncedRedraw()
	if pending then return end
	pending = true
	C_Timer.After(0.4, function() pending = nil; Pins:Redraw() end)
end

ns.Registry:Add({
	name = "Pins",
	IsFeatureEnabled = function() return HBDP ~= nil and ns:HasDataPack() end,
	OnEnable = function()
		Bus:On("ZONE_CHANGED", function() Pins:Redraw() end)
		Bus:On("QUESTLOG_CHANGED", debouncedRedraw)
		Bus:On("ROUTE_LOADED", function() Pins:Redraw() end)
		Bus:On("SLASH", function(msg)
			if msg == "pins" then
				local m = ns.db.profile.pinMode or "full"
				ns.db.profile.pinMode = (m == "full") and "route" or (m == "route") and "off" or "full"
				ns:Print("map pins: " .. ns.db.profile.pinMode)
				Pins:Redraw()
			end
		end)
		Pins:Redraw()
	end,
})
