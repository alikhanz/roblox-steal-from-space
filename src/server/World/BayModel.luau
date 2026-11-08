--!strict
-- Builds the greybox bay on a player's island (decision 068, docs/design/screens/island.md): the
-- zone lines on the floor, the owner's sign, the incubator stand and the trainer pad, and knows
-- where everything on the island stands: places (by Domain/PlaceLayout), capsules and their eggs,
-- waiting eggs, aliens on the floor. The contents themselves are added and replaced by BayService
-- as the profile changes. The island's floor and dome are WorldService's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local PlaceLayout = require(ReplicatedStorage.Shared.Domain.PlaceLayout)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

local BayModel = {}

-- Fewer pieces than this would show a circle as a polygon.
local MIN_ARC_PIECES = 24
-- An arc is drawn of straight pieces at most this long, studs.
local ARC_PIECE_LENGTH = 6
-- A ready egg lies this far above its capsule's stand, studs: room for the largest egg.
local EGG_LIFT = 1.4
-- How far above the floor a waiting egg lies, studs.
local WAITING_EGG_LIFT = 1

-- Static scenery: anchored, never touched or queried.
local function scenery(part: BasePart)
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- A flat disc at `cframe` (Roblox cylinders run along X, so the axis is turned upright).
local function disc(name: string, cframe: CFrame, radius: number, thickness: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, radius * 2, radius * 2)
	part.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- A glowing line on the floor from `a` to `b` (island frame, on the floor).
local function floorLine(origin: CFrame, a: Vector3, b: Vector3, color: Color3, parent: Instance)
	local length = (b - a).Magnitude
	if length < 1e-3 then
		return
	end
	local middle = (a + b) / 2 + Vector3.yAxis * BayLooks.ZONE_LINE_HEIGHT / 2
	local part = Instance.new("Part")
	part.Name = "ZoneLine"
	part.Size = Vector3.new(BayLooks.ZONE_LINE_WIDTH, BayLooks.ZONE_LINE_HEIGHT, length + BayLooks.ZONE_LINE_WIDTH)
	part.CFrame = origin * CFrame.lookAt(middle, middle + (b - a))
	part.Material = Enum.Material.Neon
	part.Color = color
	part.CanCollide = false
	scenery(part)
	part.Parent = parent
end

-- A point on the floor `radius` from `center` at `angle` (0: toward the island's back, +Z).
local function around(center: Vector3, radius: number, angle: number): Vector3
	return center + Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
end

-- An arc of glowing line on the floor around `center`, from angle `from` to `to`.
local function floorArc(
	origin: CFrame,
	center: Vector3,
	radius: number,
	from: number,
	to: number,
	color: Color3,
	parent: Instance
)
	local pieces = math.max(MIN_ARC_PIECES, math.ceil(radius * math.abs(to - from) / ARC_PIECE_LENGTH))
	for piece = 1, pieces do
		local a = from + (to - from) * (piece - 1) / pieces
		local b = from + (to - from) * piece / pieces
		floorLine(origin, around(center, radius, a), around(center, radius, b), color, parent)
	end
end

-- The frame of bay `slot` (1-based): the middle of its island's floor, facing the station center
-- (decision 068).
function BayModel.origin(slot: number): CFrame
	return StationConfig.ISLAND_FRAMES[slot]
end

-- Where each place stands, given the width of what stands on it (an alien's, or an empty place's
-- BayLooks.EMPTY_PLACE_WIDTH), in place order. Each frame is on the floor, facing the island's
-- center.
function BayModel.placeFrames(origin: CFrame, widths: { number }): { CFrame }
	local layout = PlaceLayout.arrange(widths, BayLooks.PLACES)
	local frames: { CFrame } = {}
	for index, spot in layout.spots do
		local at = Vector3.new(spot.x, 0, spot.z)
		frames[index] = origin * CFrame.lookAt(at, Vector3.zero)
	end
	return frames
end

-- A place's pad under an alien `width` wide (or an empty place's), at `frame` on the floor.
function BayModel.buildPlace(frame: CFrame, width: number, index: number): Model
	local model = Instance.new("Model")
	model.Name = `Place{index}`
	local radius = width / 2 + BayLooks.PLACE_PAD_MARGIN

	local ring = disc(
		"Ring",
		frame * CFrame.new(0, BayLooks.PLACE_PAD_HEIGHT / 2, 0),
		radius + BayLooks.PLACE_RING_WIDTH,
		BayLooks.PLACE_PAD_HEIGHT * 0.6
	)
	ring.Material = Enum.Material.Neon
	ring.Color = BayLooks.PLACES_COLOR
	ring.CanCollide = false
	scenery(ring)
	ring.Parent = model

	local pad = disc("Pad", frame * CFrame.new(0, BayLooks.PLACE_PAD_HEIGHT / 2, 0), radius, BayLooks.PLACE_PAD_HEIGHT)
	pad.Material = Enum.Material.Metal
	pad.Color = BayLooks.PLACE_PAD_COLOR
	scenery(pad)
	pad.Parent = model

	model.PrimaryPart = pad
	return model
