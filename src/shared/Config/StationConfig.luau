--!strict
-- Station layout. The dome sits on the platform like a bubble; the station zone (walking with
-- gravity) is the column right above the platform, under the dome; everything else is open space.

local Zones = require("../Domain/Zones")

-- Top surface of the platform, the station's reference point.
local PLATFORM_CENTER = Vector3.zero
local PLATFORM_RADIUS = 60
local PLATFORM_THICKNESS = 4
local RIM_WIDTH = 2
local DOME_RADIUS = 90

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
	-- The station border: a sphere around the dome, drawn as a faint shell with a glowing ring.
	-- Guardians never cross it and a chase ends once the thief is inside. Kept well short of
	-- the nearest nests (the Debris Belt starts 190 studs out), studs from the dome center.
	BORDER_RADIUS = 150,
	SPAWN_OFFSET = Vector3.new(0, 0.5, 30),
})
