--!strict
-- Builds the greybox bay on a player's island (decision 068, docs/design/screens/island.md): the
-- zone lines on the floor, the owner's sign, the incubator stand and the trainer pad, and knows
-- where everything on the island stands: places (by Domain/PlaceLayout), capsules and their eggs,
-- waiting eggs, aliens on the shelf. The contents themselves are added and replaced by BayService
-- as the profile changes. The island's floor and dome are WorldService's.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local Incubator = require(ReplicatedStorage.Shared.Domain.Incubator)
local IncubatorKit = require(script.Parent.IncubatorKit)
local IncubatorShape = require(ReplicatedStorage.Shared.Config.IncubatorShape)
local PlaceLayout = require(ReplicatedStorage.Shared.Domain.PlaceLayout)
local Shelf = require(ReplicatedStorage.Shared.Domain.Shelf)
local ShelfShape = require(ReplicatedStorage.Shared.Config.ShelfShape)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local StandKit = require(script.Parent.StandKit)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StorageKit = require(script.Parent.StorageKit)
local TerminalKit = require(script.Parent.TerminalKit)

local BayModel = {}

-- What a bought capsule's light shows (BayLooks.CAPSULE_LIGHTS).
export type CapsuleState = "Warming" | "Ready" | "Empty"

-- Fewer pieces than this would show a circle as a polygon.
local MIN_ARC_PIECES = 24
-- An arc is drawn of straight pieces at most this long, studs.
local ARC_PIECE_LENGTH = 6
-- A bought capsule's part that lights up with its state, and the attribute telling a bought
-- capsule from a closed bud.
local CAPSULE_LIGHT_NAME = "Light"
local CAPSULE_BOUGHT_ATTRIBUTE = "Bought"
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

-- Where incubator slot `index` (1-based) stands: on the dais's top, facing out of the ring
-- (Domain/Incubator.slotAngle: the first faces the entrance).
function BayModel.capsuleCFrame(origin: CFrame, index: number): CFrame
	local center = BayLooks.INCUBATOR_POSITION + Vector3.yAxis * IncubatorShape.DAIS_HEIGHT
	local at = around(center, IncubatorShape.RING_RADIUS, Incubator.slotAngle(index, IncubatorShape))
	return origin * CFrame.lookAt(at, at + (at - center) * Vector3.new(1, 0, 1))
end

-- A piece of the incubator's kit worn at `frame` (its offset taken), touching nothing.
local function wearKit(piece: IncubatorKit.Piece, name: string, frame: CFrame, parent: Instance): MeshPart
	local part = piece.part
	part.Name = name
	part.CanCollide = false
	scenery(part)
	part.CFrame = frame * piece.offset
	part.Parent = parent
	return part
end

-- A slot without the kit: a disc, under glass when it is bought, with a lid when it is not.
local function buildGreyboxCapsule(frame: CFrame, isBought: boolean, model: Model)
	local look = BayLooks.CAPSULE_GREYBOX
	local stand =
		disc("Stand", frame * CFrame.new(0, look.standHeight / 2, 0), IncubatorShape.SOCKET_RADIUS, look.standHeight)
	stand.Material = Enum.Material.Metal
	stand.Color = look.standColor
	stand.CanCollide = false
	scenery(stand)
	stand.Parent = model
	local height = if isBought then IncubatorShape.POD_HEIGHT - look.standHeight else look.lidHeight
	local cover = disc(
		if isBought then CAPSULE_LIGHT_NAME else "Lid",
		frame * CFrame.new(0, look.standHeight + height / 2, 0),
		IncubatorShape.SOCKET_RADIUS - 0.2,
		height
	)
	cover.Material = if isBought then Enum.Material.Glass else Enum.Material.Metal
	cover.Color = if isBought then look.glassColor else look.standColor
	cover.Transparency = if isBought then look.glassTransparency else 0
	cover.CanCollide = false
	scenery(cover)
	cover.Parent = model
end

-- Incubator slot `index`: an open capsule (`isBought`), where an egg hovers, or a closed bud
-- (docs/design/screens/incubator.md). Nothing of it collides: players walk and fly through the
-- incubator. An invisible cylinder over the socket is the model's primary part. A capsule's light
-- is set by `setCapsuleState`.
function BayModel.buildCapsule(origin: CFrame, index: number, isBought: boolean): Model
	local frame = BayModel.capsuleCFrame(origin, index)
	local model = Instance.new("Model")
	model.Name = `{if isBought then "Capsule" else "Bud"}{index}`
	local body = IncubatorKit.piece(if isBought then "PodBody" else "BudBody")
	local glow = if isBought then IncubatorKit.piece("PodGlow") else nil
	if body and (glow or not isBought) then
		wearKit(body, "Body", frame, model)
		if glow then
			wearKit(glow, CAPSULE_LIGHT_NAME, frame, model)
		end
	else
		buildGreyboxCapsule(frame, isBought, model)
	end
	local height = if isBought then IncubatorShape.POD_HEIGHT else IncubatorShape.BUD_HEIGHT
	local block = disc("Block", frame * CFrame.new(0, height / 2, 0), IncubatorShape.SOCKET_RADIUS, height)
	block.Transparency = 1
	block.CanCollide = false
	scenery(block)
	block.Parent = model
	model.PrimaryPart = block
	model:SetAttribute(CAPSULE_BOUGHT_ATTRIBUTE, isBought)
	return model
