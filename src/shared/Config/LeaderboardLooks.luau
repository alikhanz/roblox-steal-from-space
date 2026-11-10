--!strict
-- Where the coin board stands on the platform and what it looks like: the "crown" in the middle
-- of the kiosks' circle (decision 087) — pearl dais, pillar and screen backs, gold glow, navy
-- screens with the top drawn on them, a gold coin turning on top and a coin hologram turning round
-- the pillar. Its shape is StationShape's (BOARD_*).

local StationLooks = require("./StationLooks")

local GOLD = Color3.fromRGB(255, 200, 70)

return table.freeze({
	-- From the platform center, on the floor: the middle. The first screen faces the station's
	-- spawn (+Z), the rest a quarter turn apart.
	POSITION = Vector3.zero,

	PEARL_COLOR = StationLooks.PEARL_COLOR,
	PEARL_MATERIAL = StationLooks.PEARL_MATERIAL,
	PANEL_COLOR = StationLooks.NAVY_COLOR,
	GLOW_COLOR = GOLD,
	COIN_COLOR = GOLD,
	COIN_MATERIAL = Enum.Material.Metal,
	HOLO_TRANSPARENCY = 0.55,
	-- The coins turn once in this many seconds (on each client), while the camera is within
	-- COIN_TURN_DISTANCE studs of the board: farther, a coin ~10 studs across is under 0.6° of the
	-- view, and its turn is not seen (decision 101).
	COIN_TURN_SECONDS = 8,
	COIN_TURN_DISTANCE = 1000,

	-- The drawing on a screen: pixels per stud, and its colors.
	PIXELS_PER_STUD = 20,
	TITLE_COLOR = GOLD,
	ROW_COLOR = Color3.fromRGB(235, 238, 250),
	-- Gold, silver and bronze for the first three places.
	PLACE_COLORS = {
		GOLD,
		Color3.fromRGB(205, 214, 230),
		Color3.fromRGB(222, 150, 95),
	},
	-- The local player's own row.
	OWN_ROW_COLOR = Color3.fromRGB(120, 220, 255),
	-- The screens are drawn this far, studs: from every island (the far side of the farthest is
	-- about 500 off).
	MAX_DISTANCE = 1000,
	-- Farther than this from the board, the camera sees the top three big instead of the top ten.
	FAR_DISTANCE = 110,
	-- How often each client checks how far it is, seconds.
	FAR_CHECK_SECONDS = 0.5,
})
