--!strict
-- How the star serpent looks: a glowing head and a long body of segments that trails it (the
-- clients draw the body, Domain/SerpentBody). Greybox; the real model comes with the art pass.

return table.freeze({
	HEAD = table.freeze({
		size = Vector3.new(10, 8, 14),
		color = Color3.fromRGB(70, 50, 160),
		eyeColor = Color3.fromRGB(255, 240, 120),
		eyeSize = Vector3.new(1.6, 1.6, 0.6),
		glowColor = Color3.fromRGB(150, 120, 255),
		glowRange = 40,
		glowBrightness = 3,
	}),
	BODY = table.freeze({
		segments = 18,
		-- Distance between segment centers along the path, studs.
		spacing = 6,
		-- The first segment's size and the last one's; the ones between taper evenly.
		firstSize = 9,
		lastSize = 3,
		colors = table.freeze({ Color3.fromRGB(70, 50, 160), Color3.fromRGB(110, 80, 220) }),
		-- Glowing specks on every few segments: the stars it is named after.
		starEvery = 3,
		starColor = Color3.fromRGB(255, 250, 200),
	}),
})
