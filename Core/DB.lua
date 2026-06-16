--[[ Core/DB.lua  ───────────────────────────────────────────────────────────────
     AceDB setup. Account-wide settings/profiles + per-character tracking live in
     one SavedVariable (ZenithDB) split by AceDB namespaces:
       .global  → account-wide progress / shared route strings
       .profile → settings, layout, theme (profile-switchable)
       .char    → per-character tracking (level splits, route cursor, completions)
     The static quest/route database is shipped as Lua and NEVER stored here.
]]
local ADDON, ns = ...

ns.dbDefaults = {
	global = {
		customRoutes = {},
	},
	profile = {
		theme = "dark",
		minimap = { hide = false },
		modules = {},          -- [moduleName] = false to disable
		locked = false,
		pinMode = "full",
		scale = 1.0,
		routeMode = "balanced",   -- fast | balanced | complete (how many quests the route includes)
		autoEquip = false,     -- gear advisor auto-equips upgrades (out of combat only)
	},
	char = {
		route = { key = nil, cursor = 1, completed = {} },
		tracker = { splits = {}, activeTotal = 0 },
	},
}

-- Called from Init:OnInitialize once AceDB is available.
function ns:SetupDB()
	local AceDB = LibStub("AceDB-3.0")
	self.db = AceDB:New("ZenithDB", ns.dbDefaults, true)
	-- convenience aliases
	self.settings = self.db.profile
	self.char = self.db.char
	self.global = self.db.global
	self.db.RegisterCallback(self, "OnProfileChanged", function() ns.Bus:Fire("PROFILE_CHANGED") end)
	self.db.RegisterCallback(self, "OnProfileCopied",  function() ns.Bus:Fire("PROFILE_CHANGED") end)
	self.db.RegisterCallback(self, "OnProfileReset",   function() ns.Bus:Fire("PROFILE_CHANGED") end)
end