end

-- Where an alien on a place at `frame` stands: on its pad.
function BayModel.placeAlienCFrame(frame: CFrame): CFrame
	return frame * CFrame.new(0, BayLooks.PLACE_PAD_HEIGHT, 0)
end

-- The angle of capsule `index` (1-based) around the incubator: the first faces the entrance
-- (-Z), the next ones alternate to its right and left.
local function capsuleAngle(index: number): number
	local step = math.pi * 2 / BayLooks.CAPSULE_POSITIONS
	local offset = math.ceil((index - 1) / 2) * (if index % 2 == 0 then 1 else -1)
	return math.pi + offset * step
end

-- Where capsule `index` (1-based) stands: on the incubator's stand, facing out.
function BayModel.capsuleCFrame(origin: CFrame, index: number): CFrame
	local center = BayLooks.INCUBATOR_POSITION + Vector3.yAxis * BayLooks.INCUBATOR_THICKNESS
	local at = around(center, BayLooks.CAPSULE_RING_RADIUS, capsuleAngle(index))
	return origin * CFrame.lookAt(at, at + (at - center) * Vector3.new(1, 0, 1))
end

function BayModel.buildCapsule(origin: CFrame, index: number): Model
	local frame = BayModel.capsuleCFrame(origin, index)
	local stand = disc(
		"Stand",
		frame * CFrame.new(0, BayLooks.CAPSULE_STAND_HEIGHT / 2, 0),
		BayLooks.CAPSULE_RADIUS,
		BayLooks.CAPSULE_STAND_HEIGHT
	)
	stand.Material = Enum.Material.Metal
	stand.Color = BayLooks.CAPSULE_STAND_COLOR
	scenery(stand)

	local glass = disc(
		"Glass",
		frame * CFrame.new(0, BayLooks.CAPSULE_STAND_HEIGHT + BayLooks.CAPSULE_GLASS_HEIGHT / 2, 0),
		BayLooks.CAPSULE_RADIUS,
		BayLooks.CAPSULE_GLASS_HEIGHT
	)
	glass.Material = Enum.Material.Glass
	glass.Color = BayLooks.CAPSULE_GLASS_COLOR
	glass.Transparency = BayLooks.CAPSULE_GLASS_TRANSPARENCY
	glass.CanCollide = false
	scenery(glass)

	local model = Instance.new("Model")
	model.Name = `Capsule{index}`
	stand.Parent = model
	glass.Parent = model
	model.PrimaryPart = stand
	return model
end

-- Where the egg in incubator slot `index` (1-based) lies: in its capsule.
function BayModel.eggCFrame(origin: CFrame, index: number): CFrame
	return BayModel.capsuleCFrame(origin, index) * CFrame.new(0, BayLooks.CAPSULE_STAND_HEIGHT + EGG_LIFT, 0)
end

-- Where queued egg `index` (1-based) lies: on the floor round the incubator, from the
-- entrance's side outward to either side, then on a wider ring.
function BayModel.waitingEggCFrame(origin: CFrame, index: number): CFrame
	local slot = (index - 1) % BayLooks.WAITING_RING_SLOTS
	local ring = (index - 1) // BayLooks.WAITING_RING_SLOTS
	local step = math.pi * 2 / BayLooks.WAITING_RING_SLOTS
	local offset = math.ceil(slot / 2) * (if slot % 2 == 1 then 1 else -1)
	-- The second ring sits half a step round, between the first ring's eggs.
	local angle = math.pi + (offset + ring * 0.5) * step
	local radius = BayLooks.WAITING_RING_RADIUS + ring * BayLooks.WAITING_RING_STEP
	return origin * CFrame.new(around(BayLooks.INCUBATOR_POSITION, radius, angle) + Vector3.yAxis * WAITING_EGG_LIFT)
end

-- Where floor alien `index` (1-based) waits: in the tray right of the spawn, rows from the
-- entrance's side, facing the island's center. Past the tray's rows they go round again.
function BayModel.floorCFrame(origin: CFrame, index: number): CFrame
	local columns = BayLooks.PILE_COLUMNS
	local spacing = BayLooks.PILE_SPACING
	local rows = math.max(1, math.floor(BayLooks.PILE_SIZE.Y / spacing))
	local spot = (index - 1) % (columns * rows)
	local column = spot % columns
	local row = spot // columns
	local center = BayLooks.PILE_CENTER
	local at = Vector3.new(
		center.X + (column - (columns - 1) / 2) * spacing,
		0,
		center.Z - (rows - 1) / 2 * spacing + row * spacing
	)
	return origin * CFrame.lookAt(at, Vector3.new(0, 0, 0))
