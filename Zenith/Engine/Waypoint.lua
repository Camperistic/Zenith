--[[ Engine/Waypoint.lua

     A lightweight directional arrow (TomTom-style) that points toward the current
     step's coordinate and shows the distance. Pure FrameXML, no external libs.

     Arrow math (map space: x east, y south; GetPlayerFacing: 0=N, CCW):
       bearing  β = atan2(-dx, -dy)        -- CCW from north toward west
       rotation R = β - GetPlayerFacing()   -- SetRotation: +ve = counter-clockwise
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("Waypoint")

local arrow                     -- the frame
local target                    -- { mapID, x, y, label }

function M:SetTarget(mapID, x, y, label)
	-- No-op if unchanged (avoids TomTom add/remove churn on every QUEST_LOG_UPDATE).
	if target and mapID and target.mapID == mapID and target.x == x and target.y == y then return end
	if not (mapID and x and y) then
		if not target then return end
		target = nil
	else
		target = { mapID = mapID, x = x, y = y, label = label }
	end
	if arrow then arrow:SetShown(target ~= nil and ns.account.showArrow) end
	M:UpdateTomTom()
end

-- Hand the waypoint to TomTom if the player has it (better world/minimap pins).
function M:UpdateTomTom()
	local TT = _G.TomTom
	if not (TT and TT.AddWaypoint) then return end
	if M._ttuid and TT.RemoveWaypoint then pcall(TT.RemoveWaypoint, TT, M._ttuid) end
	M._ttuid = nil
	if target and ns.account.useTomTom ~= false then
		local ok, uid = pcall(TT.AddWaypoint, TT, target.mapID, target.x / 100, target.y / 100,
			{ title = "Zenith: " .. (target.label or "step"), persistent = false, minimap = true, world = true })
		if ok then M._ttuid = uid end
	end
end

function M:ClearTarget() M:SetTarget(nil) end

-- Point the arrow at the right place for a step: giver, or the turn-in NPC once
-- objectives are complete, or the next objective if this step is a zone header.
function M:SyncFromStep(step)
	local se = ns:GetModule("StepEngine")
	local mapID, x, y, label = se and se.WaypointFor and se:WaypointFor(step)
	if mapID and x and y then
		M:SetTarget(mapID, x, y, label)
	else
		M:ClearTarget()
	end
end

local function buildArrow()
	local f = CreateFrame("Frame", "ZenithArrow", UIParent)
	f:SetSize(56, 70)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.account.locked then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.account.arrowPoint = { p, rp, x, y }
	end)

	local tex = f:CreateTexture(nil, "OVERLAY")
	tex:SetSize(48, 48)
	tex:SetPoint("TOP")
	tex:SetTexture("Interface\\Minimap\\MinimapArrow")  -- always present
	f.tex = tex

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOP", tex, "BOTTOM", 0, -2)
	local c = ns.COLORS.accent
	label:SetTextColor(c[1], c[2], c[3])
	f.label = label

	local dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dist:SetPoint("TOP", label, "BOTTOM", 0, -1)
	f.dist = dist

	-- Position
	local pt = ns.account.arrowPoint
	if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
	else f:SetPoint("CENTER", UIParent, "CENTER", 0, 150) end

	f:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t or 0) + elapsed
		if self.t < 0.03 then return end   -- ~30fps is plenty
		self.t = 0
		if not target then return end

		local px, py, mapID = U.PlayerPosition()
		if not px or mapID ~= target.mapID then
			-- Different map: show a muted "travel to zone" hint instead of a heading.
			self.tex:SetVertexColor(0.7, 0.7, 0.7)
			self.tex:SetRotation(0)
			self.dist:SetText(U.Dim("→ " .. U.MapName(target.mapID)))
			self.label:SetText(target.label or "")
			return
		end

		local dx, dy = target.x - px, target.y - py
		local facing = GetPlayerFacing and GetPlayerFacing() or 0
		local bearing = math.atan2(-dx, -dy)
		self.tex:SetRotation(bearing - facing)

		local d = math.sqrt(dx * dx + dy * dy)
		-- green when roughly on-heading & close, amber otherwise
		if d < 3 then self.tex:SetVertexColor(0.45, 0.86, 0.27)
		else self.tex:SetVertexColor(1, 0.82, 0) end
		self.dist:SetText(string.format("%d yd*", math.floor(d * 10)))   -- map% ≈ tens of yards
		self.label:SetText(target.label or "")
	end)

	return f
end

function M:Refresh()
	if not arrow then return end
	arrow:SetShown(target ~= nil and ns.account.showArrow)
end

function M:OnEnable()
	arrow = buildArrow()
	arrow:Hide()
	ns:RegisterMessage("ZENITH_STEP_CHANGED", function(_, _, step) M:SyncFromStep(step) end)
	-- Re-evaluate when quest objectives change (arrow flips giver → turn-in).
	local se = ns:GetModule("StepEngine")
	ns:On("QUEST_LOG_UPDATE", function() if se then M:SyncFromStep(se:CurrentStep()) end end)
	if se then M:SyncFromStep(se:CurrentStep()) end
end
