--!strict
-- How bays look and where their parts stand. Positions are in a bay's own frame: X to the right,
-- -Z toward the platform center, Y up from the platform floor. Pure numbers live in BayConfig.

local ServerConfig = require("./ServerConfig")

-- Bays stand on a ring around the platform center, each facing inward.
local RING_RADIUS = 42
local BAY_COUNT = ServerConfig.MAX_PLAYERS

local POD_ROWS = 2
local PODS_PER_ROW = 6
local POD_SPACING = 3.2
-- Front row (toward the center) and back row, bay-local Z.
local POD_ROW_Z = { -2, -5.5 }

return table.freeze({
	RING_RADIUS = RING_RADIUS,
	BAY_COUNT = BAY_COUNT,

	BASE_SIZE = Vector3.new(26, 0.4, 18),
	BASE_COLOR = Color3.fromRGB(44, 50, 72),
	EDGE_COLOR = Color3.fromRGB(90, 200, 255),

	-- The sign post at the back of the bay, where the owner's name hangs.
	SIGN_POSITION = Vector3.new(0, 4, 7.5),
	SIGN_SIZE = Vector3.new(6, 1.2, 0.4),

	-- The incubator: a glowing disc where delivered eggs lie in a ring.
	INCUBATOR_POSITION = Vector3.new(0, 0.3, 3.5),
	INCUBATOR_RADIUS = 4.5,
	INCUBATOR_THICKNESS = 0.6,
	INCUBATOR_COLOR = Color3.fromRGB(255, 170, 60),
	-- Eggs lie on this ring inside the incubator; more eggs than slots go round again, higher.
	EGG_RING_RADIUS = 3,
	EGG_RING_SLOTS = 10,
	EGG_STACK_HEIGHT = 1.4,

	POD_ROWS = POD_ROWS,
	PODS_PER_ROW = PODS_PER_ROW,
	POD_SPACING = POD_SPACING,
	POD_ROW_Z = table.freeze(POD_ROW_Z),
	POD_STAND_RADIUS = 1.3,
	POD_STAND_HEIGHT = 0.4,
	POD_STAND_COLOR = Color3.fromRGB(120, 130, 160),
	POD_GLASS_HEIGHT = 3.4,
	POD_GLASS_COLOR = Color3.fromRGB(140, 220, 255),
	POD_GLASS_TRANSPARENCY = 0.65,

	-- Aliens with no pod wait along the sides of the bay.
	FLOOR_SPOT_X = 11,
	FLOOR_SPOT_Z_START = -6,
	FLOOR_SPOT_SPACING = 2.4,
	FLOOR_SPOTS_PER_SIDE = 6,
})
