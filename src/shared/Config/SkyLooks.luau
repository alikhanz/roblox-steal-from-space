--!strict
-- How the space around the station looks and is lit (decision 076: Realistic lighting). The sky is
-- our own skybox of deep space (assets/blender/sky/space_sky.py): a band of nebula, nebula patches
-- in their own colours, stars, and landmarks to steer by spread round the sky, each unlike the
-- others (a ringed planet, a moon, an icy planet, a galaxy, a gas giant, a comet, a red planet, a
-- black hole; 2026-11-10). A sun shines from high up: under Realistic lighting only real
-- light sources light the world, and at night the pets, the station and the guardians stayed dim.
-- The planets in the skybox are lit from the same side as this sun (ClockTime, Latitude).
-- The server sets it up (WorldService).

return table.freeze({
	-- Roblox's sky faces; the render script names its PNGs the same way.
	SKYBOX = table.freeze({
		Ft = "rbxassetid://130429926323392",
		Bk = "rbxassetid://130145116580162",
		Lf = "rbxassetid://127694167782369",
		Rt = "rbxassetid://133943224998225",
		Up = "rbxassetid://130599228949167",
		Dn = "rbxassetid://96419562498417",
	}),
	-- The sun: mid-morning, 55° up. The skybox render uses its direction (Lighting:GetSunDirection()).
	CLOCK_TIME = 10,
	LATITUDE = 41.73,
	SUN_ANGULAR_SIZE = 14,

	BRIGHTNESS = 2.5,
	-- Shade, a cool violet like the sky; the lit side stays warm from the sun.
	AMBIENT = Color3.fromRGB(62, 60, 92),
	OUTDOOR_AMBIENT = Color3.fromRGB(96, 88, 140),
	COLOR_SHIFT_TOP = Color3.fromRGB(255, 236, 214),
	-- How much the sky's own colours light and reflect off the world (metal shows the nebula).
	ENVIRONMENT_DIFFUSE = 0.5,
	ENVIRONMENT_SPECULAR = 0.9,
	GLOBAL_SHADOWS = true,
})
