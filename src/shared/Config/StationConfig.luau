--!strict
-- Station layout. The dome sits on the platform like a bubble; the station zone (walking with
-- gravity) is the column right above the platform, under the dome; everything else is open space.
-- The sizes all come from StationSize (one number sets the station's size).

local StationSize = require("./StationSize")
local Zones = require("../Domain/Zones")

-- Top surface of the platform, the station's reference point.
local PLATFORM_CENTER = Vector3.zero
local PLATFORM_RADIUS = StationSize.PLATFORM_RADIUS
local PLATFORM_THICKNESS = 4
local RIM_WIDTH = 2
local DOME_RADIUS = StationSize.DOME_RADIUS

-- Raise the dome so its sphere meets the platform exactly at the rim.
local domeRise = math.sqrt(DOME_RADIUS ^ 2 - (PLATFORM_RADIUS + RIM_WIDTH) ^ 2)

local STATION: Zones.Station = {
	domeCenter = PLATFORM_CENTER + Vector3.yAxis * domeRise,
	domeRadius = DOME_RADIUS,
	platformCenter = PLATFORM_CENTER,
	platformRadius = PLATFORM_RADIUS,
	floorY = PLATFORM_CENTER.Y - PLATFORM_THICKNESS,
}

return table.freeze({
	STATION = table.freeze(STATION),
	PLATFORM_CENTER = PLATFORM_CENTER,
	PLATFORM_RADIUS = PLATFORM_RADIUS,
	PLATFORM_THICKNESS = PLATFORM_THICKNESS,
	RIM_WIDTH = RIM_WIDTH,
	-- Studs past the boundary needed to switch between walking and flying (see Zones.nextInSpace).
	ZONE_MARGIN = 3,
	-- The hull under the platform hides the part of the dome sphere that pokes out below.
	HULL_STEPS = 4,
	-- The station border (StationSize), from the dome center, studs: drawn as a faint shell with
	-- a glowing ring.
	BORDER_RADIUS = StationSize.BORDER_RADIUS,
	SPAWN_OFFSET = Vector3.new(0, 0.5, StationSize.SPAWN_DISTANCE),
	BAY_RING_RADIUS = StationSize.BAY_RING_RADIUS,
})