end

-- The trainer zone: an outline on the floor (a dark disc inside a glowing ring), nothing to
-- climb. The prompt and the sign hang on the disc.
local function buildTrainer(origin: CFrame, parent: Instance)
	local pad = BayConfig.TRAINER_PAD
	local center = origin * CFrame.new(pad.x, 0, pad.z)

	local plate = disc(
		BayConfig.TRAINER_NAME,
		center * CFrame.new(0, BayLooks.TRAINER_HEIGHT / 2, 0),
		pad.radius,
		BayLooks.TRAINER_HEIGHT
	)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = BayLooks.TRAINER_COLOR
	plate.CanCollide = false
	scenery(plate)
	plate.Parent = parent

	local ring = disc(
		"TrainerRing",
		center * CFrame.new(0, BayLooks.TRAINER_RING_HEIGHT / 2, 0),
		pad.radius + BayLooks.TRAINER_RING_WIDTH,
		BayLooks.TRAINER_RING_HEIGHT
	)
	ring.Material = Enum.Material.Neon
	ring.Color = BayLooks.TRAINER_RING_COLOR
	ring.CanCollide = false
	scenery(ring)
	ring.Parent = parent
end

-- The owner's sign: a board on two posts at the entrance. The name hangs over it (the client's
-- label on the board).
local function buildSign(origin: CFrame, parent: Instance)
	local base = origin * CFrame.new(BayLooks.SIGN_POSITION)
	local board = BayLooks.SIGN_BOARD_SIZE
	local postHeight = BayLooks.SIGN_POST_HEIGHT

	local sign = Instance.new("Part")
	sign.Name = BayConfig.SIGN_NAME
	sign.Size = board
	sign.CFrame = base * CFrame.new(0, postHeight + board.Y / 2, 0)
	sign.Material = Enum.Material.Metal
	sign.Color = BayLooks.SIGN_COLOR
	scenery(sign)
	sign.Parent = parent

	-- A glowing frame line along the board's top and bottom.
	for _, side in { 1, -1 } do
		local edge = Instance.new("Part")
		edge.Name = "SignEdge"
		edge.Size = Vector3.new(board.X, 0.2, board.Z + 0.1)
		edge.CFrame = sign.CFrame * CFrame.new(0, side * (board.Y / 2 - 0.1), 0)
		edge.Material = Enum.Material.Neon
		edge.Color = BayLooks.EDGE_COLOR
		edge.CanCollide = false
		scenery(edge)
		edge.Parent = parent
	end

	for _, side in { 1, -1 } do
		local post = Instance.new("Part")
		post.Name = "SignPost"
		post.Size = BayLooks.SIGN_POST_SIZE + Vector3.yAxis * postHeight
		post.CFrame = base * CFrame.new(side * (board.X / 2 - 1), postHeight / 2, 0)
		post.Material = Enum.Material.Metal
		post.Color = BayLooks.SIGN_COLOR
		scenery(post)
		post.Parent = parent
	end
end

