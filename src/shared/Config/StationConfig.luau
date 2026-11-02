--!strict
-- Station layout. The dome is the boundary between walking (inside) and flying (outside).

local Zones = require("../Domain/Zones")

local DOME: Zones.Dome = {
	center = Vector3.zero,
	radius = 90,
}

return table.freeze({
	DOME = table.freeze(DOME),
	-- The walkable platform sits inside the dome with its top surface at the dome center.
	PLATFORM_RADIUS = 60,
	PLATFORM_THICKNESS = 4,
	SPAWN_OFFSET = Vector3.new(0, 0.5, 30),
})
