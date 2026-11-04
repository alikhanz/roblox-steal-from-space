--!strict
-- How the meteor shower looks: the burning streak of a falling meteor and the crater it leaves
-- (a nest with a meteor egg). The egg's own flames are in EggLooks.METEOR. Greybox; the real look
-- comes with the art pass.

return table.freeze({
	STREAK = table.freeze({
		color = Color3.fromRGB(255, 140, 40),
		-- How high above its crater a meteor starts, studs.
		height = 400,
		seconds = 1.4,
		width = 3,
	}),
	-- A scorched rock, smaller than the nest asteroids, with a glow while it is fresh.
	CRATER = table.freeze({
		rockSize = 14,
		rockColor = Color3.fromRGB(58, 44, 40),
		rockMaterial = Enum.Material.Basalt,
		glowColor = Color3.fromRGB(255, 120, 40),
		glowRange = 24,
		glowBrightness = 2,
	}),
})
