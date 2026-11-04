--!strict
-- Greybox space around the station: the asteroid field and the hard edge of the map. Where the
-- zones and their nests lie is in ZoneConfig; colors are in ZoneLooks. Seeded, so every server
-- builds the same field. Pure Luau: tests load it in Lune.

return table.freeze({
	SEED = 20261102,
	ASTEROID_COUNT = 700,
	-- Distance from the station center, studs.
	INNER_RADIUS = 160,
	OUTER_RADIUS = 2900,
	-- The field is flattened into a thick disc: max height above or below the station.
	VERTICAL_SPREAD = 400,
	-- Hard edge of the map: a sphere around the station nobody flies out of (see Bounds).
	BOUNDARY_RADIUS = 3100,
	MIN_SIZE = 8,
	MAX_SIZE = 45,
	-- Nest asteroids: dedicated rocks with a bowl on top.
	NEST_ASTEROID_MIN_SIZE = 20,
	NEST_ASTEROID_MAX_SIZE = 28,
})
