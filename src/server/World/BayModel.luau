--!strict
-- Builds the greybox bay (base plate, sign post, incubator disc) and knows where everything in
-- it stands: pods, eggs on the incubator, aliens waiting on the floor. The contents themselves
-- are added and replaced by BayService as the profile changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

local BayModel = {}

local EDGE_HEIGHT = 0.1

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

-- The frame of bay `slot` (1-based): the middle of its island's floor, facing the station center
-- (decision 068).
function BayModel.origin(slot: number): CFrame
	return StationConfig.ISLAND_FRAMES[slot]
end

local PODS_PER_TIER = BayLooks.POD_ROWS * BayLooks.PODS_PER_ROW
assert(
	BayConfig.MAX_PODS <= PODS_PER_TIER * BayLooks.POD_TIERS,
	`BayLooks has room for {PODS_PER_TIER * BayLooks.POD_TIERS} pods, BayConfig.MAX_PODS is {BayConfig.MAX_PODS}`
)

-- The tier (1: on the floor) of pod `index`.
local function tierOf(index: number): number
	return (index - 1) // PODS_PER_TIER + 1
end

-- Where pod `index` (1-based) stands: the lower tier fills first, front row first.
function BayModel.podCFrame(origin: CFrame, index: number): CFrame
	local inTier = (index - 1) % PODS_PER_TIER
	local row = inTier // BayLooks.PODS_PER_ROW + 1
	local column = inTier % BayLooks.PODS_PER_ROW
	local x = (column - (BayLooks.PODS_PER_ROW - 1) / 2) * BayLooks.POD_SPACING
	local y = BayLooks.BASE_SIZE.Y + (tierOf(index) - 1) * BayLooks.POD_TIER_HEIGHT
	local z = BayLooks.POD_ROW_Z[math.clamp(row, 1, #BayLooks.POD_ROW_Z)]
	return origin * CFrame.new(x, y, z)
end

-- Where egg `index` (1-based) lies on the incubator: round the ring, then a level higher.
function BayModel.eggCFrame(origin: CFrame, index: number): CFrame
	local slot = (index - 1) % BayLooks.EGG_RING_SLOTS
	local level = (index - 1) // BayLooks.EGG_RING_SLOTS
	local angle = slot / BayLooks.EGG_RING_SLOTS * math.pi * 2
	local lift = BayLooks.INCUBATOR_THICKNESS + 1 + level * BayLooks.EGG_STACK_HEIGHT
	return origin
		* CFrame.new(BayLooks.INCUBATOR_POSITION)
		* CFrame.new(math.cos(angle) * BayLooks.EGG_RING_RADIUS, lift, math.sin(angle) * BayLooks.EGG_RING_RADIUS)
end

-- Where queued egg `index` (1-based) lies: on the platform around the incubator, then on a
-- wider ring around it.
function BayModel.waitingEggCFrame(origin: CFrame, index: number): CFrame
	local slot = (index - 1) % BayLooks.WAITING_RING_SLOTS
	local ring = (index - 1) // BayLooks.WAITING_RING_SLOTS
	-- The second ring sits half a step round, between the first ring's eggs.
	local angle = (slot + ring * 0.5) / BayLooks.WAITING_RING_SLOTS * math.pi * 2
	local radius = BayLooks.WAITING_RING_RADIUS + ring * BayLooks.WAITING_RING_STEP
	return origin
		* CFrame.new(BayLooks.INCUBATOR_POSITION)
		* CFrame.new(math.cos(angle) * radius, 1, math.sin(angle) * radius)
end

-- Where floor alien `index` (1-based) waits: down the right side, then the left, then again.
function BayModel.floorCFrame(origin: CFrame, index: number): CFrame
	local perRound = BayLooks.FLOOR_SPOTS_PER_SIDE * 2
	local spot = (index - 1) % perRound
	local round = (index - 1) // perRound
	local side = if spot < BayLooks.FLOOR_SPOTS_PER_SIDE then 1 else -1
	local along = spot % BayLooks.FLOOR_SPOTS_PER_SIDE
	local x = side * (BayLooks.FLOOR_SPOT_X - round * BayLooks.FLOOR_SPOT_SPACING)
	local z = BayLooks.FLOOR_SPOT_Z_START + along * BayLooks.FLOOR_SPOT_SPACING
	return origin * CFrame.new(x, BayLooks.BASE_SIZE.Y, z)
end

function BayModel.buildPod(origin: CFrame, index: number): Model
	local stand = disc(
		"Stand",
		BayModel.podCFrame(origin, index) * CFrame.new(0, BayLooks.POD_STAND_HEIGHT / 2, 0),
		BayLooks.POD_STAND_RADIUS,
		BayLooks.POD_STAND_HEIGHT
	)
	stand.Material = Enum.Material.Metal
	stand.Color = BayLooks.POD_STAND_COLOR
	scenery(stand)
	-- Upper-tier stands float at head height: nobody should bump into them.
	stand.CanCollide = tierOf(index) == 1

	local glass = disc(
		"Glass",
		BayModel.podCFrame(origin, index) * CFrame.new(0, BayLooks.POD_STAND_HEIGHT + BayLooks.POD_GLASS_HEIGHT / 2, 0),
		BayLooks.POD_STAND_RADIUS,
		BayLooks.POD_GLASS_HEIGHT
	)
	glass.Material = Enum.Material.Glass
	glass.Color = BayLooks.POD_GLASS_COLOR
	glass.Transparency = BayLooks.POD_GLASS_TRANSPARENCY
	glass.CanCollide = false
	scenery(glass)

	local model = Instance.new("Model")
	model.Name = `Pod{index}`
	stand.Parent = model
	glass.Parent = model
	model.PrimaryPart = stand
	return model
end

-- Where an alien inside pod `index` stands.
function BayModel.podAlienCFrame(origin: CFrame, index: number): CFrame
	return BayModel.podCFrame(origin, index) * CFrame.new(0, BayLooks.POD_STAND_HEIGHT, 0)
end

-- The trainer zone: an outline on the station floor beside the bay (a dark disc inside a glowing
-- ring), nothing to climb. The prompt and the sign hang on the disc.
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

function BayModel.build(slot: number, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `Bay{slot}`

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = BayLooks.BASE_SIZE
	base.CFrame = origin * CFrame.new(0, BayLooks.BASE_SIZE.Y / 2, 0)
	base.Material = Enum.Material.Metal
	base.Color = BayLooks.BASE_COLOR
	scenery(base)
	base.Parent = model

	local edge = Instance.new("Part")
	edge.Name = "Edge"
	edge.Size = Vector3.new(BayLooks.BASE_SIZE.X + 0.6, EDGE_HEIGHT, BayLooks.BASE_SIZE.Z + 0.6)
	edge.CFrame = origin * CFrame.new(0, EDGE_HEIGHT / 2, 0)
	edge.Material = Enum.Material.Neon
	edge.Color = BayLooks.EDGE_COLOR
	edge.CanCollide = false
	scenery(edge)
	edge.Parent = model

	local sign = Instance.new("Part")
	sign.Name = BayConfig.SIGN_NAME
	sign.Size = BayLooks.SIGN_SIZE
	sign.CFrame = origin * CFrame.new(BayLooks.SIGN_POSITION)
	sign.Material = Enum.Material.Neon
	sign.Color = BayLooks.EDGE_COLOR
	sign.CanCollide = false
	scenery(sign)
	sign.Parent = model

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

	-- Invisible: only carries the pods' sign.
	local podsSign = Instance.new("Part")
	podsSign.Name = BayConfig.PODS_SIGN_NAME
	podsSign.Size = Vector3.one * 0.2
	podsSign.Transparency = 1
	podsSign.CFrame = origin * CFrame.new(BayLooks.PODS_SIGN_POSITION)
	podsSign.CanCollide = false
	scenery(podsSign)
	podsSign.Parent = model

	local contents = Instance.new("Folder")
	contents.Name = BayConfig.CONTENTS_NAME
	contents.Parent = model

	model.PrimaryPart = base
	return model
end

return table.freeze(BayModel)
