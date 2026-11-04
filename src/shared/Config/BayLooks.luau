--!strict
-- How bays look and where their parts stand. Positions are in a bay's own frame: X to the right,
-- -Z toward the platform center, Y up from the platform floor. Pure numbers live in BayConfig.

local ServerConfig = require("./ServerConfig")

-- Bays stand on a ring around the platform center, each facing inward.
local RING_RADIUS = 42
local BAY_COUNT = ServerConfig.MAX_PLAYERS

-- Pods stand in two tiers of three rows: the lower tier on the floor fills first, the upper
-- one floats right above it, so 30 pods fit in the footprint of the bay.
local POD_TIERS = 2
local POD_ROWS = 3
local PODS_PER_ROW = 5
local POD_SPACING = 3.2
-- Front row (toward the center) to back row, bay-local Z.
local POD_ROW_Z = { -2, -5, -8 }
-- How far above the lower tier the upper one stands, studs: a pod's stand and glass, plus air.
local POD_TIER_HEIGHT = 4.4

return table.freeze({
	RING_RADIUS = RING_RADIUS,
	BAY_COUNT = BAY_COUNT,

	BASE_SIZE = Vector3.new(26, 0.4, 18),
	BASE_COLOR = Color3.fromRGB(44, 50, 72),
	EDGE_COLOR = Color3.fromRGB(90, 200, 255),

	-- The sign post at the back of the bay, where the owner's name hangs.
	SIGN_POSITION = Vector3.new(0, 4, 7.5),
	SIGN_SIZE = Vector3.new(6, 1.2, 0.4),
	-- An invisible anchor over the pods for the pods' sign (count, price, buy button), above the
	-- upper tier.
	PODS_SIGN_POSITION = Vector3.new(0, 9.5, -5),

	-- The incubator: a glowing disc where delivered eggs lie in a ring.
	INCUBATOR_POSITION = Vector3.new(0, 0.3, 3.5),
	INCUBATOR_RADIUS = 4.5,
	INCUBATOR_THICKNESS = 0.6,
	INCUBATOR_COLOR = Color3.fromRGB(255, 170, 60),
	-- Rare eggs still shine in the incubator, at this share of their light.
	INCUBATOR_GLOW_SCALE = 0.2,
	-- Eggs lie on this ring inside the incubator; more eggs than slots go round again, higher.
	EGG_RING_RADIUS = 3,
	EGG_RING_SLOTS = 10,
	EGG_STACK_HEIGHT = 1.4,

	POD_TIERS = POD_TIERS,
	POD_TIER_HEIGHT = POD_TIER_HEIGHT,
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

	-- The trainer zone beside the bay (its place and size are in BayConfig.TRAINER_PAD): only
	-- an outline on the station floor for now, a dark disc inside a glowing ring. Placeholder:
	-- the real trainer, its animation and effects come with the art pass.
	TRAINER_HEIGHT = 0.1,
	TRAINER_COLOR = Color3.fromRGB(44, 50, 72),
	TRAINER_RING_WIDTH = 0.35,
	TRAINER_RING_HEIGHT = 0.06,
	TRAINER_RING_COLOR = Color3.fromRGB(255, 214, 90),

	-- Aliens with no pod wait along the sides of the bay.
	FLOOR_SPOT_X = 11,
	FLOOR_SPOT_Z_START = -6,
	FLOOR_SPOT_SPACING = 2.4,
	FLOOR_SPOTS_PER_SIDE = 6,
})
