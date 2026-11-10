--!strict
-- Builds the greybox bay on a player's island (decision 068, docs/design/screens/island.md): the
-- zone lines on the floor, the owner's sign, the incubator stand and the trainer pad, and knows
-- where everything on the island stands: places (by Domain/PlaceLayout), capsules and their eggs,
-- waiting eggs, aliens on the floor. The contents themselves are added and replaced by BayService
-- as the profile changes. The island's floor and dome are WorldService's.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local PlaceLayout = require(ReplicatedStorage.Shared.Domain.PlaceLayout)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local StandKit = require(script.Parent.StandKit)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local TerminalKit = require(script.Parent.TerminalKit)

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
	model:SetAttribute(BayConfig.PLACE_PIVOT_ATTRIBUTE, frame)
	-- Streamed whole: the client glides its parts round that frame (PlaceGlideController).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end

-- Moves a place built by BayModel.buildPlace to `frame` (the layout shifted it): a move, so only
-- its parts' positions go to the clients, and they glide it there.
function BayModel.movePlace(model: Model, frame: CFrame)
	local was = model:GetAttribute(BayConfig.PLACE_PIVOT_ATTRIBUTE)
	if typeof(was) ~= "CFrame" or was:FuzzyEq(frame, 1e-3) then
		return
	end
	model:PivotTo(frame * was:ToObjectSpace(model:GetPivot()))
	model:SetAttribute(BayConfig.PLACE_PIVOT_ATTRIBUTE, frame)
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

-- A box of the stand at `cframe`.
-- A part of the stand around the rider. It never collides: the frame and the rail stand close
-- around the character, and the pull onto the platform would wedge them (and their jetpack)
-- against a solid post and tip them over; only the platform is solid.
local function standPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Metal
	part.Color = color
	part.CanCollide = false
	scenery(part)
	part.Parent = parent
	return part
end

-- The greybox stand, without the kit in the place: one look for every level. Its platform (the
-- primary part), the frame behind the rider, the rail in front, pilot lights, the blast grate and
-- the ring of its zone.
local function buildGreyboxStand(origin: CFrame, frame: CFrame, parent: Model)
	local pad = BayConfig.TRAINER_PAD
	local center = origin * CFrame.new(pad.x, 0, pad.z)
	local height = StandConfig.PLATFORM_HEIGHT

	local platform = disc(BayConfig.TRAINER_NAME, center * CFrame.new(0, height / 2, 0), pad.radius, height)
	platform.Material = Enum.Material.DiamondPlate
	platform.Color = BayLooks.STAND_COLOR
	scenery(platform)
	platform.Parent = parent
	parent.PrimaryPart = platform

	local pillar = BayLooks.STAND_PILLAR_SIZE
	for _, side in { -1, 1 } do
		local x = side * BayLooks.STAND_PILLAR_X
		standPart(
			"StandPillar",
			pillar,
			frame * CFrame.new(x, height + pillar.Y / 2, BayLooks.STAND_FRAME_Z),
			BayLooks.STAND_COLOR,
			parent
		)
		local pilot = standPart(
			BayConfig.STAND_PILOT_NAME,
			Vector3.one * BayLooks.STAND_PILOT_SIZE,
			frame * CFrame.new(x, height + BayLooks.STAND_PILOT_HEIGHT, BayLooks.STAND_FRAME_Z - pillar.Z),
			BayLooks.STAND_PILOT_COLOR,
			parent
		)
		pilot.Shape = Enum.PartType.Ball
		pilot.Material = Enum.Material.Neon

		local post = BayLooks.STAND_RAIL_THICKNESS
		local postHeight = BayLooks.STAND_RAIL_HEIGHT
		local postAt = CFrame.new(side * BayLooks.STAND_RAIL_X, height + postHeight / 2, BayLooks.STAND_RAIL_Z)
		standPart("StandRailPost", Vector3.new(post, postHeight, post), frame * postAt, BayLooks.STAND_COLOR, parent)
	end
	standPart(
		"StandBar",
		Vector3.new(BayLooks.STAND_PILLAR_X * 2 + pillar.X, pillar.X, pillar.Z),
		frame * CFrame.new(0, height + BayLooks.STAND_BAR_HEIGHT, BayLooks.STAND_FRAME_Z),
		BayLooks.STAND_COLOR,
		parent
	)
	local rail = BayLooks.STAND_RAIL_THICKNESS
	standPart(
		"StandRail",
		Vector3.new(BayLooks.STAND_RAIL_X * 2 + rail, rail, rail),
		frame * CFrame.new(0, height + BayLooks.STAND_RAIL_HEIGHT, BayLooks.STAND_RAIL_Z),
		BayLooks.STAND_RAIL_COLOR,
		parent
	)

	local grate = BayLooks.STAND_GRATE_SIZE
	local blast = standPart(
		BayConfig.STAND_GRATE_NAME,
		grate,
		frame * CFrame.new(0, grate.Y / 2, BayLooks.STAND_GRATE_Z),
		BayLooks.STAND_GRATE_COLOR,
		parent
	)
	blast.Material = Enum.Material.Neon

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

