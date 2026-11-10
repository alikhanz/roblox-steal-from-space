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
	-- A row with room to spare spreads its places, up to this much air between two (user,
	-- 2026-11-10: the first aliens stand apart, but as a group behind the incubator).
	airMax = 10,
	rowSpread = 2,
	minSqueeze = 0.5,
	squeezeStep = 0.02,
})

-- The places' terminal stands at the horseshoe's end on the right of a player walking in (-X),
-- its back to the places and its screen across the entrance's path (user, 2026-11-10): it reads
-- as the places' own. This far from the island's center along the horseshoe's edge, and its middle
-- this far off the edge, into the entrance's wedge (the stand's half depth and a little air).
local PLACES_TERMINAL_ALONG = 26
local PLACES_TERMINAL_OFF_EDGE = 2.5
-- Half the entrance's wedge, radians: the horseshoe's edge runs this far from the entrance's line.
local WEDGE = (2 * math.pi - PLACES.arc) / 2
-- The edge's direction from the center, and its normal into the wedge (toward the path).
local PLACES_EDGE = Vector3.new(-math.sin(WEDGE), 0, -math.cos(WEDGE))
local PLACES_EDGE_INWARD = Vector3.new(math.cos(WEDGE), 0, -math.sin(WEDGE))
local PLACES_TERMINAL_POSITION = PLACES_EDGE * PLACES_TERMINAL_ALONG + PLACES_EDGE_INWARD * PLACES_TERMINAL_OFF_EDGE

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
	-- A place with an alien is at least this wide, studs (docs/design/screens/island.md): a small
	-- alien stands on a roomy pad, so the first ones do not jostle; a bigger one gets its own width.
	MIN_PLACE_WIDTH = 6,
	-- A new alien on a place reshapes the layout: the places and their aliens glide to their new
	-- spots in this long, seconds, rather than jump (2026-11-10).
	LAYOUT_GLIDE_SECONDS = 0.6,
	-- A hatch (docs/design/screens/buttons.md): the egg bursts in its capsule, a flash of light
	-- and stars in its colour (drawn only this close to the camera, studs), and the new alien
	-- pops onto its place from a share of its size, a little past full and back, in this long.
	HATCH_BURST = table.freeze({
		seconds = 0.6,
		stars = 26,
		starSize = 0.9,
		starSpeed = 9,
		lightRange = 14,
		lightBrightness = 4,
		maxDistance = 120,
	}),
	ALIEN_POP = table.freeze({
		from = 0.6,
		seconds = 0.35,
		-- How new an alien must be to pop (since the server built it), seconds: one streaming in
		-- later just appears.
		freshSeconds = 1.5,
	}),

	-- Terminals (docs/design/screens/terminals.md): a stand with a tilted screen beside each zone,
	-- in the entrance's wedge, the screen toward the spawn (the places' one: across the path, see
	-- PLACES_TERMINAL_ALONG). The incubator's stands a little to the left of the path for a player
	-- walking in, so the incubator shows past it (user, 2026-11-10).
	PLACES_TERMINAL_POSITION = PLACES_TERMINAL_POSITION,
	PLACES_TERMINAL_FACES = PLACES_TERMINAL_POSITION + PLACES_EDGE_INWARD,
	INCUBATOR_TERMINAL_POSITION = Vector3.new(5, 0, -17.5),
	TRAINER_TERMINAL_POSITION = Vector3.new(17, 0, -46),
	TERMINAL_FACES = Vector3.new(0, 0, -StationSize.ISLAND_SPAWN_DISTANCE),
	-- A holo projector (version 2 of the brief, user 2026-11-10): a knee-high console on a round
	-- foot, an emitter on its cap sloped toward the player, and over it a screen of light hanging in
	-- the air in a thin glowing frame, a cone of light from the emitter up to it. The eye passes
	-- over the console, so what stands behind a terminal shows past it.
	TERMINAL_FOOT_RADIUS = 1.9,
	TERMINAL_FOOT_HEIGHT = 0.3,
	-- The console's rounded shapes (World/TerminalKit, sizes as modelled in
	-- assets/blender/terminals/terminal_kit.py: keep them in step): the body on the foot, the cap
	-- on the body, sunk a little into it and sloped toward the player, the emitter's ring on the cap.
	TERMINAL_CONSOLE = table.freeze({
		body = Vector3.new(3, 1.3, 2.2),
		cap = Vector3.new(2.6, 0.3, 1.8),
		capSink = 0.1,
		capTilt = 12,
		emitterRadius = 0.7,
		emitterThickness = 0.17,
		-- The lens inside the ring: a glowing disc in a lighter shade of the zone's colour.
		lensRadius = 0.55,
		lensThickness = 0.08,
		-- Neon under bloom whitens on its own: a little lighter is enough (0.6 read as a white spot).
		lensLighten = 0.2,
	}),
	-- A glowing stripe across the console's front, this high above the foot: on the flat of the
	-- face, inside its rounded edges.
	TERMINAL_STRIPE_SIZE = Vector3.new(1.8, 0.14, 0.08),
	TERMINAL_STRIPE_HEIGHT = 0.65,
	-- Wide and big: on a phone the price must read from a few steps away (user, 2026-11-08). Its
	-- width to height is the screen canvas's (UI/TerminalScreen).
	TERMINAL_SCREEN_SIZE = Vector3.new(6, 4, 0.1),
	-- The screen's center above the floor (a player's head), and its tilt back, degrees.
	TERMINAL_SCREEN_HEIGHT = 5,
	TERMINAL_SCREEN_TILT = 15,
	-- The screen itself is dim glass: it stays when the writing fades out far away, and from
	-- behind (where there is no writing).
	TERMINAL_SCREEN_COLOR = Color3.fromRGB(22, 32, 96),
	TERMINAL_SCREEN_TRANSPARENCY = 0.6,
	-- The thin glowing frame round the screen, and the lights at its corners (diameter), studs.
	TERMINAL_FRAME_WIDTH = 0.08,
	TERMINAL_CORNER_SIZE = 0.24,
	-- The cone of light from the lens to the screen's bottom edge: a Beam, narrow at the lens.
	TERMINAL_BEAM = table.freeze({
		width0 = 0.9,
		width1 = 5.4,
		transparency0 = 0.55,
		transparency1 = 0.85,
	}),
	-- The station's grey-blue steel (its hull, light cap and dark trim), so the terminal reads as the
	-- station's own kit.
	TERMINAL_HULL_COLOR = Color3.fromRGB(149, 155, 173),
	TERMINAL_CAP_COLOR = Color3.fromRGB(222, 225, 235),
	TERMINAL_FOOT_COLOR = Color3.fromRGB(97, 101, 122),

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
	-- Room for a large egg (decision 084), with a little air over it.
	CAPSULE_GLASS_HEIGHT = 4,
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

	-- The trainer zone (its place and size are in BayConfig.TRAINER_PAD): a glowing ring round
	-- the jetpack stand's platform, and its zone line.
	TRAINER_RING_WIDTH = 0.35,
	TRAINER_RING_HEIGHT = 0.06,
	TRAINER_RING_COLOR = Color3.fromRGB(255, 214, 90),
	-- The trainer's zone line, this far around the pad.
	TRAINER_ZONE_MARGIN = 2,

	-- The jetpack stand on the trainer's pad (docs/design/screens/jetpack-stand.md), in its own
	-- frame: -Z toward the island's center (where its rider faces), +Z behind. The platform is
	-- the pad (BayConfig.TRAINER_PAD), StandConfig.PLATFORM_HEIGHT high. Greybox.
	STAND_COLOR = Color3.fromRGB(58, 67, 112),
	STAND_RAIL_COLOR = Color3.fromRGB(90, 100, 143),
	-- The frame behind the rider: two pillars and a bar at back height.
	STAND_PILLAR_SIZE = Vector3.new(0.35, 4.8, 0.35),
	STAND_PILLAR_X = 1.4,
	STAND_FRAME_Z = 1.2,
	STAND_BAR_HEIGHT = 4.3,
	-- The rail in front, at the rider's hands.
	STAND_RAIL_X = 1.3,
	STAND_RAIL_Z = -1.3,
	STAND_RAIL_HEIGHT = 2.6,
	STAND_RAIL_THICKNESS = 0.24,
	-- The pilot lights at the foot of the pillars: lit while the stand is empty.
	STAND_PILOT_SIZE = 0.35,
	STAND_PILOT_HEIGHT = 0.9,
	STAND_PILOT_COLOR = Color3.fromRGB(95, 212, 255),
	-- The blast grate on the floor behind the stand: glows while the jetpack fires into it.
	STAND_GRATE_SIZE = Vector3.new(3.2, 0.08, 2.2),
	STAND_GRATE_Z = 3.4,
	STAND_GRATE_COLOR = Color3.fromRGB(40, 30, 30),
	STAND_GRATE_HOT_COLOR = Color3.fromRGB(255, 140, 50),

	-- The floor: a tray on the right of a player who walks in from the spawn, where aliens with no
	-- place stand, all small (the first guardian's size) until placed, in a grid filled from the
	-- entrance's side.
	PILE_CENTER = Vector3.new(-17, 0, -55),
	PILE_SIZE = Vector2.new(10, 14),
	PILE_COLUMNS = 4,
	PILE_SPACING = 2.3,
	PILE_COLOR = Color3.fromRGB(154, 163, 194),
	PILE_ALIEN_SCALE = 1,
	-- A floor alien wider than this share of the grid's step is made smaller to fit (wings and
	-- claws would reach into its neighbours).
	PILE_ALIEN_FILL = 0.9,
})
