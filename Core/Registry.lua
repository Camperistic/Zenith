--[[ Core/Registry.lua  ─────────────────────────────────────────────────────────
     Central registry of feature modules. Each module registers itself with an
     Enable/Disable and an IsFeatureEnabled() predicate, giving uniform toggling
     and a trivial "disable module" UX. Modules are views over the StateModel.
]]
local ADDON, ns = ...

local Registry = {}
ns.Registry = Registry
local modules = {}
local order = {}

-- def = { name, OnEnable, OnDisable, IsFeatureEnabled }
function Registry:Add(def)
	assert(def and def.name, "module needs a name")
	modules[def.name] = def
	order[#order + 1] = def
	return def
end

function Registry:Get(name) return modules[name] end
function Registry:All() return order end

function Registry:EnableAll()
	for _, m in ipairs(order) do
		if not m._enabled and (not m.IsFeatureEnabled or m:IsFeatureEnabled()) then
			m._enabled = true
			if m.OnEnable then
				local ok, err = pcall(m.OnEnable, m)
				if not ok then ns:Debug("module " .. m.name .. " failed to enable: " .. tostring(err)) end
			end
		end
	end
end

function Registry:SetEnabled(name, on)
	local m = modules[name]
	if not m then return end
	if on and not m._enabled then
		m._enabled = true
		if m.OnEnable then pcall(m.OnEnable, m) end
	elseif not on and m._enabled then
		m._enabled = false
		if m.OnDisable then pcall(m.OnDisable, m) end
	end
end
