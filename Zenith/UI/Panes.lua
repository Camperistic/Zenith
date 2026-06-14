--[[ UI/Panes.lua

     Content builders for each tab of the main window. Each registers a function
     in ns.PaneBuilders[name] that populates the pane frame and gives it :Refresh.

     Most panes assemble a coloured text block on refresh (simple + robust); the
     Guide pane adds interactive Done/Skip/Back buttons.
]]
local ADDON_NAME, ns = ...
local U = ns.U
local AC = ns.COLORS.accent
ns.PaneBuilders = {}

-- kind → display tag
local KIND = {
	travel    = { "TRAVEL",  0.55, 0.75, 1.00 },
	quest     = { "QUEST",   1.00, 0.82, 0.00 },
	accept    = { "ACCEPT",  0.45, 0.86, 0.27 },
	turnin    = { "TURN IN", 1.00, 0.70, 0.10 },
	["do"]    = { "DO",      0.95, 0.85, 0.35 },
	grind     = { "GRIND",   0.90, 0.55, 0.30 },
	dungeon   = { "DUNGEON", 0.75, 0.45, 0.95 },
	train     = { "TRAIN",   0.45, 0.86, 0.27 },
	gear      = { "GEAR",    0.45, 0.86, 0.27 },
	hearth    = { "HEARTH",  0.60, 0.80, 1.00 },
	note      = { "NOTE",    0.70, 0.70, 0.70 },
}
local function kindTag(kind)
	local k = KIND[kind or "note"] or KIND.note
	return string.format("|cff%02x%02x%02x[%s]|r", k[2] * 255, k[3] * 255, k[4] * 255, k[1])
end

-- Reusable vertical-scrolling text region.
local function makeScroll(parent, bottomInset)
	local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 0, 0)
	sf:SetPoint("BOTTOMRIGHT", -26, bottomInset or 0)
	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(10, 10)
	sf:SetScrollChild(content)
	local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT")
	text:SetWidth((parent:GetWidth() or 340) - 30)
	text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetSpacing(2)
	sf.text = text; sf.content = content
	sf.Set = function(self, str)
		self.text:SetText(str or "")
		self.content:SetHeight((self.text:GetStringHeight() or 10) + 12)
	end
	return sf
end