-- A terminal beside a zone (docs/design/screens/terminals.md): a base with a glow in the zone's
-- `color`, a column and a tilted screen in a glowing frame, the screen toward the spawn. The
-- client draws the screen (the part named BayConfig.TERMINAL_SCREEN_NAME, its front face).
local function buildTerminal(origin: CFrame, name: string, position: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	local facing = BayLooks.TERMINAL_FACES
	local frame = origin * CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))

	local function piece(pieceName: string, size: Vector3, cframe: CFrame, pieceColor: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = pieceName
		part.Size = size
		part.CFrame = cframe
		part.Color = pieceColor
		part.Material = material
		scenery(part)
		part.Parent = model
		return part
	end

	local base = BayLooks.TERMINAL_BASE_SIZE
	local glowSize = base + Vector3.new(2, 0, 2) * BayLooks.TERMINAL_GLOW_MARGIN - Vector3.yAxis * base.Y * 0.5
	local glow = piece("Glow", glowSize, frame * CFrame.new(0, glowSize.Y / 2, 0), color, Enum.Material.Neon)
	glow.CanCollide = false
	local stand =
		piece("Base", base, frame * CFrame.new(0, base.Y / 2, 0), BayLooks.TERMINAL_BASE_COLOR, Enum.Material.Metal)
	local column = BayLooks.TERMINAL_COLUMN_SIZE
	piece(
		"Column",
		column,
		frame * CFrame.new(0, base.Y + column.Y / 2, 0),
		BayLooks.TERMINAL_COLOR,
		Enum.Material.Metal
	)

	local screenSize = BayLooks.TERMINAL_SCREEN_SIZE
	local screenFrame = frame
		* CFrame.new(0, BayLooks.TERMINAL_SCREEN_HEIGHT, 0)
		* CFrame.Angles(math.rad(BayLooks.TERMINAL_SCREEN_TILT), 0, 0)
	local margin = BayLooks.TERMINAL_FRAME_MARGIN
	local rim = piece(
		"Rim",
		screenSize + Vector3.new(margin * 2, margin * 2, -screenSize.Z / 2),
		screenFrame * CFrame.new(0, 0, screenSize.Z / 4),
		color,
		Enum.Material.Neon
	)
	rim.CanCollide = false
	piece(
		BayConfig.TERMINAL_SCREEN_NAME,
		screenSize,
		screenFrame,
		BayLooks.TERMINAL_SCREEN_COLOR,
		Enum.Material.SmoothPlastic
	)

	model.PrimaryPart = stand
	return model
end

-- The lines on the floor around each zone, in its colour.
local function buildZoneLines(origin: CFrame, parent: Instance)
	local places = BayLooks.PLACES
	local half = places.arc / 2
	local inner = places.inner - 2
	local outer = places.outer + 2
	floorArc(origin, Vector3.zero, inner, -half, half, BayLooks.PLACES_COLOR, parent)
	floorArc(origin, Vector3.zero, outer, -half, half, BayLooks.PLACES_COLOR, parent)
	for _, angle in { -half, half } do
		floorLine(
			origin,
			around(Vector3.zero, inner, angle),
			around(Vector3.zero, outer, angle),
			BayLooks.PLACES_COLOR,
			parent
		)
	end

	floorArc(
		origin,
		BayLooks.INCUBATOR_POSITION,
		BayLooks.INCUBATOR_ZONE_RADIUS,
		0,
		math.pi * 2,
		BayLooks.INCUBATOR_COLOR,
		parent
	)

	local pad = BayConfig.TRAINER_PAD
	floorArc(
		origin,
		Vector3.new(pad.x, 0, pad.z),
		pad.radius + BayLooks.TRAINER_ZONE_MARGIN,
		0,
		math.pi * 2,
		BayLooks.TRAINER_RING_COLOR,
		parent
	)

	local center = BayLooks.PILE_CENTER
	local halfX, halfZ = BayLooks.PILE_SIZE.X / 2, BayLooks.PILE_SIZE.Y / 2
	local corners = {
		center + Vector3.new(-halfX, 0, -halfZ),
		center + Vector3.new(halfX, 0, -halfZ),
		center + Vector3.new(halfX, 0, halfZ),
		center + Vector3.new(-halfX, 0, halfZ),
	}
	for index, corner in corners do
		floorLine(origin, corner, corners[index % #corners + 1], BayLooks.PILE_COLOR, parent)
	end
end

function BayModel.build(slot: number, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `Bay{slot}`

	local lines = Instance.new("Folder")
	lines.Name = "ZoneLines"
	buildZoneLines(origin, lines)
	lines.Parent = model

	buildSign(origin, model)

	local incubator = disc(
		BayConfig.INCUBATOR_NAME,
		origin * CFrame.new(BayLooks.INCUBATOR_POSITION) * CFrame.new(0, BayLooks.INCUBATOR_THICKNESS / 2, 0),
		BayLooks.INCUBATOR_RADIUS,
		BayLooks.INCUBATOR_THICKNESS
	)
	incubator.Material = Enum.Material.SmoothPlastic
	incubator.Color = BayLooks.INCUBATOR_COLOR
	scenery(incubator)
	incubator.Parent = model

	buildTrainer(origin, model)

	local places = BayLooks.PLACES_TERMINAL_POSITION
	local hatchery = BayLooks.INCUBATOR_TERMINAL_POSITION
	local training = BayLooks.TRAINER_TERMINAL_POSITION
	buildTerminal(origin, BayConfig.PLACES_TERMINAL_NAME, places, BayLooks.PLACES_COLOR).Parent = model
	buildTerminal(origin, BayConfig.INCUBATOR_TERMINAL_NAME, hatchery, BayLooks.INCUBATOR_COLOR).Parent = model
	buildTerminal(origin, BayConfig.TRAINER_TERMINAL_NAME, training, BayLooks.TRAINER_RING_COLOR).Parent = model

	local contents = Instance.new("Folder")
	contents.Name = BayConfig.CONTENTS_NAME
	contents.Parent = model

	model.PrimaryPart = incubator
	return model
end

return table.freeze(BayModel)
