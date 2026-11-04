--!strict
-- Where the coin board stands on the platform and what its greybox stand looks like: a tall
-- panel on two legs, facing the spawn.

return table.freeze({
	-- From the platform center, on the floor.
	POSITION = Vector3.new(-18, 0, 22),
	FACING = Vector3.new(1, 0, 0.3),

	-- Wide enough for a 20-letter display name next to the coins.
	PANEL_SIZE = Vector3.new(12, 12, 0.6),
	-- The panel's bottom edge above the floor.
	PANEL_LIFT = 1.5,
	PANEL_COLOR = Color3.fromRGB(30, 34, 52),
	TRIM_COLOR = Color3.fromRGB(255, 214, 90),
	TRIM_THICKNESS = 0.3,
	LEG_SIZE = Vector3.new(0.6, 1.5, 0.6),
	LEG_COLOR = Color3.fromRGB(44, 50, 72),

	-- The drawing on the panel: pixels per stud, and its colors.
	PIXELS_PER_STUD = 40,
	TITLE_COLOR = Color3.fromRGB(255, 214, 90),
	ROW_COLOR = Color3.fromRGB(235, 238, 250),
	-- Gold, silver and bronze for the first three places.
	PLACE_COLORS = {
		Color3.fromRGB(255, 214, 90),
		Color3.fromRGB(205, 214, 230),
		Color3.fromRGB(222, 150, 95),
	},
	-- The local player's own row.
	OWN_ROW_COLOR = Color3.fromRGB(120, 220, 255),
	-- The board is not drawn beyond this distance, studs.
	MAX_DISTANCE = 150,
})
