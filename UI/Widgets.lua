--[[ UI/Widgets.lua : shared visual helpers — thin borders, flat themed buttons,
     and per-step icons. Keeps the look consistent and a notch above flat panels. ]]
local ADDON_NAME, ns = ...
local AC = ns.COLORS.accent
local W = {}
ns.W = W

-- A thin border drawn with four edge textures (works on every client; matches theme).
function W.Border(frame, r, g, b, a, t)
	t = t or 1
	r, g, b, a = r or AC[1], g or AC[2], b or AC[3], a or 0.8
	local function edge()
		local tex = frame:CreateTexture(nil, "BORDER")
		tex:SetColorTexture(r, g, b, a)
		return tex
	end
	local top = edge();   top:SetPoint("TOPLEFT");    top:SetPoint("TOPRIGHT");    top:SetHeight(t)
	local bot = edge();   bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(t)
	local left = edge();  left:SetPoint("TOPLEFT");   left:SetPoint("BOTTOMLEFT"); left:SetWidth(t)
	local right = edge(); right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(t)
end

-- Flat, dark, accent-bordered button with a hover glow (replaces the gold UIPanel button).
function W.Button(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(); bg:SetColorTexture(0.11, 0.13, 0.11, 0.95)
	W.Border(b, AC[1], AC[2], AC[3], 0.45, 1)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("CENTER"); fs:SetText(text); fs:SetTextColor(AC[1], AC[2], AC[3])
	b.label = fs
	b:SetScript("OnEnter", function() bg:SetColorTexture(AC[1] * 0.28, AC[2] * 0.28, AC[3] * 0.28, 0.95) end)
	b:SetScript("OnLeave", function() bg:SetColorTexture(0.11, 0.13, 0.11, 0.95) end)
	b.SetText = function(self, t) self.label:SetText(t) end
	return b
end

-- Per-step-kind icon texture.
local ICON = {
	quest   = "Interface\\GossipFrame\\AvailableQuestIcon",
	accept  = "Interface\\GossipFrame\\AvailableQuestIcon",
	turnin  = "Interface\\GossipFrame\\ActiveQuestIcon",
	["do"]  = "Interface\\Icons\\Ability_Hunter_SniperShot",
	travel  = "Interface\\Icons\\Ability_Mount_RidingHorse",
	dungeon = "Interface\\Icons\\Achievement_Boss_Generic",
	grind   = "Interface\\Icons\\Ability_DualWield",
	train   = "Interface\\Icons\\Spell_Holy_MagicalSentry",
	gear    = "Interface\\Icons\\INV_Chest_Chain",
	hearth  = "Interface\\Icons\\INV_Misc_Rune_01",
	note    = "Interface\\Icons\\INV_Misc_Note_01",
}
function W.KindIcon(kind) return ICON[kind] or ICON.note end
