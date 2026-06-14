--[[ Engine/RotationHelper.lua

     A live "next best shot" suggestion. Walks the spec's priority list top-down
     each update and shows the first ability that is learned, off cooldown, and
     condition-satisfied. A min-max DPS nudge, not a full bot.

     Renders a small icon + name frame near the bottom-centre of the screen,
     visible in combat with a target. Move it by dragging when unlocked.
]]
local ADDON_NAME, ns = ...
local U = ns.U
local M = ns:NewModule("RotationHelper")

local frame
local lastRangedCrit = 0      -- GetTime() of last player ranged crit (for Kill Command)

local function rotationData()
	local cls = ns.data.rotations[U.PlayerClass()]
	if not cls then return nil end
	return cls[cls.default or "BM"]
end

-- Build the decision context once per update.
local function context()
	local powerType = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
	local mana = UnitPowerMax("player", powerType)
	mana = (mana > 0) and (UnitPower("player", powerType) / mana) or 1
	local thp = UnitHealthMax("target")
	thp = (thp > 0) and (UnitHealth("target") / thp) or 1
	return {
		level       = U.PlayerLevel(),
		mana        = mana,
		petActive   = UnitExists("pet") and not UnitIsDead("pet"),
		lastCrit    = (GetTime() - lastRangedCrit) < 5,
		targetExists= UnitExists("target") and UnitCanAttack("player", "target"),
		targetHP    = thp,
	}
end

-- Is this priority entry castable right now?
local function isReady(entry, ctx)
	if ctx.level < (entry.minLevel or 1) then return false end
	if entry.cond and not entry.cond(ctx) then return false end
	local name = entry.spell
	-- Learned & resource check (nil = not learned).
	local usable, noMana = IsUsableSpell(name)
	if usable == nil then
		-- Some core actions (Auto Shot) report oddly; allow level-gated fallthrough.
		if name ~= "Auto Shot" then return false end
	elseif not usable and noMana then
		return false
	end
	-- Cooldown check (ignore the global cooldown).
	local start, duration = GetSpellCooldown(name)
	if start and duration and duration > 1.6 then
		if (start + duration - GetTime()) > 0.4 then return false end
	end
	return true
end

function M:Suggest()
	local data = rotationData()
	if not data then return nil end
	local ctx = context()
	if not ctx.targetExists then return nil end
	local list = data.priority
	-- Multi-target? (best-effort: nameplates aren't reliably countable, so single
	-- target priority is the default; AoE list is documented in the Gear/Help tab.)
	for _, entry in ipairs(list) do
		if isReady(entry, ctx) then
			return entry
		end
	end
	return nil
end

local function buildFrame()
	local f = CreateFrame("Frame", "ZenithRotation", UIParent)
	f:SetSize(220, 48)
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.account.locked then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.account.rotationPoint = { p, rp, x, y }
	end)

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.05, 0.82)

	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(40, 40); f.icon:SetPoint("LEFT", 4, 0)
	f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	f.iconBorder = f:CreateTexture(nil, "OVERLAY")
	f.iconBorder:SetPoint("TOPLEFT", f.icon, -2, 2)
	f.iconBorder:SetPoint("BOTTOMRIGHT", f.icon, 2, -2)
	f.iconBorder:SetColorTexture(0.45, 0.86, 0.27, 0.35)

	f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -2)
	f.name:SetPoint("RIGHT", -4, 0); f.name:SetJustifyH("LEFT")

	f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.note:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2)
	f.note:SetPoint("RIGHT", -4, 0); f.note:SetJustifyH("LEFT")
	f.note:SetTextColor(0.8, 0.8, 0.8)

	local pt = ns.account.rotationPoint
	if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
	else f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180) end

	f:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t or 0) + elapsed
		if self.t < 0.1 then return end
		self.t = 0
		if not ns.account.showRotation then self:Hide(); return end
		local show = InCombatLockdown() or UnitAffectingCombat("player")
		local entry = show and M:Suggest() or nil
		if not entry then self:Hide(); return end
		self:Show()
		self.icon:SetTexture(GetSpellTexture(entry.spell) or 134400)
		self.name:SetText(U.Accent(entry.spell))
		self.note:SetText(entry.note or "")
	end)

	return f
end

function M:OnEnable()
	if not rotationData() then return end
	frame = buildFrame()
	frame:Hide()
	-- Track player ranged crits to enable Kill Command suggestions.
	ns:On("COMBAT_LOG_EVENT_UNFILTERED", function()
		local info = { CombatLogGetCurrentEventInfo() }
		local sub, srcGUID = info[2], info[4]
		if srcGUID ~= UnitGUID("player") then return end
		-- SPELL_DAMAGE / RANGE_DAMAGE payload: ...amount(15), overkill, school,
		-- resisted, blocked, absorbed, critical(21).
		if (sub == "RANGE_DAMAGE" or sub == "SPELL_DAMAGE") and info[21] then
			lastRangedCrit = GetTime()
		end
	end)
end
