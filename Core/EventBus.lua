--[[ Core/EventBus.lua  ─────────────────────────────────────────────────────────
     Internal publish/subscribe bus. Subsystems react to StateModel changes and
     each other through this — never by polling. Distinct from Blizzard events
     (those feed the StateModel; the StateModel publishes semantic events here).

     Semantic events (payload in parens):
       SPEC_CHANGED ()            LEVEL_CHANGED (newLevel)
       ZONE_CHANGED (uiMapID)     XP_CHANGED ()
       QUESTLOG_CHANGED ()        BAGS_CHANGED ()
       EQUIPMENT_CHANGED ()       STATE_READY ()
]]
local ADDON, ns = ...

local Bus = {}
ns.Bus = Bus
local listeners = {}

function Bus:On(event, fn)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
	return fn
end

function Bus:Off(event, fn)
	local l = listeners[event]
	if not l then return end
	for i = #l, 1, -1 do if l[i] == fn then table.remove(l, i) end end
end

function Bus:Fire(event, ...)
	local l = listeners[event]
	if not l then return end
	for i = 1, #l do
		local ok, err = pcall(l[i], ...)
		if not ok and ns.Debug then ns:Debug("Bus handler error [" .. event .. "]: " .. tostring(err)) end
	end
end