-- The jetpack stand on the trainer's pad (docs/design/screens/jetpack-stand.md), one model; the
-- simulation pulls the owner onto its platform. With the kit in the place its look grows with the
-- trainer's level (decision 091, BayModel.dressStand); its pivot is its frame on the floor, -Z
-- where the rider faces (the island's centre).
local function buildStand(origin: CFrame, island: Instance)
	local pad = BayConfig.TRAINER_PAD
	local frame = origin * CFrame.lookAt(Vector3.new(pad.x, 0, pad.z), Vector3.zero)
	local stand = Instance.new("Model")
	stand.Name = BayConfig.STAND_NAME
	if StandKit.present() then
		-- The solid platform, unseen: the kit's discs draw it. dressStand sizes it to the tier's.
		local height = StandConfig.PLATFORM_HEIGHT
		local platform = disc(BayConfig.TRAINER_NAME, frame * CFrame.new(0, height / 2, 0), pad.radius, height)
		platform.Transparency = 1
		scenery(platform)
		platform.Parent = stand
		stand.PrimaryPart = platform
		platform.PivotOffset = platform.CFrame:ToObjectSpace(frame)
		-- No tier worn yet: the first dressStand puts one on.
		stand:SetAttribute(BayConfig.STAND_TIER_ATTRIBUTE, 0)
	else
		buildGreyboxStand(origin, frame, stand)
	end
	stand.Parent = island
end

-- A piece of the stand's look: it never collides (see standPart), never casts a shadow (phones).
local function standLook(part: BasePart, name: string, parent: Instance)
	part.Name = name
	part.CanCollide = false
	scenery(part)
	part.Parent = parent
end

local TIER_STARTS = table.freeze((function()
	local starts = {}
	for index, tier in BayLooks.STAND_TIERS do
		starts[index] = tier.fromLevel
	end
	return starts
end)())

-- The kit's pieces a tier wears: the piece's name in the kit and on the stand, its material and
-- colour. Not every tier has every piece (gold is the top's).
local STAND_PIECES = table.freeze({
	{
		kind = "Body",
		name = BayConfig.STAND_LOOK_NAME,
		material = BayLooks.STAND_BODY_MATERIAL,
		color = Color3.new(1, 1, 1),
	},
	{
		kind = "Glow",
		name = BayConfig.STAND_LOOK_NAME,
		material = Enum.Material.Neon,
		color = BayLooks.STAND_GLOW_COLOR,
	},
	{
		kind = "Gold",
		name = BayConfig.STAND_LOOK_NAME,
		material = BayLooks.STAND_BODY_MATERIAL,
		color = BayLooks.STAND_GOLD_COLOR,
	},
	{
		kind = "Grate",
		name = BayConfig.STAND_GRATE_NAME,
		material = Enum.Material.Neon,
		color = BayLooks.STAND_GRATE_COLOR,
	},
	{
		kind = "Pilot",
		name = BayConfig.STAND_PILOT_NAME,
		material = Enum.Material.Neon,
		color = BayLooks.STAND_PILOT_COLOR,
	},
})

local STAND_LOOK_NAMES = table.freeze({
	[BayConfig.STAND_LOOK_NAME] = true,
	[BayConfig.STAND_GRATE_NAME] = true,
	[BayConfig.STAND_PILOT_NAME] = true,
	[BayConfig.STAND_LAMP_NAME] = true,
})

-- Puts tier `index`'s look on the kit's stand: its pieces where the kit holds them, its platform's
-- size, the level dial's lamps round its rim.
local function wearTier(stand: Model, platform: BasePart, index: number)
	for _, child in stand:GetChildren() do
		if STAND_LOOK_NAMES[child.Name] then
			child:Destroy()
		end
	end
	local frame = stand:GetPivot()
	local tier = BayLooks.STAND_TIERS[index]
	local height = StandConfig.PLATFORM_HEIGHT
	platform.Size = Vector3.new(height, tier.platformRadius * 2, tier.platformRadius * 2)

	for _, look in STAND_PIECES do
		local id = `{look.kind}{index}`
		local piece = if StandKit.has(id) then StandKit.piece(id) else nil
		if piece then
			local part = piece.part
			part.CFrame = frame * piece.offset
			part.Material = look.material
			part.Color = look.color
			if look.kind == "Gold" and MaterialService:FindFirstChild(AlienLooks.MODELS.METAL_VARIANT) then
				part.MaterialVariant = AlienLooks.MODELS.METAL_VARIANT
			end
			standLook(part, look.name, stand)
		end
	end

	local dial = BayLooks.STAND_DIAL
	for lamp = 1, dial.lamps do
		-- From the rider's front left (-X, -Z), round behind them (+Z), to their front right.
		local degrees = -dial.arcDegrees / 2 + dial.arcDegrees * (lamp - 0.5) / dial.lamps
		local part = Instance.new("Part")
		part.Size = dial.lampSize
		part.CFrame = frame
			* CFrame.Angles(0, math.rad(degrees), 0)
			* CFrame.new(0, height + dial.lampSize.Y / 2, tier.dialRadius)
		part:SetAttribute(BayConfig.STAND_LAMP_NAME, lamp)
		standLook(part, BayConfig.STAND_LAMP_NAME, stand)
	end
	stand:SetAttribute(BayConfig.STAND_TIER_ATTRIBUTE, index)
end

-- Dresses the stand of `bay` for trainer `level` (decision 091): the tier's look (only when the
-- tier changes) and the level dial, a lamp lit a level. Nothing for the greybox stand.
function BayModel.dressStand(bay: Instance, level: number)
	local stand = bay:FindFirstChild(BayConfig.STAND_NAME)
	local platform = stand and stand:FindFirstChild(BayConfig.TRAINER_NAME)
	if not stand or not stand:IsA("Model") or not platform or not platform:IsA("BasePart") then
		return
	end
	if stand:GetAttribute(BayConfig.STAND_TIER_ATTRIBUTE) == nil then
		-- The greybox: no kit in the place when the island was built.
		return
	end
	local index = Stand.tier(level, TIER_STARTS)
	if stand:GetAttribute(BayConfig.STAND_TIER_ATTRIBUTE) ~= index then
		wearTier(stand, platform, index)
	end
	local dial = BayLooks.STAND_DIAL
	local lit = Stand.dialLit(level, dial.lamps)
	for _, part in stand:GetChildren() do
		local lamp = part:GetAttribute(BayConfig.STAND_LAMP_NAME)
		if part:IsA("BasePart") and type(lamp) == "number" then
			part.Material = if lamp <= lit then Enum.Material.Neon else BayLooks.STAND_BODY_MATERIAL
			part.Color = if lamp <= lit then dial.litColor else dial.offColor
		end
	end
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

-- Where a terminal's cap sits, in the terminal's frame: on the body, sunk a little into it, its top
-- sloped toward the player (-Z).
local function terminalCap(): CFrame
	local looks = BayLooks.TERMINAL_CONSOLE
	return CFrame.new(0, BayLooks.TERMINAL_FOOT_HEIGHT + looks.body.Y + looks.cap.Y / 2 - looks.capSink, 0)
		* CFrame.Angles(-math.rad(looks.capTilt), 0, 0)
end

-- Where a terminal's screen hangs, in the terminal's frame: at a player's head, its top leaning back.
local function terminalScreen(): CFrame
	return CFrame.new(0, BayLooks.TERMINAL_SCREEN_HEIGHT, 0)
		* CFrame.Angles(math.rad(BayLooks.TERMINAL_SCREEN_TILT), 0, 0)
end

-- A terminal's greybox console, when the place has no kit: the foot, body and cap as plain parts
-- in their shades of the hull's colour.
local function greyboxConsole(frame: CFrame, parent: Instance)
	local looks = BayLooks.TERMINAL_CONSOLE
	local shades = BayLooks.TERMINAL_SHADES
	local hull = BayLooks.TERMINAL_HULL_COLOR
	local footHeight = BayLooks.TERMINAL_FOOT_HEIGHT
	local foot = disc("Foot", frame * CFrame.new(0, footHeight / 2, 0), BayLooks.TERMINAL_FOOT_RADIUS, footHeight)
	foot.Color = hull:Lerp(Color3.new(), 1 - shades.foot)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = looks.body
	body.CFrame = frame * CFrame.new(0, footHeight + looks.body.Y / 2, 0)
	body.Color = hull:Lerp(Color3.new(), 1 - shades.body)
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = looks.cap
	cap.CFrame = frame * terminalCap()
	cap.Color = hull
	for _, part in { foot, body, cap } do
		part.Material = Enum.Material.Metal
		scenery(part)
		part.Parent = parent
	end
end

-- A terminal's greybox glow, when the place has no kit: the stripe, the emitter's ring and lens,
-- the screen's frame and corner lights as plain parts in the zone's `color`.
local function greyboxGlow(frame: CFrame, color: Color3, parent: Instance)
	local looks = BayLooks.TERMINAL_CONSOLE
	local function glowing(part: Part, cframe: CFrame)
		part.CFrame = cframe
		part.Color = color
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		scenery(part)
		part.Parent = parent
	end
	local function block(name: string, size: Vector3, cframe: CFrame)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		glowing(part, cframe)
	end
	local stripe = BayLooks.TERMINAL_STRIPE_SIZE
	block(
		"Stripe",
		stripe,
		frame
			* CFrame.new(
				0,
				BayLooks.TERMINAL_FOOT_HEIGHT + BayLooks.TERMINAL_STRIPE_HEIGHT,
				-(looks.body.Z + stripe.Z / 2) / 2
			)
	)
	local capTop = frame * terminalCap() * CFrame.new(0, looks.cap.Y / 2, 0)
	local ring = disc("Emitter", capTop, looks.emitterRadius + looks.emitterThickness / 2, looks.emitterThickness / 2)
	glowing(ring, ring.CFrame)
	local lens = disc("Lens", capTop * CFrame.new(0, looks.lensThickness / 2, 0), looks.lensRadius, looks.lensThickness)
	glowing(lens, lens.CFrame)
	local screen = BayLooks.TERMINAL_SCREEN_SIZE
	local screenFrame = frame * terminalScreen()
	local bar = BayLooks.TERMINAL_FRAME_WIDTH
	local halfWidth, halfHeight = (screen.X + bar) / 2, (screen.Y + bar) / 2
	for _, side in { -1, 1 } do
		block("Bar", Vector3.new(screen.X + bar * 2, bar, bar), screenFrame * CFrame.new(0, side * halfHeight, 0))
		block("Bar", Vector3.new(bar, screen.Y, bar), screenFrame * CFrame.new(side * halfWidth, 0, 0))
		for _, level in { -1, 1 } do
			local corner = Instance.new("Part")
			corner.Name = "Corner"
			corner.Shape = Enum.PartType.Ball
			corner.Size = Vector3.one * BayLooks.TERMINAL_CORNER_SIZE
			glowing(corner, screenFrame * CFrame.new(side * halfWidth, level * halfHeight, 0))
		end
	end
end

-- A terminal beside a zone (docs/design/screens/terminals.md, version 2; decision 086): a holo
-- projector, its screen toward the spawn. Two meshes of World/TerminalKit — the steel console and
-- everything glowing in the zone's `color` — put on the terminal's spot by their pivot (greybox
-- parts without the kit), and the screen: a dim glass part in the air the client draws on (the
-- part named BayConfig.TERMINAL_SCREEN_NAME, its front face), with the attachments the client's
-- beam runs between. `faces`: the point its screen turns to, in the island's frame (the spawn by
-- default).
local function buildTerminal(origin: CFrame, name: string, position: Vector3, color: Color3, faces: Vector3?): Model
	local model = Instance.new("Model")
	model.Name = name
	local facing = faces or BayLooks.TERMINAL_FACES
	-- Its -Z (look vector) toward the spawn: the front.
	local frame = origin * CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))

	local console = TerminalKit.piece("Console")
	if console then
		console.Color = BayLooks.TERMINAL_HULL_COLOR
		console.Material = Enum.Material.Metal
		console:PivotTo(frame)
		scenery(console)
		console.Parent = model
	else
		greyboxConsole(frame, model)
	end
	local glow = TerminalKit.piece("Glow")
	if glow then
		glow.Color = color
		glow.Material = Enum.Material.Neon
		glow.CanCollide = false
		glow:PivotTo(frame)
		scenery(glow)
		glow.Parent = model
	else
		greyboxGlow(frame, color, model)
	end

	local screenSize = BayLooks.TERMINAL_SCREEN_SIZE
	local screenFrame = frame * terminalScreen()
	local screen = Instance.new("Part")
	screen.Name = BayConfig.TERMINAL_SCREEN_NAME
	screen.Size = screenSize
	screen.CFrame = screenFrame
	screen.Color = BayLooks.TERMINAL_SCREEN_COLOR
	screen.Material = Enum.Material.SmoothPlastic
	screen.Transparency = BayLooks.TERMINAL_SCREEN_TRANSPARENCY
	screen.CanCollide = false
	scenery(screen)
	-- Queried, unlike the rest of the scenery: a click reaches a SurfaceGui's buttons only through
	-- a ray that hits its part. While the screen still collided, CanQuery = false did not apply
	-- (Roblox ignores it on colliding parts); once it stopped colliding, the buttons went dead.
	screen.CanQuery = true
	screen.Parent = model
	-- Where the beam runs, both on the screen part so they stream in with it: from the lens to the
	-- screen's bottom edge. A fixed beam spreads its width along its attachments' secondary axis
	-- (measured in Studio; docs/design/BLENDER_ROBLOX.md, section 6): the screen's right, so the
	-- beam is a fan in the screen's plane (a camera-facing one lay across the screen from above).
	local function beamEnd(attachmentName: string, at: Vector3)
		local attachment = Instance.new("Attachment")
		attachment.Name = attachmentName
		attachment.Parent = screen
		attachment.WorldCFrame = CFrame.fromMatrix(at, frame.LookVector, frame.RightVector)
	end
	local looks = BayLooks.TERMINAL_CONSOLE
	local lens = frame * terminalCap() * CFrame.new(0, looks.cap.Y / 2 + looks.lensThickness, 0)
	beamEnd(BayConfig.TERMINAL_BEAM_FROM_NAME, lens.Position)
	beamEnd(BayConfig.TERMINAL_BEAM_TO_NAME, (screenFrame * CFrame.new(0, -screenSize.Y / 2, 0)).Position)

	model.PrimaryPart = screen
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

	buildStand(origin, model)

	local places = BayLooks.PLACES_TERMINAL_POSITION
	local hatchery = BayLooks.INCUBATOR_TERMINAL_POSITION
	local training = BayLooks.TRAINER_TERMINAL_POSITION
	buildTerminal(origin, BayConfig.PLACES_TERMINAL_NAME, places, BayLooks.PLACES_COLOR, BayLooks.PLACES_TERMINAL_FACES).Parent =
		model
	buildTerminal(origin, BayConfig.INCUBATOR_TERMINAL_NAME, hatchery, BayLooks.INCUBATOR_COLOR).Parent = model
	buildTerminal(origin, BayConfig.TRAINER_TERMINAL_NAME, training, BayLooks.TRAINER_RING_COLOR).Parent = model

	local contents = Instance.new("Folder")
	contents.Name = BayConfig.CONTENTS_NAME
	contents.Parent = model

	model.PrimaryPart = incubator
	return model
end

return table.freeze(BayModel)
