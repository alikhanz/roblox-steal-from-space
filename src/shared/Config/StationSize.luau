--!strict
-- The station's size, and every distance that follows from it. One number is set by hand,
-- PLATFORM_RADIUS; the rest is a chain: the dome from the platform, the border from the dome,
-- and the map (ZoneConfig, WorldConfig) from the border. Change the platform, and the dome, the
-- line where guardians stop, the solar storm's edge, the spawn, the bays and the zones all move
-- together. Plain numbers, so the balance calculator and tests load it in Lune; StationConfig
-- builds the station's shapes from it.

-- The platform's radius, studs.
local PLATFORM_RADIUS = 60
-- The dome over the platform, this many times the platform.
local DOME_RADIUS = PLATFORM_RADIUS * 1.5
-- The station border, from the dome center, this many times the dome. Guardians never cross
-- it, a chase ends once the thief is inside, and the solar storm keeps everyone within it.
local BORDER_RADIUS = DOME_RADIUS * 5 / 3

return table.freeze({
	PLATFORM_RADIUS = PLATFORM_RADIUS,
	DOME_RADIUS = DOME_RADIUS,
	BORDER_RADIUS = BORDER_RADIUS,
	-- The spawn: halfway from the platform center to its edge.
	SPAWN_DISTANCE = PLATFORM_RADIUS * 0.5,
	-- Bays stand on this ring around the platform center, facing inward.
	BAY_RING_RADIUS = PLATFORM_RADIUS * 0.7,
})
