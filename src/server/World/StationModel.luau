--!strict
-- Builds the central station (decision 087, docs/plans/STATION.md): the platform and its rim, the
-- dome, the cone hull with glowing bands and engines under it, the ring round the dome with a
-- screen facing each island, and the struts holding the ring up. Shapes from the kit
-- (World/StationKit), sizes from StationShape, looks from StationLooks; without the kit each piece
-- stands in greybox parts of the same size. The kiosks and the coin board are built elsewhere.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StationKit = require(script.Parent.StationKit)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local StationShape = require(ReplicatedStorage.Shared.Config.StationShape)

local STATION = StationConfig.STATION
local SCALE = StationShape.SCALE
-- Steps of the greybox hull standing in for the cone without the kit.
local GREYBOX_HULL_STEPS = 4

local StationModel = {}

-- Static scenery: anchored, never touched or queried, so physics and raycasts skip it.
local function scenery(part: BasePart, collides: boolean, shadow: boolean)
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.CanCollide = collides
	part.CastShadow = shadow
end

local function block(name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	return part
end

-- A flat disc centred at `center` (Roblox cylinders run along X, so turn the axis upright).
local function disc(name: string, center: Vector3, radius: number, thickness: number): Part
	local part = block(
		name,
		Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function paint(part: BasePart, color: Color3, material: Enum.Material)
	part.Color = color
	part.Material = material
end

-- The direction round the station at `angle` (as the islands': from +X towards +Z).
local function outward(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function buildPlatform(parent: Instance)
	local slabCenter = STATION.platformCenter - Vector3.yAxis * StationConfig.PLATFORM_THICKNESS / 2
	local platform = disc("Platform", slabCenter, STATION.platformRadius, StationConfig.PLATFORM_THICKNESS)
	paint(platform, StationLooks.FLOOR_COLOR, StationLooks.FLOOR_MATERIAL)
	scenery(platform, true, true)
	platform.Parent = parent

	local rim =
		disc("Rim", slabCenter, STATION.platformRadius + StationConfig.RIM_WIDTH, StationConfig.PLATFORM_THICKNESS / 2)
	paint(rim, StationLooks.RIM_COLOR, Enum.Material.Neon)
	scenery(rim, false, false)
	rim.Parent = parent

	local dome = block("Dome", Vector3.one * STATION.domeRadius * 2, CFrame.new(STATION.domeCenter))
	dome.Shape = Enum.PartType.Ball
	paint(dome, StationLooks.DOME_COLOR, Enum.Material.ForceField)
	dome.Transparency = StationLooks.DOME_TRANSPARENCY
	scenery(dome, false, false)
	dome.Parent = parent
end

local function buildHull(parent: Instance)
	local top = CFrame.new(STATION.platformCenter.X, STATION.floorY, STATION.platformCenter.Z)
	local hull = StationKit.piece("Hull", SCALE)
	if hull then
		hull.CFrame = StationKit.place("Hull", top, SCALE)
		paint(hull, StationLooks.STEEL_COLOR, StationLooks.STEEL_MATERIAL)
		scenery(hull, true, true)
		hull.Parent = parent
		-- Its glowing bands and engine nozzles, one piece.
		local glow = StationKit.piece("HullGlow", SCALE)
		if glow then
			glow.CFrame = StationKit.place("HullGlow", top, SCALE)
			paint(glow, StationLooks.GLOW_COLOR, Enum.Material.Neon)
			scenery(glow, false, false)
			glow.Parent = parent
		end
		return
	end
	-- Greybox: steps as wide as the cone at their tops (they hide the dome's sphere below the floor
	-- too), and glowing discs for the bands.
	local stepDepth = StationShape.HULL_DEPTH / GREYBOX_HULL_STEPS
	for step = 1, GREYBOX_HULL_STEPS do
		local depth = (step - 1) * stepDepth
		local center = top.Position - Vector3.yAxis * (depth + stepDepth / 2)
		local part = disc(`Hull{step}`, center, StationShape.hullRadiusAt(depth), stepDepth)
		paint(part, StationLooks.STEEL_COLOR, StationLooks.STEEL_MATERIAL)
		scenery(part, true, true)
		part.Parent = parent
	end
	for index, share in StationShape.HULL_BANDS do
		local depth = StationShape.HULL_DEPTH * share
		local radius = StationShape.hullRadiusAt(depth) + StationShape.HULL_BAND_OVERHANG
		local band =
			disc(`HullBand{index}`, top.Position - Vector3.yAxis * depth, radius, StationShape.HULL_BAND_THICKNESS)
		paint(band, StationLooks.GLOW_COLOR, Enum.Material.Neon)
		scenery(band, false, false)
		band.Parent = parent
	end
end

-- The ring's segment `index` (1-based), facing island `index`: a band and its screen in the niche.
local function buildRingSegment(parent: Instance, center: Vector3, index: number)
	local angle = (index - 1) / StationShape.RING_SEGMENTS * math.pi * 2
	local direction = outward(angle)
	-- Looking out at the island: the segment lies along -Z of this frame, its niche facing out.
	local frame = CFrame.lookAt(center, center + direction)
	local segment = StationKit.piece("RingSegment", SCALE)
	if segment then
		segment.CFrame = StationKit.place("RingSegment", frame, SCALE)
		paint(segment, StationLooks.STEEL_COLOR, StationLooks.STEEL_MATERIAL)
		scenery(segment, true, true)
		segment.Name = `RingSegment{index}`
		segment.Parent = parent
	else
		-- A straight slab behind the screen, chord-wide.
		local width = 2 * StationShape.RING_OUTER_RADIUS * math.sin(math.pi / StationShape.RING_SEGMENTS)
		local depth = StationShape.SCREEN_BACK - StationShape.RING_INNER_RADIUS
		local slab = block(
			`RingSegment{index}`,
			Vector3.new(width, StationShape.RING_HEIGHT, depth),
			frame * CFrame.new(0, 0, -(StationShape.RING_INNER_RADIUS + depth / 2))
		)
		paint(slab, StationLooks.STEEL_COLOR, StationLooks.STEEL_MATERIAL)
		scenery(slab, true, true)
		slab.Parent = parent
	end

	-- The screen's front face (Front, -Z) looks out at the island.
	local screen = block(
		`Screen{index}`,
		Vector3.new(StationShape.SCREEN_WIDTH, StationShape.SCREEN_HEIGHT, StationShape.SCREEN_THICKNESS),
		frame * CFrame.new(0, 0, -(StationShape.SCREEN_BACK + StationShape.SCREEN_THICKNESS / 2))
	)
	paint(screen, StationLooks.SCREEN_COLOR, StationLooks.SCREEN_MATERIAL)
	screen.Transparency = StationLooks.SCREEN_TRANSPARENCY
	scenery(screen, false, false)
	-- Each client draws the top of the coin board on it (CoinBoardController).
	CollectionService:AddTag(screen, LeaderboardConfig.SCREEN_TAG)
	screen.Parent = parent
end

local function buildPylon(parent: Instance, index: number)
	local angle = StationShape.PYLON_FIRST_ANGLE + (index - 1) / StationShape.PYLON_COUNT * math.pi * 2
	local direction = outward(angle)
	local base = STATION.platformCenter
	local foot = base + direction * StationShape.PYLON_FOOT_RADIUS - Vector3.yAxis * StationShape.PYLON_FOOT_DROP
	local top = base + direction * StationShape.PYLON_TOP_RADIUS + Vector3.yAxis * StationShape.PYLON_TOP_LIFT
	local axis = (top - foot).Unit
	local length = (top - foot).Magnitude
	-- The strut runs along +Y of this frame, from its foot.
	local frame = CFrame.fromMatrix(foot, axis:Cross(direction).Unit, axis)
	local pylon: BasePart? = StationKit.piece("Pylon", SCALE)
	if pylon then
		pylon.Size = Vector3.new(pylon.Size.X, length, pylon.Size.Z)
	else
		pylon = block("Pylon", Vector3.new(2, length, 2) * Vector3.new(SCALE, 1, SCALE), CFrame.identity)
	end
	assert(pylon, "a pylon or its greybox")
	pylon.Name = `Pylon{index}`
	pylon.CFrame = frame * CFrame.new(0, length / 2, 0)
	paint(pylon, StationLooks.STEEL_LIGHT_COLOR, StationLooks.STEEL_MATERIAL)
	scenery(pylon, true, true)
	pylon.Parent = parent
end

-- Builds the station into a Folder `Station` in `parent`; returns the folder.
function StationModel.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Station"
	buildPlatform(folder)
	buildHull(folder)
	local ring = Instance.new("Folder")
	ring.Name = "Ring"
	local ringCenter = STATION.platformCenter + Vector3.yAxis * StationShape.RING_LIFT
	for index = 1, StationShape.RING_SEGMENTS do
		buildRingSegment(ring, ringCenter, index)
	end
	-- The trims along both its edges, all the way round: one piece.
	local glow = StationKit.piece("RingGlow", SCALE)
	if glow then
		glow.CFrame = StationKit.place("RingGlow", CFrame.new(ringCenter), SCALE)
		paint(glow, StationLooks.GLOW_COLOR, Enum.Material.Neon)
		scenery(glow, false, false)
		glow.Parent = ring
	end
	for index = 1, StationShape.PYLON_COUNT do
		buildPylon(ring, index)
	end
	ring.Parent = folder
	folder.Parent = parent
	return folder
end

return table.freeze(StationModel)
