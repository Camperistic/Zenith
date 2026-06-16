--[[ Modules/UI/Widgets.lua — themed building blocks (borders, panels, flat
     buttons, step icons). All colours resolved through ns.Theme. ]]
local ADDON, ns = ...
local Theme = ns.Theme
local W = {}
ns.W = W

function W.Panel(parent, key, layer)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(Theme:C(key or "panel"))
	return t
end

function W.Border(frame, alpha, thickness)
	local t = thickness or 1
	local r, g, b = Theme:RGB("accent")
	local a = alpha or 0.7
	local function edge()
		local tex = frame:CreateTexture(nil, "BORDER"); tex:SetColorTexture(r, g, b, a); return tex
	end
	local top = edge();   top:SetPoint("TOPLEFT");    top:SetPoint("TOPRIGHT");    top:SetHeight(t)
	local bot = edge();   bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(t)
	local lf = edge();    lf:SetPoint("TOPLEFT");     lf:SetPoint("BOTTOMLEFT");   lf:SetWidth(t)
	local rt = edge();    rt:SetPoint("TOPRIGHT");    rt:SetPoint("BOTTOMRIGHT");  rt:SetWidth(t)
end

function W.Button(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(Theme:C("panel"))
	W.Border(b, 0.45, 1)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("CENTER"); fs:SetText(text); fs:SetTextColor(Theme:RGB("accent"))
	b.label = fs
	b:SetScript("OnEnter", function() local r, g, bl = Theme:RGB("accent"); bg:SetColorTexture(r * 0.3, g * 0.3, bl * 0.3, 0.95) end)
	b:SetScript("OnLeave", function() bg:SetColorTexture(Theme:C("panel")) end)
	b.SetText = function(self, t) self.label:SetText(t) end
	return b
end

local ICON = {
	quest = "Interface\\GossipFrame\\AvailableQuestIcon", accept = "Interface\\GossipFrame\\AvailableQuestIcon",
	turnin = "Interface\\GossipFrame\\ActiveQuestIcon", ["do"] = "Interface\\Icons\\Ability_Hunter_SniperShot",
	travel = "Interface\\Icons\\Ability_Mount_RidingHorse", dungeon = "Interface\\Icons\\Achievement_Boss_Generic",
	go = "Interface\\Icons\\Ability_Rogue_Sprint", note = "Interface\\Icons\\INV_Misc_Note_01",
}
function W.KindIcon(kind) return ICON[kind] or ICON.note end
