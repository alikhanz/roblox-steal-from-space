--!strict
-- How the central station looks (decision 087): colours and materials of its floor, dome, hull,
-- ring and struts, and its capsule kiosks. The shape is StationShape's; World/StationModel and
-- World/KioskModel build it. The steel is the station's grey-blue, shared with the island
-- terminals (BayLooks.TERMINAL_*); the kiosks wear the robot pets' pearl and the terminals' navy.

local ShopConfig = require("./ShopConfig")
local StationShape = require("./StationShape")

local SCALE = StationShape.SCALE

export type KioskId = "Jetpacks" | "Store" | "Quests" | "Gift"

export type Kiosk = {
	read id: KioskId,
	-- Its place in the circle (StationShape.kioskAngle).
	read slot: number,
	read color: Color3,
}

-- The kiosks in the circle round the coin board, in the ring banner's order too. The client gives
-- each its name, icon and window (KioskController).
local KIOSKS: { Kiosk } = {
	{ id = "Jetpacks", slot = 1, color = Color3.fromRGB(255, 140, 60) },
	{ id = "Store", slot = 2, color = Color3.fromRGB(165, 120, 255) },
	{ id = "Quests", slot = 3, color = Color3.fromRGB(60, 230, 190) },
	{ id = "Gift", slot = 4, color = Color3.fromRGB(255, 110, 190) },
}

return table.freeze({
	KIOSKS = table.freeze(KIOSKS),
	-- Kiosk models carry this tag and their id in the attribute.
	KIOSK_TAG = "Kiosk",
	KIOSK_ATTRIBUTE = "Kiosk",
	-- Parts of a kiosk the client draws on: the badge's disc (icon), the name plate (name), the
	-- hologram in the opening (icon); the prompt hangs on a point at the counter
	-- (ShopConfig.PROMPT_POINT_NAME).
	KIOSK_BADGE_NAME = "Badge",
	KIOSK_PLATE_NAME = "Plate",
	KIOSK_HOLO_NAME = "Holo",
	KIOSK_PROMPT_DISTANCE = ShopConfig.PROMPT_DISTANCE,
	-- A kiosk's icon (on its badge, in its hologram, on the ring's banner) is white tinted this far
	-- towards the kiosk's colour.
	KIOSK_ICON_TINT = 0.35,

	PEARL_COLOR = Color3.fromRGB(237, 239, 246),
	PEARL_MATERIAL = Enum.Material.SmoothPlastic,
	NAVY_COLOR = Color3.fromRGB(28, 36, 66),

	-- A kiosk's parts outside its three meshes (World/StationKit: pearl, dark, glow), in its frame (X
	-- right, Y up from the floor, -Z out of its front), as assets/blender/station/station_kit.py
	-- models them (concept: concept_kiosks.py, direction "pod"). Base, glow and counter are also the
	-- greybox without the kit.
	KIOSK = table.freeze({
		baseRadius = 5.2 * SCALE,
		baseHeight = 0.7 * SCALE,
		glowRadius = StationShape.KIOSK_FOOTPRINT_RADIUS,
		glowHeight = 0.3 * SCALE,
		counterCenter = Vector3.new(0, 2.0, -3.4) * SCALE,
		counterSize = Vector3.new(6.6, 2.6, 2.0) * SCALE,
		-- The prompt's point: at the counter's front edge, this high over its top, at the height of
		-- a player's head against the dark opening (at the counter's foot it read badly on the pearl
		-- and sat too low; the user's pick, 2026-11-10).
		promptAboveCounter = 1.3 * SCALE,
		-- The hologram plate in the opening.
		holoCenter = Vector3.new(0, 6.6, -1.9) * SCALE,
		holoSize = Vector3.new(4.0, 3.6, 0.2) * SCALE,
		holoTransparency = 0.55,
		lightRange = 12 * SCALE,
		lightBrightness = 1,
		-- The round badge over the shell (its ring is in the glow) and the name plate under it (its
		-- frame too).
		badgeCenter = Vector3.new(0, 18.8, -0.4) * SCALE,
		badgeRadius = 2.45 * SCALE,
		badgeThickness = 0.2 * SCALE,
		plateCenter = Vector3.new(0, 15.2, -0.4) * SCALE,
		plateSize = Vector3.new(10, 2, 0.5) * SCALE,
	}),

	FLOOR_COLOR = Color3.fromRGB(70, 76, 98),
	FLOOR_MATERIAL = Enum.Material.DiamondPlate,
	-- The glowing rim round the platform.
	RIM_COLOR = Color3.fromRGB(90, 200, 255),
	-- The station's dome, a touch brighter and greener than the islands' so it stands apart.
	DOME_COLOR = Color3.fromRGB(120, 225, 255),
	DOME_TRANSPARENCY = 0.75,

	STEEL_COLOR = Color3.fromRGB(149, 155, 173),
	STEEL_LIGHT_COLOR = Color3.fromRGB(222, 225, 235),
	STEEL_DARK_COLOR = Color3.fromRGB(97, 101, 122),
	STEEL_MATERIAL = Enum.Material.Metal,

	-- The hull's glowing bands and nozzles, the ring's trims: the rim's cyan, so the station reads as
	-- one thing.
	GLOW_COLOR = Color3.fromRGB(90, 200, 255),

	-- A ring screen under its drawing: dark with a faint blue (not Glass: Roblox hides see-through
	-- things behind Glass).
	SCREEN_COLOR = Color3.fromRGB(22, 32, 96),
	SCREEN_MATERIAL = Enum.Material.SmoothPlastic,
	SCREEN_TRANSPARENCY = 0,
	-- The ring's screens, outside (to the islands) and inside (to the platform), carry this tag;
	-- each client runs the kiosks' names along them (KioskController, UI/RingBanner).
	BANNER_TAG = "RingBanner",
	-- The banner on a screen: pixels per stud (coarse, so the letters stand big), seen this far
	-- (from every island), one kiosk's name and icon this share of the screen's width, sliding by
	-- one in this many seconds.
	BANNER = table.freeze({
		pixelsPerStud = 18,
		maxDistance = 800,
		itemShare = 0.75,
		secondsPerItem = 3,
	}),
})