-- ════════════════════════════════ GUIDE ═══════════════════════════════════════
ns.PaneBuilders.Guide = function(pane)
	local SE = ns:GetModule("StepEngine")

	local progress = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	progress:SetPoint("TOPLEFT")
	progress:SetTextColor(AC[1], AC[2], AC[3])

	-- Current step card
	local card = CreateFrame("Frame", nil, pane)
	card:SetPoint("TOPLEFT", 0, -18); card:SetPoint("TOPRIGHT", -2, -18); card:SetHeight(96)
	local cbg = card:CreateTexture(nil, "BACKGROUND"); cbg:SetAllPoints(); cbg:SetColorTexture(AC[1], AC[2], AC[3], 0.10)
	local cedge = card:CreateTexture(nil, "BORDER"); cedge:SetPoint("TOPLEFT"); cedge:SetPoint("BOTTOMLEFT"); cedge:SetWidth(3); cedge:SetColorTexture(AC[1], AC[2], AC[3], 1)

	local curTag = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	curTag:SetPoint("TOPLEFT", 8, -6)
	local curText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	curText:SetPoint("TOPLEFT", curTag, "BOTTOMLEFT", 0, -4)
	curText:SetPoint("RIGHT", card, "RIGHT", -8, 0); curText:SetJustifyH("LEFT"); curText:SetWordWrap(true)
	local curDetail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	curDetail:SetPoint("TOPLEFT", curText, "BOTTOMLEFT", 0, -4)
	curDetail:SetPoint("RIGHT", card, "RIGHT", -8, 0); curDetail:SetJustifyH("LEFT"); curDetail:SetWordWrap(true)
	curDetail:SetTextColor(0.78, 0.78, 0.78)

	-- Buttons
	local back = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	back:SetSize(58, 20); back:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -6); back:SetText("◁ Back")
	back:SetScript("OnClick", function() SE:Prev() end)
	local done = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	done:SetSize(96, 20); done:SetPoint("LEFT", back, "RIGHT", 6, 0); done:SetText("✓ Done")
	done:SetScript("OnClick", function() SE:CompleteStep() end)
	local skip = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	skip:SetSize(58, 20); skip:SetPoint("LEFT", done, "RIGHT", 6, 0); skip:SetText("Skip ▷")
	skip:SetScript("OnClick", function() SE:Next() end)

	local upcomingLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	upcomingLabel:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -8); upcomingLabel:SetText(U.Dim("UP NEXT"))

	local listHost = CreateFrame("Frame", nil, pane)
	listHost:SetPoint("TOPLEFT", upcomingLabel, "BOTTOMLEFT", 0, -4)
	listHost:SetPoint("BOTTOMRIGHT", 0, 0)
	local scroll = makeScroll(listHost)

	function pane:Refresh()
		local idx = ns.char.stepIndex or 1
		local total = SE:Count()
		local step = SE:CurrentStep()
		if not step then
			progress:SetText("No route data for this class yet.")
			curText:SetText("")
			scroll:Set("")
			return
		end
		local band = step.band and string.format("  ·  Lvl %d–%d", step.band[1], step.band[2]) or ""
		progress:SetText(string.format("Step %d / %d   ·   %s%s", idx, total, step.zone or "", band))
		curTag:SetText(kindTag(step.kind))
		curText:SetText(step.text or "")
		curDetail:SetText(step.detail or "")

		-- next few steps
		local lines = {}
		for i = idx + 1, math.min(total, idx + 8) do
			local s = SE:StepAt(i)
			if s then
				lines[#lines + 1] = string.format("%s  %s %s",
					kindTag(s.kind), U.Dim(s.zone or ""), s.text or "")
			end
		end
		scroll:Set(#lines > 0 and table.concat(lines, "\n\n") or U.Dim("Route complete — congratulations, 70!"))
	end
end

-- ════════════════════════════════ TALENTS ═════════════════════════════════════
ns.PaneBuilders.Talents = function(pane)
	local TC = ns:GetModule("TalentCoach")

	local header = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header:SetPoint("TOPLEFT"); header:SetTextColor(AC[1], AC[2], AC[3])

	local nextBox = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nextBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	nextBox:SetPoint("RIGHT", pane, "RIGHT", -2, 0); nextBox:SetJustifyH("LEFT"); nextBox:SetWordWrap(true)

	local listHost = CreateFrame("Frame", nil, pane)
	listHost:SetPoint("TOPLEFT", nextBox, "BOTTOMLEFT", 0, -10)
	listHost:SetPoint("BOTTOMRIGHT", 0, 0)
	local scroll = makeScroll(listHost)

	function pane:Refresh()
		local data = TC:SpecData()
		if not data then
			header:SetText("No talent path for this class yet.")
			nextBox:SetText(""); scroll:Set(""); return
		end
		local spent = TC:SpentPoints()
		local unspent = TC:UnspentPoints()
		header:SetText(string.format("%s  (%s)   ·   %d points spent",
			data.specName, data.finalSpec, spent))

		local rec = TC:NextRecommendation()
		if unspent > 0 and rec then
			nextBox:SetText(string.format("%s %s\n%s",
				U.Gold("▶ Put your point in:"), U.Accent(rec.talent),
				U.Dim(rec.note or rec.tree .. " tree")))
		elseif rec then
			nextBox:SetText(U.Dim("Next at level " .. (rec.level or "?") .. ": ") .. U.Accent(rec.talent))
		else
			nextBox:SetText(U.Accent("Leveling path complete — 41/20/0!"))
		end

		-- full path with current marker
		local lines = {}
		local order = data.order
		for i = 1, #order do
			local e = order[i]
			local marker, body
			if i <= spent then
				marker = "|cff40c040✔|r"
				body = U.Dim(string.format("L%d  %s", e.level, e.talent))
			elseif i == spent + 1 then
				marker = U.Gold("▶")
				body = string.format("L%d  %s %s", e.level, U.Accent(e.talent), e.spike and U.Gold("★ SPIKE") or "")
			else
				marker = "  "
				body = string.format("L%d  %s%s", e.level, e.talent, e.spike and U.Gold("  ★") or "")
			end
			lines[#lines + 1] = marker .. " " .. body
		end
		scroll:Set(table.concat(lines, "\n"))
	end
end

-- ════════════════════════════════ GEAR ════════════════════════════════════════
ns.PaneBuilders.Gear = function(pane)
	local GA = ns:GetModule("GearAdvisor")
	local scroll = makeScroll(pane)

	function pane:Refresh()
		local data = GA:Data()
		if not data then scroll:Set("No gear plan for this class yet."); return end
		local out = {}
		out[#out+1] = U.Accent("Stat priority: ") .. data.statPriority

		-- pet tip for current band
		local pets = ns.data.pets[U.PlayerClass()]
		if pets then
			local lvl = U.PlayerLevel()
			for _, ph in ipairs(pets.phases) do
				if lvl <= ph.band[2] then
					out[#out+1] = "\n" .. U.Gold("Pet — " .. ph.title) .. "\n" .. ph.pick
					break
				end
			end
		end

		if GA:IsMaxLevel() and data.preraid then
			out[#out+1] = "\n" .. U.Gold("PRE-RAID BiS (fresh 70)")
			for _, it in ipairs(data.preraid) do
				out[#out+1] = string.format("%s %s  %s", U.Accent("•"),
					it.name .. U.Dim(" ("..it.slot..")"), U.Dim("— " .. (it.source or "")))
			end
		else
			local ms = GA:CurrentMilestone()
			if ms then
				out[#out+1] = "\n" .. U.Gold("CHASE NOW — " .. ms.title)
				for _, it in ipairs(ms.items) do
					out[#out+1] = string.format("%s %s  %s", U.Accent("•"),
						it.name .. U.Dim(" ("..it.slot..")"), U.Dim("— " .. (it.note or "")))
				end
			end
			if data.preraid then
				out[#out+1] = "\n" .. U.Dim("Full pre-raid BiS list unlocks at level 70.")
			end
		end

		out[#out+1] = "\n" .. U.Gold("NOTES")
		for _, n in ipairs(data.notes) do out[#out+1] = "• " .. n end
		scroll:Set(table.concat(out, "\n"))
	end
end

-- ════════════════════════════════ HELP ════════════════════════════════════════
ns.PaneBuilders.Help = function(pane)
	local scroll = makeScroll(pane)
	function pane:Refresh()
		local out = {}
		local rot = ns.data.rotations[U.PlayerClass()]
		rot = rot and rot[rot.default or "BM"]
		if rot then
			if rot.openers then
				out[#out+1] = U.Gold("ROTATION — openers")
				for _, o in ipairs(rot.openers) do out[#out+1] = "• " .. o end
			end
			if rot.aspects then
				out[#out+1] = "\n" .. U.Gold("ASPECTS / MANA")
				for _, a in ipairs(rot.aspects) do out[#out+1] = "• " .. a end
			end
			if rot.notes then
				out[#out+1] = "\n" .. U.Gold("NOTES")
				for _, a in ipairs(rot.notes) do out[#out+1] = "• " .. a end
			end
			out[#out+1] = "\n" .. U.Dim("The on-screen helper suggests your next ability in combat.")
		end
		out[#out+1] = "\n" .. U.Gold("COMMANDS")
		out[#out+1] = "/zenith — toggle window      /zen next | prev"
		out[#out+1] = "/zen arrow — toggle waypoint arrow"
		out[#out+1] = "/zen rotation — toggle DPS helper"
		out[#out+1] = "/zen lock | unlock — move frames"
		out[#out+1] = "/zen reset — restart route progress"
		out[#out+1] = "\n" .. U.Gold("SOURCES")
		out[#out+1] = U.Dim("Wowhead, Icy-Veins, Warcraft Tavern, wowtbc.gg — TBC Classic BM Hunter guides. See README.")
		scroll:Set(table.concat(out, "\n"))
	end
end
