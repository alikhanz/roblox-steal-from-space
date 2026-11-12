--!strict
-- How a player's island looks inside and where everything on it stands (decision 068,
-- docs/design/screens/island.md). Positions are in the island's own frame: -Z toward the station
-- center (the entrance), X to the right when facing it (so to the left of a player walking in),
-- Y up from the island floor. Pure numbers live in
-- BayConfig. Greybox: the real looks come with the art pass.

local IncubatorShape = require("./IncubatorShape")
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

-- The shelf's origin (Config/ShelfShape) on the island: right of the spawn, in the entrance's
-- wedge, clear of the places' horseshoe.
local SHELF_POSITION = Vector3.new(-21, 0, -52)

-- The incubator's colour: its terminal, its line on the floor, its dais's light and a capsule whose
-- egg warms; and a capsule whose egg is ready to hatch (the hatch action's green,
-- docs/design/DESIGN.md). Deep and saturated: on the islands Neon of a lighter orange
-- (255, 170, 60) read yellow beside the trainer's, and a light green (90, 240, 110) white
-- (Studio, 2026-11-10).
local INCUBATOR_COLOR = Color3.fromRGB(255, 80, 10)
local CAPSULE_READY_COLOR = Color3.fromRGB(20, 200, 60)

return table.freeze({
	BAY_COUNT = BAY_COUNT,

	EDGE_COLOR = Color3.fromRGB(90, 200, 255),
	-- Lines on the floor around each zone, studs.
	ZONE_LINE_WIDTH = 0.5,
	ZONE_LINE_HEIGHT = 0.06,
	-- The places' outline: arcs are drawn of straight pieces this many degrees long.
	ZONE_ARC_STEP_DEGREES = 5,

	-- The owner's sign: a board on two posts in the entrance, the name over it (seen from inside
	-- and from outside alike). Twice the old size, read from afar (user, 2026-11-12:
	-- docs/design/screens/markers.md); the dome is low near the edge (5 studs over the floor 4
	-- studs in), so the board stands deeper in, under it.
	SIGN_POSITION = Vector3.new(0, 0, -(RADIUS - 21)),
	SIGN_BOARD_SIZE = Vector3.new(28, 6, 0.6),
	SIGN_POST_HEIGHT = 4,
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
	-- The console: the body on the foot, the cap on the body, sunk a little into it and sloped toward
	-- the player, the emitter's ring and lens on the cap. The kit (World/TerminalKit) is modelled
	-- from these numbers and the stripe's, screen's and frame's below
	-- (assets/blender/terminals/terminal_kit.py: keep them in step); the greybox and the beam's
	-- start are built from them.
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
	-- The fan of light from the lens to the screen's bottom edge: a Beam each client makes (an
	-- effect: UI/TerminalScreen), narrow at the lens.
	TERMINAL_BEAM = table.freeze({
		width0 = 0.9,
		width1 = 5.4,
		transparency0 = 0.55,
		transparency1 = 0.85,
	}),
	-- The station's grey-blue steel, so the terminal reads as the station's own kit: the cap's
	-- colour, and the shades of the console's parts against it (the kit bakes them into its vertex
	-- colours, terminal_kit.py SHADES: keep them in step) — dark foot, mid body, light cap.
	TERMINAL_HULL_COLOR = Color3.fromRGB(222, 225, 235),
	TERMINAL_SHADES = table.freeze({
		foot = 0.44,
		body = 0.67,
		cap = 1,
	}),

	-- The incubator (docs/design/screens/incubator.md): a dais in the island's center, its slots
	-- round it (Config/IncubatorShape), each an open capsule where an egg hovers or, not bought
	-- yet, a closed bud.
	INCUBATOR_POSITION = Vector3.zero,
	INCUBATOR_COLOR = INCUBATOR_COLOR,
	-- The incubator's zone on the floor: a ring around the dais and the waiting eggs.
	INCUBATOR_ZONE_RADIUS = 15,
	-- A capsule's light tells its state: its egg warms, is ready to hatch, or it is bought and
	-- empty (lit no more: plastic of the warm colour).
	CAPSULE_LIGHTS = table.freeze({
		Warming = table.freeze({ color = INCUBATOR_COLOR, material = Enum.Material.Neon }),
		Ready = table.freeze({ color = CAPSULE_READY_COLOR, material = Enum.Material.Neon }),
		Empty = table.freeze({ color = Color3.fromRGB(150, 105, 60), material = Enum.Material.SmoothPlastic }),
	}),
	-- The chip over an egg in a capsule hangs this far over the petals' tips, or over the egg's
	-- own top when it is the taller (Domain/Incubator.chipAbove).
	EGG_CHIP_OVER_POD = 0.6,
	EGG_CHIP_OVER_EGG = 0.55,
	-- Without the kit in the place: a disc a slot, glass over a bought one, a lid on the rest.
	CAPSULE_GREYBOX = table.freeze({
		standHeight = 0.4,
		standColor = Color3.fromRGB(120, 130, 160),
		glassColor = Color3.fromRGB(140, 220, 255),
		glassTransparency = 0.65,
		lidHeight = 1,
	}),
	-- Rare eggs still shine in the incubator, at this share of their light.
	INCUBATOR_GLOW_SCALE = 0.2,
	-- A ready egg (its time has come, decision 059) shines with this light until it is hatched.
	READY_EGG_LIGHT_COLOR = CAPSULE_READY_COLOR,
	READY_EGG_LIGHT_BRIGHTNESS = 3,
	READY_EGG_LIGHT_RANGE = 8,
	-- Eggs waiting for a slot lie on the floor around the incubator, from the entrance's side
	-- (decision 058), then on a wider ring; the first ring is clear of the dais's edge even for a
	-- large egg.
	WAITING_RING_RADIUS = IncubatorShape.DAIS_RADIUS + 1.6,
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

	-- The stand's look grows with the trainer's level (decision 091): a new model from the kit
	-- (World/StandKit, assets/blender/trainer/stand.py) at each tier's first level, the last the
	-- top; Domain/Stand.tier picks it. Each tier: its first level, the radius of its solid platform
	-- (its widest disc) and of the level dial on its top. Keep them in step with stand.py's TIERS.
	-- Without the kit in the place the stand is the greybox above, one look for every level.
	STAND_TIERS = table.freeze({
		table.freeze({ fromLevel = 0, platformRadius = 3, dialRadius = 2.75 }),
		table.freeze({ fromLevel = 3, platformRadius = 3.45, dialRadius = 2.85 }),
		table.freeze({ fromLevel = 6, platformRadius = 3.65, dialRadius = 3 }),
		table.freeze({ fromLevel = 9, platformRadius = 3.85, dialRadius = 3.15 }),
		table.freeze({ fromLevel = 12, platformRadius = 3.8, dialRadius = 3.4 }),
		table.freeze({ fromLevel = 15, platformRadius = 4.1, dialRadius = 3.7 }),
	}),
	-- The kit's pieces of a tier: the metal body (its shades baked in, times this tint), the
	-- yellow light, the top tier's gold (the pets' metal variant, AlienLooks.MODELS.METAL_VARIANT,
	-- whose base is SmoothPlastic). The island's light and grading turn the concepts' blue-grey
	-- steel pink on plain plastic; Metal tinted blue and darker reads as the concepts' steel
	-- (Studio, 2026-11-10).
	STAND_BODY_MATERIAL = Enum.Material.Metal,
	STAND_BODY_TINT = Color3.fromRGB(120, 135, 190),
	STAND_GLOW_COLOR = Color3.fromRGB(255, 214, 90),
	STAND_GOLD_MATERIAL = Enum.Material.SmoothPlastic,
	STAND_GOLD_COLOR = Color3.fromRGB(255, 190, 45),
	-- Between tiers, the level dial on the platform's top: a lamp lit a level, all lit from the
	-- last on. Its lamps run round the rim from the rider's front left, behind them, to their front
	-- right; the gap in front is where they step off. A lamp's size: along the rim, up, across it.
	STAND_DIAL = table.freeze({
		lamps = 15,
		arcDegrees = 300,
		lampSize = Vector3.new(0.32, 0.06, 0.16),
		litColor = Color3.fromRGB(255, 214, 90),
		offColor = Color3.fromRGB(40, 44, 62),
	}),

	-- The shelf (docs/design/screens/storage-shelf.md; its shape is Config/ShelfShape): on the right
	-- of a player who walks in from the spawn, where aliens with no place stand, all small (the
	-- first guardian's size) until placed. Its frame on the island: its origin, facing the spawn.
	SHELF_FRAME = CFrame.lookAt(SHELF_POSITION, Vector3.new(0, 0, -StationSize.ISLAND_SPAWN_DISTANCE)),
	-- Its light (the kit's Glow, the zone line): its own colour, apart from the places' blue, the
	-- incubator's orange and the trainer's yellow. Deep and leaning blue: a lighter violet (176,
	-- 128, 255) burnt to white under Bloom, and (120, 60, 255) read magenta in the island's grading
	-- (Studio, 2026-11-10).
	SHELF_COLOR = Color3.fromRGB(85, 70, 255),
	-- A full shelf (decision 110): its count and glow turn the danger red of the interface.
	SHELF_FULL_COLOR = Color3.fromHex("#FF5A64"),
	-- Its count hangs this far over the top of the shelf, studs.
	SHELF_COUNTER_ABOVE = 1.6,
	SHELF_GLOW_MATERIAL = Enum.Material.Neon,
	-- The kit's body: its colours are baked in (white leaves them as they are).
	SHELF_BODY_MATERIAL = Enum.Material.SmoothPlastic,
	SHELF_BODY_COLOR = Color3.new(1, 1, 1),
	-- The zone line on the floor: an arc this far in front of the niches.
	SHELF_ZONE_GAP = 1.5,
	-- The greybox shelf, without the kit in the place.
	SHELF_GREYBOX_COLOR = Color3.fromRGB(120, 130, 160),
	SHELF_GREYBOX_BACK_COLOR = Color3.fromRGB(30, 36, 64),
	SHELF_ALIEN_SCALE = 1,
	-- An alien bigger than this share of its niche's room is made smaller to fit (wings and
	-- claws would reach into the uprights).
	SHELF_ALIEN_FILL = 0.9,
})
