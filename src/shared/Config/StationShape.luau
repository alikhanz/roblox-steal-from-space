--!strict
-- The central station's shape in numbers (decision 087, docs/plans/STATION.md): the cone hull under
-- the platform, the ring of screens round the dome, one facing each island, and the struts holding
-- the ring up. Everything follows StationSize's chain: the kit of meshes (World/StationKit) is
-- modelled for a 60-stud platform, and a bigger or smaller station scales every piece by SCALE.
-- Plain numbers, so tests load it in Lune; StationLooks has the colours and materials,
-- World/StationModel builds it.

local StationSize = require("./StationSize")

-- The platform the kit is modelled for (assets/blender/station/station_kit.py).
local MODELLED_PLATFORM_RADIUS = 60
local SCALE = StationSize.PLATFORM_RADIUS / MODELLED_PLATFORM_RADIUS

-- The hull: a cone from under the rim down to a blunt tip with engine pods round it.
local HULL_TOP_RADIUS = StationSize.PLATFORM_RADIUS + StationSize.RIM_WIDTH / 2
local HULL_BOTTOM_RADIUS = 16 * SCALE
local HULL_DEPTH = 40 * SCALE

-- The ring: a band round the dome, clear of it by RING_GAP, its middle 0.3 of the dome's radius
-- above the dome's centre (where the dome is still nearly at its widest).
local RING_GAP = 1 * SCALE
local RING_THICKNESS = 3 * SCALE
local RING_OUTER_RADIUS = StationSize.DOME_RADIUS + RING_GAP + RING_THICKNESS
local RING_HEIGHT = 14 * SCALE
local RING_LIFT = StationSize.DOME_RISE + StationSize.DOME_RADIUS * 0.3

-- The circle of kiosks: the spawn at +Z (StationConfig.SPAWN_OFFSET) falls between two of them.
local KIOSK_SLOTS = 5
local SPAWN_ANGLE = math.pi / 2
local KIOSK_FIRST_ANGLE = SPAWN_ANGLE + math.pi / KIOSK_SLOTS

-- The angle round the station (as the islands': from +X towards +Z) of kiosk place `slot` (1-based).
local function kioskAngle(slot: number): number
	return KIOSK_FIRST_ANGLE + (slot - 1) / KIOSK_SLOTS * 2 * math.pi
end

-- The cone's radius `depth` below the hull's top.
local function hullRadiusAt(depth: number): number
	return HULL_TOP_RADIUS + (HULL_BOTTOM_RADIUS - HULL_TOP_RADIUS) * depth / HULL_DEPTH
end

return table.freeze({
	SCALE = SCALE,

	HULL_TOP_RADIUS = HULL_TOP_RADIUS,
	HULL_BOTTOM_RADIUS = HULL_BOTTOM_RADIUS,
	HULL_DEPTH = HULL_DEPTH,
	hullRadiusAt = hullRadiusAt,
	-- Glowing bands round the cone, at these fractions of its depth (in the hull's glow; without the
	-- kit, discs a little wider than the cone there, so only their edge shows).
	HULL_BANDS = table.freeze({ 0.25, 0.6 }),
	HULL_BAND_THICKNESS = 0.8 * SCALE,
	HULL_BAND_OVERHANG = 0.3 * SCALE,
	-- The engine pods round the tip (in the hull's mesh, their nozzles in its glow).
	ENGINE_COUNT = 8,

	-- One segment, one screen, one island: segment k faces island k (StationConfig.ISLAND_FRAMES).
	RING_SEGMENTS = StationSize.ISLAND_COUNT,
	RING_OUTER_RADIUS = RING_OUTER_RADIUS,
	RING_INNER_RADIUS = RING_OUTER_RADIUS - RING_THICKNESS,
	RING_HEIGHT = RING_HEIGHT,
	-- The ring's middle, above the platform's top.
	RING_LIFT = RING_LIFT,
	-- The glowing trims along the ring's top and bottom outer edges: their square section.
	RING_TRIM_SIZE = 0.6 * SCALE,
	-- A screen in its segment's niche: the niche's flat back from the ring's centre, the screen
	-- just in front of it.
	SCREEN_WIDTH = 33.4 * SCALE,
	SCREEN_HEIGHT = 10.9 * SCALE,
	SCREEN_BACK = 92 * SCALE,
	SCREEN_THICKNESS = 0.2 * SCALE,

	-- Struts from under the rim up to the ring's underside, between the screens.
	PYLON_COUNT = 4,
	-- The first strut's angle round the station (as the islands': from +X towards +Z); the rest
	-- follow evenly. Half a screen's turn, so a strut never stands in front of a screen.
	PYLON_FIRST_ANGLE = math.pi / StationSize.ISLAND_COUNT,
	PYLON_FOOT_RADIUS = HULL_TOP_RADIUS,
	PYLON_FOOT_DROP = 3 * SCALE,
	PYLON_TOP_RADIUS = RING_OUTER_RADIUS - 1.5 * SCALE,
	PYLON_TOP_LIFT = RING_LIFT - RING_HEIGHT / 2,

	-- The kiosks and the coin board stand in a circle on the platform, facing out, so whichever
	-- side a player lands on, a front greets them (decision 087).
	KIOSK_SLOTS = KIOSK_SLOTS,
	KIOSK_CIRCLE_RADIUS = StationSize.PLATFORM_RADIUS * 0.6,
	-- The station's spawn, round the station; the circle starts half a step past it.
	SPAWN_ANGLE = SPAWN_ANGLE,
	kioskAngle = kioskAngle,
	-- A kiosk's footprint: its base with the glowing ring under it.
	KIOSK_FOOTPRINT_RADIUS = 5.45 * SCALE,
})
