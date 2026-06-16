--[[ Modules/UI/Theme.lua

     The design system. A theme is a named set of colours resolved through one
     theme-aware getter (ns.Theme:C). Ship multiple; switch at runtime via profile.
     Widgets and frames must read colours from here — never hardcode.
]]
local ADDON, ns = ...

local Theme = {}
ns.Theme = Theme

local themes = {
	dark = {
		label  = "Dark (fel)",
		bg     = { 0.045, 0.05, 0.045, 0.96 },
		panel  = { 0.11, 0.13, 0.11, 0.95 },
		header = { 0.072, 0.085, 0.072, 0.95 },
		accent = { 0.45, 0.86, 0.27 },
		text   = { 0.90, 0.90, 0.90 },
		dim    = { 0.60, 0.62, 0.60 },
		gold   = { 1.00, 0.82, 0.00 },
		done   = { 0.40, 0.78, 0.40 },
	},
	midnight = {
		label  = "Midnight (arcane)",
		bg     = { 0.04, 0.045, 0.06, 0.96 },
		panel  = { 0.10, 0.11, 0.15, 0.95 },
		header = { 0.07, 0.08, 0.12, 0.95 },
		accent = { 0.40, 0.62, 1.00 },
		text   = { 0.90, 0.91, 0.95 },
		dim    = { 0.58, 0.60, 0.66 },
		gold   = { 1.00, 0.82, 0.00 },
		done   = { 0.45, 0.70, 1.00 },
	},
	contrast = {
		label  = "High contrast",
		bg     = { 0.00, 0.00, 0.00, 0.97 },
		panel  = { 0.08, 0.08, 0.08, 1.00 },
		header = { 0.12, 0.12, 0.12, 1.00 },
		accent = { 1.00, 0.85, 0.10 },     -- colourblind-safe amber
		text   = { 1.00, 1.00, 1.00 },
		dim    = { 0.75, 0.75, 0.75 },
		gold   = { 1.00, 0.85, 0.10 },
		done   = { 0.30, 0.85, 1.00 },
	},
}

function Theme:Name() return (ns.db and ns.db.profile.theme) or "dark" end
function Theme:Active() return themes[self:Name()] or themes.dark end
function Theme:C(key) return unpack(self:Active()[key] or themes.dark[key] or { 1, 1, 1 }) end
function Theme:RGB(key) local t = self:Active()[key] or { 1, 1, 1 }; return t[1], t[2], t[3] end
function Theme:List() local l = {}; for k, v in pairs(themes) do l[#l + 1] = { k, v.label } end return l end

-- "|cff..text|r" in a theme colour.
function Theme:Color(key, text)
	local r, g, b = self:RGB(key)
	return string.format("|cff%02x%02x%02x%s|r", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5, text)
end
