--[[ Modules/UI/Window.lua

     The unified window. Owns the chrome, the tab bar, and the built-in Guide tab
     (the live route step). Other modules add tabs via ns.UI:AddTab(name, builder).
     Reads ns.Route and reacts to EventBus changes — never polls.
]]
local ADDON, ns = ...
local Theme, W, Bus = ns.Theme, ns.W, ns.Bus
local C = ns.compat

local UI = {}
ns.UI = UI

local frame, tabs, panes, activeTab = nil, {}, {}, "Guide"
local tabDefs = {}   -- ordered { {name, build} }

function UI:AddTab(name, build)
	tabDefs[#tabDefs + 1] = { name = name, build = build }
	if frame then self:RebuildTabs() end
end

-- ── helpers ───────────────────────────────────────────────────────────────────
local function scrollRegion(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT"); sf:SetPoint("BOTTOMRIGHT", -26, 0)
	local content = CreateFrame("Frame", nil, sf); content:SetSize(10, 10); sf:SetScrollChild(content)
	local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT"); fs:SetWidth((parent:GetWidth() or 330) - 30)
	fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetSpacing(2)
	sf.Set = function(_, s) fs:SetText(s or ""); content:SetHeight((fs:GetStringHeight() or 10) + 12) end
	return sf
end

local function liveObjectives(qid)
	if not (qid and C.GetQuestObjectives and C.GetLogIndexForQuestID and C.GetLogIndexForQuestID(qid)) then return nil end
	local objs = C.GetQuestObjectives(qid); if not objs then return nil end
	local lines = {}
	for _, o in ipairs(objs) do
		if o.text and o.text ~= "" then lines[#lines + 1] = (o.finished and "|cff40c040" .. o.text .. "|r") or ("• " .. o.text) end
	end
	return #lines > 0 and table.concat(lines, "\n") or nil
end

-- ── Guide pane ────────────────────────────────────────────────────────────────
local function buildGuide(pane)
	local progress = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	progress:SetPoint("TOPLEFT"); progress:SetTextColor(Theme:RGB("accent"))

	local card = CreateFrame("Frame", nil, pane)
	card:SetPoint("TOPLEFT", 0, -18); card:SetPoint("TOPRIGHT", -2, -18); card:SetHeight(108)
	local cbg = card:CreateTexture(nil, "BACKGROUND"); cbg:SetAllPoints()
	local r, g, b = Theme:RGB("accent"); cbg:SetColorTexture(r, g, b, 0.07)
	W.Border(card, 0.4, 1)
	local edge = card:CreateTexture(nil, "ARTWORK"); edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(3); edge:SetColorTexture(r, g, b, 1)

	local icon = card:CreateTexture(nil, "ARTWORK"); icon:SetSize(26, 26); icon:SetPoint("TOPLEFT", 10, -8); icon:SetTexCoord(.08, .92, .08, .92)
	local tag = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); tag:SetPoint("TOPLEFT", icon, "TOPRIGHT", 7, -3)
	local text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); text:SetPoint("TOPLEFT", 10, -38); text:SetPoint("RIGHT", card, "RIGHT", -8, 0); text:SetJustifyH("LEFT"); text:SetWordWrap(true)
	local detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); detail:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4); detail:SetPoint("RIGHT", card, "RIGHT", -8, 0); detail:SetJustifyH("LEFT"); detail:SetWordWrap(true); detail:SetTextColor(Theme:RGB("dim"))
	local objfs = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); objfs:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -3); objfs:SetPoint("RIGHT", card, "RIGHT", -8, 0); objfs:SetJustifyH("LEFT"); objfs:SetWordWrap(true)

	local back = W.Button(pane, "◁ Back", 58, 20); back:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -6); back:SetScript("OnClick", function() ns.Route:Prev() end)
	local done = W.Button(pane, "✓ Done", 96, 20); done:SetPoint("LEFT", back, "RIGHT", 6, 0); done:SetScript("OnClick", function() ns.Route:Complete() end)
	local skip = W.Button(pane, "Skip ▷", 58, 20); skip:SetPoint("LEFT", done, "RIGHT", 6, 0); skip:SetScript("OnClick", function() ns.Route:Complete() end)

	local label = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); label:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -8); label:SetText(Theme:Color("dim", "UP NEXT"))
	local host = CreateFrame("Frame", nil, pane); host:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4); host:SetPoint("BOTTOMRIGHT")
	local scroll = scrollRegion(host)

	local VERB = { accept = "ACCEPT", ["do"] = "DO", ["turn in"] = "TURN IN", go = "GO TO" }
	function pane:Refresh()
		local R = ns.Route
		local g = R and R:Guidance()
		if not g then
			icon:SetTexture(nil); tag:SetText(""); detail:SetText(""); objfs:SetText("")
			if R and R:Count() > 0 then progress:SetText(Theme:Color("accent", "Route complete — congratulations!")); text:SetText("Every quest on the route is done.")
			else progress:SetText("No route for this character yet."); text:SetText("") end
			scroll:Set(""); return
		end
		local s = g.step
		local idx = ns.db.char.route.cursor or 1
		local band = s.band and string.format("  ·  Lvl %d–%d", s.band[1], s.band[2]) or ""
		progress:SetText(string.format("Step %d / %d   ·   %s%s", idx, R:Count(), s.zone or "", band))
		icon:SetTexture(W.KindIcon(s.kind))
		tag:SetText(Theme:Color("gold", "[" .. (VERB[g.stage] or "DO") .. "]"))
		text:SetText(s.text or "")
		local d = s.detail or ""
		if g.stage == "accept" then d = "Pick up this quest." .. (s.detail and ("  " .. s.detail) or "")
		elseif g.stage == "turn in" then d = "Hand this quest in." end
		detail:SetText(d)
		objfs:SetText((g.stage == "do" and liveObjectives(s.qid)) or "")

		local lines = {}
		local plan = R:Plan(10)
		-- skip plan[1] — that's already the card. Show the rest as ACCEPT/DO/TURN IN.
		for i = 2, #plan do
			local p = plan[i]
			local verb = VERB[p.stage] or "DO"
			lines[#lines + 1] = Theme:Color("gold", "[" .. verb .. "]") .. "  "
				.. Theme:Color("dim", (p.step.zone or "") .. "  ") .. (p.label or "")
		end
		scroll:Set(#lines > 0 and table.concat(lines, "\n") or "")
	end
end

-- ── chrome / tabs ─────────────────────────────────────────────────────────────
function UI:RebuildTabs()
	for _, b in pairs(tabs) do b:Hide() end
	wipe(tabs)
	local x = 6
	for _, def in ipairs(tabDefs) do
		local b = CreateFrame("Button", nil, frame); b:SetSize(66, 22); b:SetPoint("TOPLEFT", x, -32)
		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); fs:SetAllPoints(); fs:SetText(def.name); b.fs = fs
		local ul = b:CreateTexture(nil, "OVERLAY"); ul:SetColorTexture(Theme:RGB("accent")); ul:SetPoint("BOTTOMLEFT", 4, 0); ul:SetPoint("BOTTOMRIGHT", -4, 0); ul:SetHeight(2); b.ul = ul
		b:SetScript("OnClick", function() UI:Select(def.name) end)
		tabs[def.name] = b; x = x + 69
		if not panes[def.name] then
			local p = CreateFrame("Frame", nil, frame); p:SetPoint("TOPLEFT", 8, -58); p:SetPoint("BOTTOMRIGHT", -8, 8)
			def.build(p); panes[def.name] = p; p:Hide()
		end
	end
	UI:Select(activeTab)
end

function UI:Select(name)
	if not panes[name] then name = tabDefs[1] and tabDefs[1].name end
	activeTab = name
	for n, b in pairs(tabs) do
		local on = n == name
		b.ul:SetShown(on)
		b.fs:SetTextColor(Theme:RGB(on and "accent" or "dim"))
	end
	for n, p in pairs(panes) do p:SetShown(n == name) end
	if panes[name] and panes[name].Refresh then panes[name]:Refresh() end
end

function UI:RefreshActive() if panes[activeTab] and panes[activeTab].Refresh then panes[activeTab]:Refresh() end end
function UI:Toggle() if frame:IsShown() then frame:Hide() else frame:Show(); UI:Select(activeTab) end end
function UI:Frame() return frame end

-- Apply live-tunable profile settings (scale, lock label) to the existing window.
function UI:ApplySettings()
	if not frame then return end
	frame:SetScale(ns.db.profile.scale or 1)
	if frame.lockBtn then frame.lockBtn:SetText(ns.db.profile.locked and "Unlock" or "Lock") end
end

local function buildChrome()
	local f = CreateFrame("Frame", "ZenithWindow", UIParent); f:SetSize(340, 460); f:SetClampedToScreen(true)
	f:SetScale(ns.db.profile.scale or 1)
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetFrameStrata("MEDIUM")
	f:SetScript("OnDragStart", function(self) if not ns.db.profile.locked then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); ns.db.profile.point = { p, rp, x, y } end)
	W.Panel(f):SetAllPoints()
	local hdr = f:CreateTexture(nil, "BACKGROUND"); hdr:SetColorTexture(Theme:C("header")); hdr:SetPoint("TOPLEFT", 1, -1); hdr:SetPoint("TOPRIGHT", -1, -1); hdr:SetHeight(28)
	local line = f:CreateTexture(nil, "ARTWORK"); line:SetColorTexture(Theme:RGB("accent")); line:SetPoint("TOPLEFT", 1, -29); line:SetPoint("TOPRIGHT", -1, -29); line:SetHeight(1)
	W.Border(f, 0.75, 1)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 10, -7)
	title:SetText(Theme:Color("accent", "Zenith") .. Theme:Color("dim", "  v" .. ns.VERSION))
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2); close:SetScript("OnClick", function() f:Hide() end)
	local lock = W.Button(f, ns.db.profile.locked and "Unlock" or "Lock", 50, 18); lock:SetPoint("TOPRIGHT", -26, -5)
	lock:SetScript("OnClick", function() ns.db.profile.locked = not ns.db.profile.locked; lock:SetText(ns.db.profile.locked and "Unlock" or "Lock") end)
	f.lockBtn = lock
	local pt = ns.db.profile.point
	if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("CENTER", 280, 0) end
	return f
end

ns.Registry:Add({
	name = "UI",
	OnEnable = function()
		frame = buildChrome()
		UI:AddTab("Guide", buildGuide)   -- built-in; others register via AddTab
		UI:RebuildTabs()
		frame:SetShown(ns.db.profile.windowShown ~= false)
		Bus:On("ROUTE_CHANGED", function() UI:RefreshActive() end)
		Bus:On("ROUTE_LOADED", function() UI:RefreshActive() end)
		Bus:On("QUESTLOG_CHANGED", function() UI:RefreshActive() end)
		Bus:On("PROFILE_CHANGED", function() UI:RefreshActive() end)
		Bus:On("SLASH", function(msg) if msg == "" or msg == "toggle" then UI:Toggle() end end)
	end,
})
