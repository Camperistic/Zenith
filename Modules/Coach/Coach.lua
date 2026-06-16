--[[ Modules/Coach/Coach.lua

     The class-coaching brain (display-only — no automation, ever).
       • Talents — counts points actually spent, recommends order[spent+1] live.
       • Rotation — evaluates a per-spec priority list on a throttle and shows the
         next recommended ability on a compact widget (the net-new live pillar).
       • Gear — per-spec stat priority + advice (tab text for now).

     Class data registers via ns.RegisterClass(class, data). Pure data per spec.
]]
local ADDON, ns = ...
local Bus, State, Theme, C = ns.Bus, ns.State, ns.Theme, ns.compat

local Coach = {}
ns.Coach = Coach
local classes = {}

function ns.RegisterClass(class, data) classes[class] = data end
local function data() return classes[State:Class() or ""] end

-- ── talents ───────────────────────────────────────────────────────────────────
function Coach:SpentPoints()
	local total, tabs = 0, (GetNumTalentTabs and GetNumTalentTabs()) or 0
	for tab = 1, tabs do
		for i = 1, (GetNumTalents and GetNumTalents(tab) or 0) do
			local _, _, _, _, rank = GetTalentInfo(tab, i)
			total = total + (rank or 0)
		end
	end
	return total
end
function Coach:NextTalent()
	local d = data(); if not (d and d.talents) then return nil end
	return d.talents[self:SpentPoints() + 1]
end

-- ── rotation evaluation ─────────────────────────────────────────────────────────
local function ready(entry, ctx)
	if ctx.level < (entry.minLevel or 1) then return false end
	if entry.cond and not entry.cond(ctx) then return false end
	local name = entry.spell
	if C.IsUsableSpell then
		local usable, noMana = C.IsUsableSpell(name)
		if usable == nil and name ~= "Auto Shot" then return false end
		if usable == false and noMana then return false end
	end
	if C.GetSpellCooldown then
		local start, dur = C.GetSpellCooldown(name)
		if start and dur and dur > 1.6 and (start + dur - GetTime()) > 0.4 then return false end
	end
	return true
end

function Coach:Suggest()
	local d = data(); if not (d and d.rotation and d.rotation.priority) then return nil end
	if not (UnitExists("target") and UnitCanAttack("player", "target")) then return nil end
	local mana = UnitPowerMax("player", 0)
	local ctx = {
		level = State:Level(),
		mana = (mana > 0) and (UnitPower("player", 0) / mana) or 1,
		targetHP = (UnitHealthMax("target") > 0) and (UnitHealth("target") / UnitHealthMax("target")) or 1,
		petActive = UnitExists("pet") and not UnitIsDead("pet"),
	}
	for _, e in ipairs(d.rotation.priority) do if ready(e, ctx) then return e end end
end

-- ── rotation widget ──────────────────────────────────────────────────────────────
local function buildWidget()
	local f = CreateFrame("Frame", "ZenithRotation", UIParent)
	f:SetSize(210, 46); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(s) if not ns.db.profile.locked then s:StartMoving() end end)
	f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); local p, _, rp, x, y = s:GetPoint(); ns.db.profile.rotationPoint = { p, rp, x, y } end)
	local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(Theme:C("panel"))
	ns.W.Border(f, 0.4, 1)
	f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(38, 38); f.icon:SetPoint("LEFT", 4, 0); f.icon:SetTexCoord(.07, .93, .07, .93)
	f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -2); f.name:SetPoint("RIGHT", -4, 0); f.name:SetJustifyH("LEFT")
	f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.note:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2); f.note:SetPoint("RIGHT", -4, 0); f.note:SetJustifyH("LEFT"); f.note:SetTextColor(Theme:RGB("dim"))
	local pt = ns.db.profile.rotationPoint
	if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("BOTTOM", 0, 180) end
	f:SetScript("OnUpdate", function(self, e)
		self.t = (self.t or 0) + e; if self.t < 0.12 then return end; self.t = 0
		if ns.db.profile.showRotation == false then self:Hide(); return end
		local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
		local s = inCombat and Coach:Suggest() or nil
		if not s then self:Hide(); return end
		self:Show()
		self.icon:SetTexture((C.GetSpellTexture and C.GetSpellTexture(s.spell)) or 134400)
		self.name:SetText(Theme:Color("accent", s.spell)); self.note:SetText(s.note or "")
	end)
	return f
end

-- ── tabs (Talents / Gear) ─────────────────────────────────────────────────────────
local function textPane(pane, refresh)
	local sf = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT"); sf:SetPoint("BOTTOMRIGHT", -26, 0)
	local content = CreateFrame("Frame", nil, sf); content:SetSize(10, 10); sf:SetScrollChild(content)
	local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT"); fs:SetWidth((pane:GetWidth() or 330) - 30); fs:SetJustifyH("LEFT"); fs:SetSpacing(2)
	pane.Refresh = function() fs:SetText(refresh() or ""); content:SetHeight((fs:GetStringHeight() or 10) + 12) end
end

local function talentsText()
	local d = data(); if not (d and d.talents) then return Theme:Color("dim", "No talent path for this class yet.") end
	local spent, out = Coach:SpentPoints(), {}
	out[#out+1] = Theme:Color("accent", d.specName or "Leveling spec") .. "  (" .. (d.finalSpec or "") .. ")  ·  " .. spent .. " spent"
	local nxt = d.talents[spent + 1]
	if nxt then out[#out+1] = Theme:Color("gold", "▶ Next point: ") .. Theme:Color("accent", nxt.talent) .. (nxt.note and ("  " .. Theme:Color("dim", nxt.note)) or "") end
	out[#out+1] = ""
	for i, e in ipairs(d.talents) do
		local mark = (i <= spent and "|cff40c040✔|r ") or (i == spent + 1 and Theme:Color("gold", "▶ ") or "   ")
		out[#out+1] = mark .. string.format("L%d %s%s", e.level or i + 9, e.talent, e.spike and Theme:Color("gold", " ★") or "")
	end
	return table.concat(out, "\n")
end

local function gearText()
	local d = data(); if not (d and d.gear) then return Theme:Color("dim", "No gear guidance for this class yet.") end
	local out = { Theme:Color("accent", "Stat priority: ") .. (d.gear.statPriority or "?") }
	for _, n in ipairs(d.gear.notes or {}) do out[#out+1] = "• " .. n end
	return table.concat(out, "\n")
end

ns.Registry:Add({
	name = "Coach",
	OnEnable = function()
		buildWidget()
		Bus:On("LEVEL_CHANGED", function()
			local n = Coach:NextTalent()
			if n and ns.db.profile.showTalentPop ~= false then
				ns:Print(Theme:Color("gold", "Talent point!") .. " Next: " .. Theme:Color("accent", n.talent) .. " — " .. (n.note or ""))
			end
			if ns.UI then ns.UI:RefreshActive() end
		end)
		if ns.UI then
			ns.UI:AddTab("Talents", function(p) textPane(p, talentsText) end)
			ns.UI:AddTab("Gear", function(p) textPane(p, gearText) end)
		end
	end,
})
