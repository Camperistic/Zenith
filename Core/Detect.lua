--[[ Core/Detect.lua  ──────────────────────────────────────────────────────────
     Runtime client/flavour detection. Never hardcode the version anywhere else —
     read ns.flavor.* instead. Drives which data pack and flavour modules apply.
]]
local ADDON, ns = ...

local PROJECT = {
	[WOW_PROJECT_MAINLINE or -1]            = "mainline",
	[WOW_PROJECT_CLASSIC or -2]             = "vanilla",
	[WOW_PROJECT_BURNING_CRUSADE or -3]     = "tbc",
	[WOW_PROJECT_WRATH_CLASSIC or -4]       = "wrath",
	[WOW_PROJECT_CATACLYSM_CLASSIC or -5]   = "cata",
	[WOW_PROJECT_MISTS_CLASSIC or -6]       = "mists",
}

local version, build, _, interface = GetBuildInfo()

ns.flavor = {
	project   = WOW_PROJECT_ID,
	id        = PROJECT[WOW_PROJECT_ID] or "unknown",
	version   = version,        -- e.g. "2.5.4"
	build     = tonumber(build),
	interface = interface,      -- e.g. 20504
	-- The classic-style 51-point talent trees vs. the Retail/Dragonflight system.
	classicTalents = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE),
}

-- Data packs register the flavours they cover so Init can friendly-fail cleanly.
ns.dataPacks = ns.dataPacks or {}          -- [flavorId] = true once a pack loads
function ns:HasDataPack(flavorId)
	return ns.dataPacks[flavorId or ns.flavor.id] == true
end
