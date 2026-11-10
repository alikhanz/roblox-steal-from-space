--!strict
-- How each zone looks, greybox: the rocks of its nests take the zone's palette, and the zone
-- announces itself with a landmark (ice ring, red haze, the black hole). Pure numbers are in
-- ZoneConfig.

local WorldConfig = require("./WorldConfig")
local ZoneConfig = require("./ZoneConfig")

export type ZoneLook = {
	-- A nest's rock (one of the colours, at random) and the landing pad on it (docs/plans/ZONES.md).
	read rockColors: { Color3 },
	read rockMaterial: Enum.Material,
	read padColor: Color3,
	read padMaterial: Enum.Material,
}

local rgb = Color3.fromRGB

local ZONES: { [ZoneConfig.ZoneId]: ZoneLook } = {
	-- A scrapyard: grey rock, a steel plate to land on.
	DebrisBelt = {
		rockColors = { rgb(124, 118, 128), rgb(140, 128, 120), rgb(106, 108, 120), rgb(150, 112, 90) },
		rockMaterial = Enum.Material.Slate,
		padColor = rgb(150, 156, 166),
		padMaterial = Enum.Material.DiamondPlate,
	},
	-- Frost: blue ice rock, a snowy pad.
	IceRings = {
		rockColors = { rgb(150, 200, 235), rgb(120, 180, 225), rgb(175, 215, 240) },
		rockMaterial = Enum.Material.Glacier,
		padColor = rgb(225, 238, 250),
		padMaterial = Enum.Material.Snow,
	},
	-- Warm gas: magma-cracked basalt, an obsidian pad.
	RedNebula = {
		rockColors = { rgb(120, 52, 44), rgb(100, 40, 48), rgb(135, 64, 46) },
		rockMaterial = Enum.Material.CrackedLava,
		padColor = rgb(48, 34, 36),
		padMaterial = Enum.Material.Basalt,
	},
	-- The dark edge: black-violet rock, a dark pad.
	EventHorizon = {
		rockColors = { rgb(62, 54, 82), rgb(48, 42, 64), rgb(76, 58, 98) },
		rockMaterial = Enum.Material.Slate,
		padColor = rgb(40, 36, 54),
		padMaterial = Enum.Material.Basalt,
	},
}

return table.freeze({
	ZONES = table.freeze(ZONES),

	-- A nest (docs/plans/ZONES.md): a rock with a flat top, a short pillar on it and a wide landing
	-- pad, wide enough to land on for a theft (user, 2026-11-08). The pad's rim and the cradle the
	-- egg lies in take the colour of the nest's guardian (GuardianLooks.POSTS), seen from afar.
	-- Studs; the rock's width is the nest's size (WorldConfig.NEST_ASTEROID_MIN/MAX_SIZE).
	NEST = table.freeze({
		-- The rock's shape against its width: flattened, a little longer one way.
		rockStretch = Vector3.new(1.15, 0.6, 1),
		pillarRadius = 2.4,
		pillarHeight = 2.2,
		padRadius = 7,
		padThickness = 0.8,
		rimThickness = 0.45,
		-- The cradle holds a large egg (decision 084).
		cradleRadius = 1.9,
		cradleThickness = 0.8,
		cradleMaterial = Enum.Material.SmoothPlastic,
		-- How high over the pad the egg's bottom floats.
		eggGap = 0.15,
	}),

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