end

-- Whether `capsule` (buildCapsule) is an open, bought one.
function BayModel.isCapsuleBought(capsule: Model): boolean
	return capsule:GetAttribute(CAPSULE_BOUGHT_ATTRIBUTE) == true
end

-- Lights a bought capsule for its egg: warming, ready, or none (BayLooks.CAPSULE_LIGHTS).
function BayModel.setCapsuleState(capsule: Model, state: CapsuleState)
	local light = capsule:FindFirstChild(CAPSULE_LIGHT_NAME)
	if not light or not light:IsA("BasePart") then
		return
	end
	local lights = BayLooks.CAPSULE_LIGHTS
	local look = if state == "Ready" then lights.Ready elseif state == "Warming" then lights.Warming else lights.Empty
	if light:IsA("MeshPart") then
		light.Color = look.color
		light.Material = look.material
	else
		-- The greybox's glass takes the state's colour as its tint (an empty one, its own).
		light.Color = if state == "Empty" then BayLooks.CAPSULE_GREYBOX.glassColor else look.color
	end
end

-- Where the egg in incubator slot `index` (1-based) hovers: a medium egg's centre in its capsule
-- (every size stands its bottom there, EggLooks.liftOf).
function BayModel.eggCFrame(origin: CFrame, index: number): CFrame
	return BayModel.capsuleCFrame(origin, index) * CFrame.new(0, IncubatorShape.EGG_FLOOR + EggLooks.EGG_SIZE.Y / 2, 0)
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

-- Where the `index`-th alien with no place (1-based) stands: on its niche's board of the shelf,
-- facing out of the niche (Domain/Shelf). Nil past the shelf's last niche: that one is only in the
-- window.
function BayModel.shelfCFrame(origin: CFrame, index: number): CFrame?
	local niche = Shelf.niche(index, ShelfShape)
	if not niche then
		return nil
	end
	local spot = Shelf.spot(niche, ShelfShape)
	return origin * BayLooks.SHELF_FRAME * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, spot.angle, 0)
end

-- A niche column's frame on the floor: the middle of its arc, facing out of it.
local function shelfColumnFrame(shelf: CFrame, column: number): CFrame
	local spot = Shelf.spot({ column = column, tier = 1 }, ShelfShape)
	return shelf * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, spot.angle, 0)
end

