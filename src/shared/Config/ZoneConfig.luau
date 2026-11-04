--!strict
-- The four zones of the map, as rings around the station: how far they are, how many nests
-- and guardian posts each has, and what eggs grow there. Farther zones give rarer eggs.
-- Pure Luau: the balance calculator and tests load it in Lune. Looks live in ZoneLooks.
--
-- The rings are measured out from the station border (StationSize), so a bigger station moves
-- the whole map out with it and the flight from the border to the first nests stays the same.

local EggConfig = require("./EggConfig")
local Loot = require("../Domain/Loot")
local StationSize = require("./StationSize")
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

-- `studs` past the station border, from the station center.
local function pastBorder(studs: number): number
	return StationSize.BORDER_RADIUS + studs
end

local function zone(
	id: ZoneId,
	nameKey: keyof<typeof(Strings)>,
	-- Where its nests lie (see Zone) and how many there are: the far rings are much longer, so
	-- they get more nests, about 2.2 s of flight apart at the zone's own speed everywhere.
	ring: { min: number, max: number, height: number, nests: number },
	rarityLoot: { Loot.Entry<EggConfig.RarityId> },
	sizeLoot: { Loot.Entry<EggConfig.SizeId> }
): Zone
	return table.freeze({
		id = id,
		nameKey = nameKey,
		ringMin = ring.min,
		ringMax = ring.max,
		heightSpread = ring.height,
		nestCount = ring.nests,
		postCount = POSTS_PER_ZONE,
		rarityLoot = table.freeze(rarityLoot),
		sizeLoot = table.freeze(sizeLoot),
	})
end

local ZONES: { [ZoneId]: Zone } = {
	DebrisBelt = zone("DebrisBelt", "zone.debrisBelt.title", {
		min = pastBorder(135),
		max = pastBorder(330),
		height = 90,
		nests = 14,
	}, {
		{ id = "Common", weight = 70 },
		{ id = "Uncommon", weight = 25 },
		{ id = "Rare", weight = 5 },
	}, {
		{ id = "Small", weight = 50 },
		{ id = "Medium", weight = 35 },
		{ id = "Large", weight = 15 },
	}),
	IceRings = zone("IceRings", "zone.iceRings.title", {
		min = pastBorder(625),
		max = pastBorder(965),
		height = 160,
		nests = 20,
	}, {
		{ id = "Common", weight = 50 },
		{ id = "Uncommon", weight = 32 },
		{ id = "Rare", weight = 15 },
		{ id = "Epic", weight = 3 },
	}, {
		{ id = "Small", weight = 40 },
		{ id = "Medium", weight = 40 },
		{ id = "Large", weight = 20 },
	}),
	RedNebula = zone("RedNebula", "zone.redNebula.title", {
		min = pastBorder(1295),
		max = pastBorder(1790),
		height = 230,
		nests = 25,
	}, {
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
	EventHorizon = zone(
		"EventHorizon",
		"zone.eventHorizon.title",
		{ min = pastBorder(2150), max = pastBorder(2750), height = 300, nests = 32 },
		{
			{ id = "Common", weight = 25 },
			{ id = "Uncommon", weight = 30 },
			{ id = "Rare", weight = 25 },
			{ id = "Epic", weight = 15 },
			{ id = "Legendary", weight = 5 },
		},
		{
			{ id = "Small", weight = 30 },
			{ id = "Medium", weight = 40 },
			{ id = "Large", weight = 30 },
		}
	),
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

-- The zone `distance` studs from the station lies in, or the nearest one when between rings
-- (beyond the last ring: the last zone). Nil this side of the first ring.
function ZoneConfig.zoneAtDistance(distance: number): ZoneId?
	local first = ZONES[ZONE_ORDER[1]]
	if distance < first.ringMin then
		return nil
	end
	local nearest: ZoneId = ZONE_ORDER[1]
	local nearestGap = math.huge
	for _, id in ZONE_ORDER do
		local ring = ZONES[id]
		local gap = if distance < ring.ringMin
			then ring.ringMin - distance
			elseif distance > ring.ringMax then distance - ring.ringMax
			else 0
		if gap < nearestGap then
			nearest, nearestGap = id, gap
		end
	end
	return nearest
end

-- The global index of post `local_` of `zoneId`.
function ZoneConfig.postIndex(zoneId: ZoneId, local_: number): number
	local zoneIndex = assert(table.find(ZONE_ORDER, zoneId), `unknown zone {zoneId}`)
	assert(local_ >= 1 and local_ <= POSTS_PER_ZONE, `post {local_} out of range for {zoneId}`)
	return (zoneIndex - 1) * POSTS_PER_ZONE + local_
end

return table.freeze(ZoneConfig)
