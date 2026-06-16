--[[ Modules/Route/Arrow.lua

     Native directional arrow (no TomTom required). A single movable UIParent frame,
     throttled OnUpdate, pointing from the player to the route's current waypoint via
     HereBeDragons world coordinates + GetPlayerFacing. Re-targets on route/quest
     changes and ~1/sec so the batch "nearest" stays fresh as you move.
]]
local ADDON, ns = ...
local Bus, State = ns.Bus, ns.State
local HBD = LibStub("HereBeDragons-2.0", true)

local Arrow = {}
ns.Arrow = Arrow

local frame, target

local function build()
	local f = CreateFrame("Frame", "ZenithArrow", UIParent)
	f:SetSize(56, 70); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetFrameStrata("HIGH")
	f:SetScript("OnDragStart", function(self) if not ns.db.profile.locked then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.db.profile.arrowPoint = { p, rp, x, y }
	end)
	f.tex = f:CreateTexture(nil, "OVERLAY")
	f.tex:SetSize(48, 48); f.tex:SetPoint("TOP"); f.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
	f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.label:SetPoint("TOP", f.tex, "BOTTOM", 0, -2)
	f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.dist:SetPoint("TOP", f.label, "BOTTOM", 0, -1)

	local pt = ns.db.profile.arrowPoint
	if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("CENTER", 0, 160) end

	f:SetScript("OnUpdate", function(self, e)
		self.rt = (self.rt or 0) + e
		if self.rt > 1.0 then self.rt = 0; Arrow:Retarget() end
		self.t = (self.t or 0) + e
		if self.t < 0.04 then return end
		self.t = 0
		if not target or not HBD then return end
		local pX, pY, pInst = HBD:GetPlayerWorldPosition()
		local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(target.x / 100, target.y / 100, target.mapID)
		if not (pX and tX) or pInst ~= tInst then
			self.tex:SetRotation(0); self.tex:SetVertexColor(0.7, 0.7, 0.7)
			self.dist:SetText("→ " .. (target.label or ""))
			self.label:SetText(""); return
		end
		local angle, dist = HBD:GetWorldVector(pInst, pX, pY, tX, tY)
		self.tex:SetRotation((angle or 0) - (GetPlayerFacing() or 0))
		if dist and dist < 12 then self.tex:SetVertexColor(0.45, 0.86, 0.27)
		else self.tex:SetVertexColor(1, 0.82, 0) end
		self.dist:SetText(string.format("%d yd", math.floor(dist or 0)))
		self.label:SetText(target.label or "")
	end)
	return f
end

function Arrow:Retarget()
	if not ns.Route then return end
	local mapID, x, y, label = ns.Route:NextWaypoint()
	local show = mapID and x and y and ns.db.profile.showArrow ~= false
	if show then target = { mapID = mapID, x = x, y = y, label = label }
	else target = nil end
	if frame then frame:SetShown(show and true or false) end
end

ns.Registry:Add({
	name = "Arrow",
	IsFeatureEnabled = function() return ns.Route ~= nil and HBD ~= nil end,
	OnEnable = function()
		frame = build(); frame:Hide()
		Bus:On("ROUTE_CHANGED", function() Arrow:Retarget() end)
		Bus:On("QUESTLOG_CHANGED", function() Arrow:Retarget() end)
		Bus:On("SLASH", function(msg)
			if msg == "arrow" then ns.db.profile.showArrow = not (ns.db.profile.showArrow ~= false); Arrow:Retarget() end
		end)
		Arrow:Retarget()
	end,
})