-- A plain box of the shelf: `size` along the arc, up and deep, at `cframe`.
local function shelfBox(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.CanCollide = false
	scenery(part)
	part.Parent = parent
	return part
end

-- The shelf without its kit: its boards, crowns and backs in greybox boxes.
local function buildGreyboxShelf(shelf: CFrame, parent: Instance)
	local shape = ShelfShape
	local top = shape.BASE_HEIGHT + shape.TIERS * shape.CELL_HEIGHT
	for column = 1, shape.COLUMNS do
		local frame = shelfColumnFrame(shelf, column)
		local width = shape.CELL_WIDTH
		local grey = BayLooks.SHELF_GREYBOX_COLOR
		shelfBox(
			"Base",
			Vector3.new(width, shape.BASE_HEIGHT, shape.DEPTH),
			frame * CFrame.new(0, shape.BASE_HEIGHT / 2, 0),
			grey,
			parent
		)
		for tier = 2, shape.TIERS do
			local floor = shape.BASE_HEIGHT + (tier - 1) * shape.CELL_HEIGHT
			local board = Vector3.new(width, shape.BOARD_THICKNESS, shape.DEPTH)
			shelfBox("Board", board, frame * CFrame.new(0, floor + shape.BOARD_THICKNESS / 2, 0), grey, parent)
		end
		local crown = Vector3.new(width, shape.CROWN_HEIGHT, shape.DEPTH)
		shelfBox("Crown", crown, frame * CFrame.new(0, top + shape.CROWN_HEIGHT / 2, 0), grey, parent)
		local back = Vector3.new(width, top - shape.BASE_HEIGHT, shape.BACK_THICKNESS)
		local behind = shape.DEPTH / 2 - shape.BACK_THICKNESS / 2
		local backFrame = frame * CFrame.new(0, (top + shape.BASE_HEIGHT) / 2, behind)
		shelfBox("Back", back, backFrame, BayLooks.SHELF_GREYBOX_BACK_COLOR, parent)
	end
end

-- The shelf where aliens with no place stand (docs/design/screens/storage-shelf.md): the kit's
-- pieces (World/StorageKit) or greybox, and a solid invisible block a niche column, so nobody walks
-- into it; the look itself collides with nothing (prompts and the camera pass into the niches).
local function buildShelf(origin: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = BayConfig.SHELF_NAME
	local shelf = origin * BayLooks.SHELF_FRAME
	local body = StorageKit.piece("Body")
	local glow = StorageKit.piece("Glow")
	if body and glow then
		for _, piece in { body, glow } do
			piece.part.CanCollide = false
			scenery(piece.part)
			piece.part.CFrame = shelf * piece.offset
			piece.part.Parent = model
		end
		body.part.Name = "Body"
		body.part.Material = BayLooks.SHELF_BODY_MATERIAL
		body.part.Color = BayLooks.SHELF_BODY_COLOR
		glow.part.Name = "Glow"
		glow.part.Material = BayLooks.SHELF_GLOW_MATERIAL
		glow.part.Color = BayLooks.SHELF_COLOR
	else
		buildGreyboxShelf(shelf, model)
	end
	local height = Shelf.height(ShelfShape)
	for column = 1, ShelfShape.COLUMNS do
		local block = Instance.new("Part")
		block.Name = "Block"
		block.Size = Vector3.new(ShelfShape.CELL_WIDTH, height, ShelfShape.DEPTH)
		block.CFrame = shelfColumnFrame(shelf, column) * CFrame.new(0, height / 2, 0)
		block.Transparency = 1
		scenery(block)
		block.Parent = model
	end
	model.Parent = parent
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
		color = BayLooks.STAND_BODY_TINT,
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
		material = BayLooks.STAND_GOLD_MATERIAL,
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

	-- The shelf's: an arc in front of its niches, round the same centre (Domain/Shelf: the arc's
	-- angle 0 is the shelf's middle, toward +Z from the centre in front of it).
	local radius = ShelfShape.RADIUS
	local halfArc = ShelfShape.COLUMNS * ShelfShape.CELL_WIDTH / radius / 2
	floorArc(
		origin * BayLooks.SHELF_FRAME,
		Vector3.new(0, 0, -radius),
		radius - ShelfShape.DEPTH / 2 - BayLooks.SHELF_ZONE_GAP,
		-halfArc,
		halfArc,
		BayLooks.SHELF_COLOR,
		parent
	)
end

-- The incubator's dais in the island's center (docs/design/screens/incubator.md): the part
-- `Incubator` (invisible over the kit's dais; it carries the incubator's attributes), the kit's
-- dais and its light, or the greybox disc in the incubator's colour. None of it collides: players
-- walk and fly through the incubator. Its slots are BayService's (buildCapsule).
local function buildIncubator(origin: CFrame, parent: Instance)
	local center = origin * CFrame.new(BayLooks.INCUBATOR_POSITION)
	local incubator = disc(
		BayConfig.INCUBATOR_NAME,
		center * CFrame.new(0, IncubatorShape.DAIS_HEIGHT / 2, 0),
		IncubatorShape.DAIS_RADIUS,
		IncubatorShape.DAIS_HEIGHT
	)
	incubator.Material = Enum.Material.SmoothPlastic
	incubator.Color = BayLooks.INCUBATOR_COLOR
	incubator.CanCollide = false
	scenery(incubator)
	incubator.Parent = parent
	local body = IncubatorKit.piece("DaisBody")
	local glow = IncubatorKit.piece("DaisGlow")
	if not body or not glow then
		return
	end
	incubator.Transparency = 1
	wearKit(body, "Dais", center, parent)
	local light = wearKit(glow, "DaisLight", center, parent)
	light.Material = Enum.Material.Neon
	light.Color = BayLooks.INCUBATOR_COLOR
end

function BayModel.build(slot: number, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `Bay{slot}`

	local lines = Instance.new("Folder")
	lines.Name = "ZoneLines"
	buildZoneLines(origin, lines)
	lines.Parent = model

	buildSign(origin, model)

	buildIncubator(origin, model)
	buildStand(origin, model)
	buildShelf(origin, model)

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

	model.PrimaryPart = model:FindFirstChild(BayConfig.INCUBATOR_NAME) :: BasePart
	return model
end

return table.freeze(BayModel)
