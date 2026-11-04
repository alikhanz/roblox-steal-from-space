--!strict
-- Greybox space around the station: the asteroid field and the hard edge of the map. Where the
-- zones and their nests lie is in ZoneConfig; colors are in ZoneLooks. Seeded, so every server
-- builds the same field. Pure Luau: tests load it in Lune.
--
-- The field and the edge follow the station and the zones (StationSize, ZoneConfig): a bigger
-- station pushes them out together.

local StationSize = require("./StationSize")
local ZoneConfig = require("./ZoneConfig")

-- The far edge of the last zone.
local LAST_RING = ZoneConfig.ZONES[ZoneConfig.ZONE_ORDER[#ZoneConfig.ZONE_ORDER]].ringMax

return table.freeze({
	SEED = 20261102,
	ASTEROID_COUNT = 700,
	-- Distance from the station center, studs: from just past the station border to the far
	-- edge of the last zone.
	INNER_RADIUS = StationSize.BORDER_RADIUS + 10,
	OUTER_RADIUS = LAST_RING,
	-- The field is flattened into a thick disc: max height above or below the station.
	VERTICAL_SPREAD = 400,
	-- Hard edge of the map: a sphere around the station nobody flies out of (see Bounds), a
	-- little past the last zone.
	BOUNDARY_RADIUS = LAST_RING + 200,
	MIN_SIZE = 8,
	MAX_SIZE = 45,
	-- Nest asteroids: dedicated rocks with a bowl on top.
	NEST_ASTEROID_MIN_SIZE = 20,
	NEST_ASTEROID_MAX_SIZE = 28,
})
