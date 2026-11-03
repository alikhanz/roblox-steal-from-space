--!strict
-- The four zones of the map, as rings around the station: how far they are, how many nests
-- and guardian posts each has, and what eggs grow there. Farther zones give rarer eggs.
-- Pure Luau: the balance calculator and tests load it in Lune. Looks live in ZoneLooks.

local EggConfig = require("./EggConfig")
local Loot = require("../Domain/Loot")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")

export type ZoneId = "DebrisBelt" | "IceRings" | "RedNebula" | "EventHorizon"

export type Zone = {
	read id: ZoneId,
	read nameKey: keyof<typeof(Strings)>,
	-- Nest asteroids of the zone lie between these distances from the station, studs, and
	-- within this height above or below it.
	read ringMin: number,
	read ringMax: number,
	read heightSpread: number,
	read nestCount: number,
	-- Guardian posts of the zone; nests are shared out among them, nearest first.
	read postCount: number,
	read rarityLoot: { Loot.Entry<EggConfig.RarityId> },
	read sizeLoot: { Loot.Entry<EggConfig.SizeId> },
}

-- From the station outwards. Guardian posts and alien grades follow this order.
local ZONE_ORDER: { ZoneId } = { "DebrisBelt", "IceRings", "RedNebula", "EventHorizon" }

local POSTS_PER_ZONE = 6

local function zone(
	id: ZoneId,
	nameKey: keyof<typeof(Strings)>,
	ring: { min: number, max: number, height: number },
	rarityLoot: { Loot.Entry<EggConfig.RarityId> },
	sizeLoot: { Loot.Entry<EggConfig.SizeId> }
): Zone
	return table.freeze({
		id = id,
		nameKey = nameKey,
		ringMin = ring.min,
		ringMax = ring.max,
		heightSpread = ring.height,
		nestCount = 12,
		postCount = POSTS_PER_ZONE,
		rarityLoot = table.freeze(rarityLoot),
		sizeLoot = table.freeze(sizeLoot),
	})
end

local ZONES: { [ZoneId]: Zone } = {
	DebrisBelt = zone("DebrisBelt", "zone.debrisBelt.title", { min = 190, max = 320, height = 60 }, {
		{ id = "Common", weight = 70 },
		{ id = "Uncommon", weight = 25 },
		{ id = "Rare", weight = 5 },
	}, {
		{ id = "Small", weight = 50 },
		{ id = "Medium", weight = 35 },
		{ id = "Large", weight = 15 },
	}),
	IceRings = zone("IceRings", "zone.iceRings.title", { min = 430, max = 620, height = 90 }, {
		{ id = "Common", weight = 50 },
		{ id = "Uncommon", weight = 32 },
		{ id = "Rare", weight = 15 },
		{ id = "Epic", weight = 3 },
	}, {
		{ id = "Small", weight = 40 },
		{ id = "Medium", weight = 40 },
		{ id = "Large", weight = 20 },
	}),
	RedNebula = zone("RedNebula", "zone.redNebula.title", { min = 760, max = 1020, height = 120 }, {
		{ id = "Common", weight = 35 },
		{ id = "Uncommon", weight = 35 },
		{ id = "Rare", weight = 20 },
		{ id = "Epic", weight = 8 },
		{ id = "Legendary", weight = 2 },
	}, {
		{ id = "Small", weight = 35 },
		{ id = "Medium", weight = 40 },
		{ id = "Large", weight = 25 },
	}),
	EventHorizon = zone("EventHorizon", "zone.eventHorizon.title", { min = 1150, max = 1450, height = 150 }, {
		{ id = "Common", weight = 25 },
		{ id = "Uncommon", weight = 30 },
		{ id = "Rare", weight = 25 },
		{ id = "Epic", weight = 15 },
		{ id = "Legendary", weight = 5 },
	}, {
		{ id = "Small", weight = 30 },
		{ id = "Medium", weight = 40 },
		{ id = "Large", weight = 30 },
	}),
}

local ZoneConfig = {}

ZoneConfig.ZONE_ORDER = table.freeze(ZONE_ORDER)
ZoneConfig.ZONES = table.freeze(ZONES)
ZoneConfig.POSTS_PER_ZONE = POSTS_PER_ZONE
ZoneConfig.POST_COUNT = POSTS_PER_ZONE * #ZONE_ORDER

-- The zone of global post (and alien grade) `index`, and the post's number within it.
function ZoneConfig.zoneOfPost(index: number): (ZoneId, number)
	assert(index >= 1 and index <= ZoneConfig.POST_COUNT and index % 1 == 0, `post {index} out of range`)
	local zoneIndex = (index - 1) // POSTS_PER_ZONE + 1
	return ZONE_ORDER[zoneIndex], (index - 1) % POSTS_PER_ZONE + 1
end

-- The global index of post `local_` of `zoneId`.
function ZoneConfig.postIndex(zoneId: ZoneId, local_: number): number
	local zoneIndex = assert(table.find(ZONE_ORDER, zoneId), `unknown zone {zoneId}`)
	assert(local_ >= 1 and local_ <= POSTS_PER_ZONE, `post {local_} out of range for {zoneId}`)
	return (zoneIndex - 1) * POSTS_PER_ZONE + local_
end

return table.freeze(ZoneConfig)
