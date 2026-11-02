--!strict
-- Greybox asteroid field around the station. Seeded, so every server builds the same field.

return table.freeze({
	SEED = 20261102,
	ASTEROID_COUNT = 140,
	-- Distance from the station center, studs.
	INNER_RADIUS = 160,
	OUTER_RADIUS = 900,
	-- The field is flattened into a thick disc: max height above or below the station.
	VERTICAL_SPREAD = 250,
	MIN_SIZE = 8,
	MAX_SIZE = 45,
	-- Nests of the Debris Belt: dedicated asteroids spread around a ring outside the dome.
	NEST_COUNT = 12,
	NEST_RING_MIN = 190,
	NEST_RING_MAX = 320,
	NEST_HEIGHT_SPREAD = 60,
	NEST_ASTEROID_MIN_SIZE = 20,
	NEST_ASTEROID_MAX_SIZE = 28,
	ROCK_COLORS = table.freeze({
		Color3.fromRGB(96, 92, 104),
		Color3.fromRGB(120, 112, 118),
		Color3.fromRGB(78, 80, 92),
		Color3.fromRGB(110, 98, 90),
	}),
})
