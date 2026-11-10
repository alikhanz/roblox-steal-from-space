--!strict
-- Where the coin board stands on the platform and what its stand looks like: a tall navy panel
-- on two pearl legs over a kiosk's base, in the kiosks' circle (decision 087).

local StationLooks = require("./StationLooks")
local StationShape = require("./StationShape")

-- The coin board takes the kiosks' circle's spare place, facing out like them (decision 087).
local ANGLE = StationShape.kioskAngle(StationLooks.COIN_BOARD_SLOT)
local OUTWARD = Vector3.new(math.cos(ANGLE), 0, math.sin(ANGLE))

return table.freeze({
	-- From the platform center, on the floor.
	POSITION = OUTWARD * StationShape.KIOSK_CIRCLE_RADIUS,
	FACING = OUTWARD,

	-- Wide enough for a 20-letter display name next to the coins.
	PANEL_SIZE = Vector3.new(12, 12, 0.6),
	-- The panel's bottom edge above the floor.
	PANEL_LIFT = 1.5,
	PANEL_COLOR = StationLooks.NAVY_COLOR,
	TRIM_COLOR = Color3.fromRGB(255, 214, 90),
	TRIM_THICKNESS = 0.3,
	LEG_SIZE = Vector3.new(0.6, 1.5, 0.6),
	LEG_COLOR = StationLooks.PEARL_COLOR,
	-- It stands on a kiosk's base and glowing ring (StationLooks.KIOSK), the ring in the trim's gold.
	BASE_COLOR = StationLooks.NAVY_COLOR,

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
	-- The ring's screens (StationShape.SCREEN_*): drawn coarse, so the letters stand big, and
	-- far enough to show from every island.
	SCREEN_PIXELS_PER_STUD = 18,
	SCREEN_MAX_DISTANCE = 800,
})
