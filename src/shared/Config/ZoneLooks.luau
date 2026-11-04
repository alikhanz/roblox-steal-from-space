--!strict
-- How each zone looks, greybox: the rocks of its nests take the zone's palette, and the zone
-- announces itself with a landmark (ice ring, red haze, the black hole). Pure numbers are in
-- ZoneConfig.

local WorldConfig = require("./WorldConfig")
local ZoneConfig = require("./ZoneConfig")

export type ZoneLook = {
	read rockColors: { Color3 },
	read rockMaterial: Enum.Material,
}

local rgb = Color3.fromRGB

local ZONES: { [ZoneConfig.ZoneId]: ZoneLook } = {
	DebrisBelt = {
		rockColors = { rgb(96, 92, 104), rgb(120, 112, 118), rgb(78, 80, 92), rgb(110, 98, 90) },
		rockMaterial = Enum.Material.Slate,
	},
	IceRings = {
		rockColors = { rgb(190, 225, 245), rgb(160, 205, 235), rgb(215, 240, 255) },
		rockMaterial = Enum.Material.Ice,
	},
	RedNebula = {
		rockColors = { rgb(140, 50, 50), rgb(110, 40, 60), rgb(170, 70, 50) },
		rockMaterial = Enum.Material.Basalt,
	},
	EventHorizon = {
		rockColors = { rgb(40, 36, 52), rgb(28, 26, 38), rgb(55, 40, 70) },
		rockMaterial = Enum.Material.Slate,
	},
}

return table.freeze({
	ZONES = table.freeze(ZONES),

	-- How far the sign over a guardian shows, studs. Nests stand farther apart in the far zones
	-- (about 170 studs in the Debris Belt, 300 in the Ice Rings, 430 in the Red Nebula, 510 on
	-- the Event Horizon), so the signs reach farther there: the next 3-4 nests around are always
	-- in sight, without the whole map covered in text.
	GUARDIAN_SIGN_DISTANCE = table.freeze({
		DebrisBelt = 500,
		IceRings = 750,
		RedNebula = 950,
		EventHorizon = 1150,
	} :: { [ZoneConfig.ZoneId]: number }),

	-- The plain asteroids of the field, everywhere.
	FIELD_ROCK_COLORS = table.freeze({ rgb(96, 92, 104), rgb(120, 112, 118), rgb(78, 80, 92), rgb(110, 98, 90) }),

	-- Ice Rings: a thin band of small ice chunks around the station at the zone's distance.
	ICE_CHUNK_COUNT = 720,
	ICE_CHUNK_MIN_SIZE = 2,
	ICE_CHUNK_MAX_SIZE = 7,
	ICE_BAND_HEIGHT = 45,
	ICE_COLOR = rgb(200, 235, 255),

	-- Red Nebula: a haze of big, faint red spheres through the zone.
	HAZE_COUNT = 75,
	HAZE_MIN_SIZE = 200,
	HAZE_MAX_SIZE = 450,
	HAZE_COLOR = rgb(200, 40, 60),
	HAZE_TRANSPARENCY = 0.88,

	-- Event Horizon: a black hole at the edge of the map (just inside it), with a glowing rim.
	BLACK_HOLE_DISTANCE = WorldConfig.BOUNDARY_RADIUS - 100,
	BLACK_HOLE_RADIUS = 200,
	BLACK_HOLE_RIM_RADIUS = 225,
	BLACK_HOLE_COLOR = rgb(5, 5, 8),
	BLACK_HOLE_RIM_COLOR = rgb(255, 150, 60),
	BLACK_HOLE_RIM_TRANSPARENCY = 0.5,
})
