--!strict
-- Where the jetpack shop stands on the platform and what its greybox kiosk looks like: a counter,
-- a tall back panel and a glowing orb above the counter.

local StationConfig = require("./StationConfig")

return table.freeze({
	-- From the platform center, on the floor, in the station's size (18, 22 on a 60-stud
	-- platform); the kiosk faces the spawn.
	POSITION = Vector3.new(0.3, 0, 22 / 60) * StationConfig.PLATFORM_RADIUS,
	FACING = Vector3.new(-1, 0, 0.3),

	COUNTER_SIZE = Vector3.new(6, 3, 2),
	COUNTER_COLOR = Color3.fromRGB(44, 50, 72),
	PANEL_SIZE = Vector3.new(6, 7, 0.5),
	-- Behind the counter.
	PANEL_OFFSET = 2,
	PANEL_COLOR = Color3.fromRGB(30, 34, 52),
	TRIM_COLOR = Color3.fromRGB(255, 170, 60),
	TRIM_HEIGHT = 0.3,
	-- A glowing jetpack-colored orb floats over the counter.
	ORB_RADIUS = 0.9,
	ORB_HEIGHT = 4.4,
	ORB_COLOR = Color3.fromRGB(255, 140, 60),
	ORB_LIGHT_RANGE = 8,
	ORB_LIGHT_BRIGHTNESS = 0.6,
})
