--!strict
-- How the station border looks (StationSize.BORDER_RADIUS): a faint force-field shell and a
-- glowing ring around its middle, so the line where guardians give up is plain to see from both
-- sides. During the solar storm it turns red and the shell thickens: nobody gets past it then.
-- The server builds it (WorldService); each client recolors it for the storm.

return table.freeze({
	-- The border's folder in the world, tagged so clients find it.
	TAG = "StationBorder",
	SHELL_NAME = "Shell",
	RING_SEGMENTS = 96,
	RING_THICKNESS = 1.5,

	-- Calm: green and barely there.
	COLOR = Color3.fromRGB(90, 255, 170),
	SHELL_TRANSPARENCY = 0.93,
	-- Storm: red, a shell you cannot miss, a thicker ring.
	STORM_COLOR = Color3.fromRGB(255, 60, 50),
	STORM_SHELL_TRANSPARENCY = 0.55,
	STORM_RING_SCALE = 2.5,
	-- How long the change of look takes, seconds.
	FADE_SECONDS = 0.8,
	-- From inside, a sphere's own shell does not show, so in the storm a wall of the force field
	-- appears on the border right ahead of a player flying at it: a disc this wide, studs,
	-- showing from this far, studs, and solid up to this transparency at the very edge.
	WALL_DIAMETER = 80,
	WALL_THICKNESS = 0.4,
	WALL_SHOW_DISTANCE = 45,
	WALL_MIN_TRANSPARENCY = 0.2,
})
