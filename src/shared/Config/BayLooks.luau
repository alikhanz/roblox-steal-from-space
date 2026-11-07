--!strict
-- How a player's island looks inside and where everything on it stands (decision 068,
-- docs/design/screens/island.md). Positions are in the island's own frame: -Z toward the station
-- center (the entrance), X to the right when facing it (so to the left of a player walking in),
-- Y up from the island floor. Pure numbers live in
-- BayConfig. Greybox: the real looks come with the art pass.

local StationSize = require("./StationSize")

-- One bay on each island around the station (the islands' places are in StationConfig).
local BAY_COUNT = StationSize.ISLAND_COUNT
local RADIUS = StationSize.ISLAND_RADIUS

-- The places: a horseshoe of rows around the incubator, open toward the entrance; the layout
-- itself is Domain/PlaceLayout's.
local PLACES = table.freeze({
	inner = 20,
	-- The last row stays this far inside the island's edge.
	outer = RADIUS - 3,
	arc = math.rad(300),
	gap = 1.5,
	rowSpread = 2,
	minSqueeze = 0.5,
	squeezeStep = 0.02,
})

-- The incubator in the island's center: a low stand with up to 12 capsules round it.
local CAPSULE_RING_RADIUS = 8.5
local CAPSULE_RADIUS = 1.6

return table.freeze({
	BAY_COUNT = BAY_COUNT,

	EDGE_COLOR = Color3.fromRGB(90, 200, 255),
	-- Lines on the floor around each zone, studs.
	ZONE_LINE_WIDTH = 0.5,
	ZONE_LINE_HEIGHT = 0.06,
	-- The places' outline: arcs are drawn of straight pieces this many degrees long.
	ZONE_ARC_STEP_DEGREES = 5,

	-- The owner's sign: a board on two posts by the island's edge at the entrance, the name over
	-- it (seen from inside and from outside alike).
	SIGN_POSITION = Vector3.new(0, 0, -(RADIUS - 4)),
	SIGN_BOARD_SIZE = Vector3.new(14, 3, 0.6),
	SIGN_POST_HEIGHT = 3,
	SIGN_POST_SIZE = Vector3.new(0.6, 0, 0.6),
	SIGN_COLOR = Color3.fromRGB(44, 50, 72),

	PLACES = PLACES,
	PLACES_COLOR = Color3.fromRGB(62, 166, 255),
	-- A place's pad: a disc this much wider than its alien.
	PLACE_PAD_MARGIN = 0.4,
	PLACE_PAD_HEIGHT = 0.3,
	PLACE_PAD_COLOR = Color3.fromRGB(44, 50, 72),
	PLACE_RING_WIDTH = 0.3,
	-- A bought place with no alien: a small pad.
	EMPTY_PLACE_WIDTH = 2.6,
	-- An invisible anchor for the places' sign (count, price, buy button): over the space between
	-- the incubator and the first row.
	PLACES_SIGN_POSITION = Vector3.new(0, 8, 15),

	-- The incubator: a disc under the capsules; eggs in its slots lie in the capsules.
	INCUBATOR_POSITION = Vector3.zero,
	INCUBATOR_RADIUS = CAPSULE_RING_RADIUS + CAPSULE_RADIUS + 0.8,
	INCUBATOR_THICKNESS = 0.6,
	INCUBATOR_COLOR = Color3.fromRGB(255, 170, 60),
	-- The incubator's zone on the floor: a ring around the stand and the waiting eggs.
	INCUBATOR_ZONE_RADIUS = 15,
	-- Capsules stand in a ring; the first faces the entrance, the next ones alternate to either
	-- side of it.
	CAPSULE_RING_RADIUS = CAPSULE_RING_RADIUS,
	CAPSULE_POSITIONS = 12,
	CAPSULE_RADIUS = CAPSULE_RADIUS,
	CAPSULE_STAND_HEIGHT = 0.4,
	CAPSULE_GLASS_HEIGHT = 3.6,
	CAPSULE_STAND_COLOR = Color3.fromRGB(120, 130, 160),
	CAPSULE_GLASS_COLOR = Color3.fromRGB(140, 220, 255),
	CAPSULE_GLASS_TRANSPARENCY = 0.65,
	-- Rare eggs still shine in the incubator, at this share of their light.
	INCUBATOR_GLOW_SCALE = 0.2,
	-- A ready egg (its time has come, decision 059) shines with this light until it is hatched.
	READY_EGG_LIGHT_COLOR = Color3.fromRGB(255, 240, 150),
	READY_EGG_LIGHT_BRIGHTNESS = 3,
	READY_EGG_LIGHT_RANGE = 8,
	-- Eggs waiting for a slot lie on the floor around the incubator, from the entrance's side
	-- (decision 058), then on a wider ring.
	WAITING_RING_RADIUS = 12.5,
	WAITING_RING_SLOTS = 24,
	WAITING_RING_STEP = 2,

	-- The trainer zone (its place and size are in BayConfig.TRAINER_PAD): an outline on the
	-- floor, a dark disc inside a glowing ring. Placeholder: the real trainer comes with the art
	-- pass.
	TRAINER_HEIGHT = 0.1,
	TRAINER_COLOR = Color3.fromRGB(44, 50, 72),
	TRAINER_RING_WIDTH = 0.35,
	TRAINER_RING_HEIGHT = 0.06,
	TRAINER_RING_COLOR = Color3.fromRGB(255, 214, 90),
	-- The trainer's zone line, this far around the pad.
	TRAINER_ZONE_MARGIN = 2,

	-- The floor: a tray on the right of a player who walks in from the spawn, where aliens with no
	-- place stand, all small (the first guardian's size) until placed, in a grid filled from the
	-- entrance's side.
	PILE_CENTER = Vector3.new(-17, 0, -55),
	PILE_SIZE = Vector2.new(10, 14),
	PILE_COLUMNS = 4,
	PILE_SPACING = 2.3,
	PILE_COLOR = Color3.fromRGB(154, 163, 194),
	PILE_ALIEN_SCALE = 1,
})
