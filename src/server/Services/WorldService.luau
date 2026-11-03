--!strict
-- Builds the greybox world at server start: station platform, dome, spawn, asteroid field and
-- space lighting. Code-owned so the world lives in Git; real models replace the parts later.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ShopModel = require(script.Parent.Parent.World.ShopModel)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)

local WORLD_FOLDER_NAME = "World"
local DOME_TRANSPARENCY = 0.75
local DOME_COLOR = Color3.fromRGB(110, 190, 255)
local PLATFORM_COLOR = Color3.fromRGB(128, 136, 160)
local HULL_COLOR = Color3.fromRGB(70, 76, 94)
-- Glowing rim around the platform: makes the station easy to find from the asteroid field.
local RIM_COLOR = Color3.fromRGB(90, 200, 255)
local STAR_COUNT = 5000
-- The map edge: a faint shell so players see where space ends (Bounds stops them there).
local BOUNDARY_COLOR = Color3.fromRGB(150, 90, 255)
local BOUNDARY_TRANSPARENCY = 0.9
local NEST_BOWL_RADIUS = 4.5
local NEST_BOWL_THICKNESS = 1.2
local NEST_BOWL_COLOR = Color3.fromRGB(92, 66, 110)
-- Height of an egg's center above the bowl's center.
local NEST_EGG_LIFT = 1.5

export type NestSite = {
	id: string,
	model: Model,
	zone: ZoneConfig.ZoneId,
	-- Where an egg rests in this nest.
	eggCFrame: CFrame,
}

export type WorldService = {
	name: string,
	start: () -> (),
	-- Where players respawn; nil before the world is built.
	getSpawn: () -> SpawnLocation?,
	-- Nest locations; empty before the world is built.
	getNestSites: () -> { NestSite },
}

local WorldService = {}

-- Static scenery: anchored, never touched or queried, so physics and raycasts skip it.
local function scenery(part: BasePart)
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- A flat disc centered at `center` (Roblox cylinders run along X, so turn the axis upright).
local function disc(name: string, center: Vector3, radius: number, thickness: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, radius * 2, radius * 2)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- Stepped hull under the platform. Each step is a little wider than the dome sphere at its top,
-- so the part of the sphere below the platform stays hidden inside the hull.
local function buildHull(parent: Instance)
	local station = StationConfig.STATION
	local sphereBottomY = station.domeCenter.Y - station.domeRadius
	local depth = station.floorY - sphereBottomY
	if depth <= 0 then
		return
	end
	local stepHeight = depth / StationConfig.HULL_STEPS
	for step = 1, StationConfig.HULL_STEPS do
		local topY = station.floorY - (step - 1) * stepHeight
		local sphereRadiusAtTop = math.sqrt(math.max(0, station.domeRadius ^ 2 - (topY - station.domeCenter.Y) ^ 2))
		local center = Vector3.new(station.domeCenter.X, topY - stepHeight / 2, station.domeCenter.Z)
		local hull = disc(`Hull{step}`, center, sphereRadiusAtTop + 1, stepHeight)
		hull.Material = Enum.Material.Metal
		hull.Color = HULL_COLOR
		hull.Anchored = true
		hull.CanTouch = false
		hull.Parent = parent
	end
end

local function buildStation(parent: Instance): SpawnLocation
	local station = StationConfig.STATION
	local platformCenter = StationConfig.PLATFORM_CENTER - Vector3.yAxis * StationConfig.PLATFORM_THICKNESS / 2

	local platform = disc("Platform", platformCenter, StationConfig.PLATFORM_RADIUS, StationConfig.PLATFORM_THICKNESS)
	platform.Material = Enum.Material.DiamondPlate
	platform.Color = PLATFORM_COLOR
	platform.Anchored = true
	platform.CanTouch = false
	platform.Parent = parent

	local rim = disc(
		"Rim",
		platformCenter,
		StationConfig.PLATFORM_RADIUS + StationConfig.RIM_WIDTH,
		StationConfig.PLATFORM_THICKNESS / 2
	)
	rim.Material = Enum.Material.Neon
	rim.Color = RIM_COLOR
	rim.CanCollide = false
	scenery(rim)
	rim.Parent = parent

	local shell = Instance.new("Part")
	shell.Name = "Dome"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * station.domeRadius * 2
	shell.CFrame = CFrame.new(station.domeCenter)
	shell.Material = Enum.Material.ForceField
	shell.Color = DOME_COLOR
	shell.Transparency = DOME_TRANSPARENCY
	shell.CanCollide = false
	scenery(shell)
	shell.Parent = parent

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StationSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(StationConfig.PLATFORM_CENTER + StationConfig.SPAWN_OFFSET)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Anchored = true
	spawn.CanTouch = false
	spawn.Parent = parent

	buildHull(parent)
	return spawn
end

local function randomInField(random: Random): Vector3
	-- Uniform over the disc area between the inner and outer radius.
	local inner, outer = WorldConfig.INNER_RADIUS, WorldConfig.OUTER_RADIUS
	local distance = math.sqrt(random:NextNumber(inner * inner, outer * outer))
	local angle = random:NextNumber(0, math.pi * 2)
	local height = random:NextNumber(-WorldConfig.VERTICAL_SPREAD, WorldConfig.VERTICAL_SPREAD)
	return StationConfig.PLATFORM_CENTER + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
end

local function buildAsteroids(parent: Instance)
	local random = Random.new(WorldConfig.SEED)
	local folder = Instance.new("Folder")
	folder.Name = "Asteroids"
	for index = 1, WorldConfig.ASTEROID_COUNT do
		local asteroid = Instance.new("Part")
		asteroid.Name = `Asteroid{index}`
		asteroid.Shape = Enum.PartType.Ball
		asteroid.Size = Vector3.one * random:NextNumber(WorldConfig.MIN_SIZE, WorldConfig.MAX_SIZE)
		asteroid.CFrame = CFrame.new(randomInField(random))
		asteroid.Material = Enum.Material.Slate
		asteroid.Color = ZoneLooks.FIELD_ROCK_COLORS[random:NextInteger(1, #ZoneLooks.FIELD_ROCK_COLORS)]
		asteroid.Anchored = true
		asteroid.CanTouch = false
		asteroid.Parent = folder
	end
	folder.Parent = parent
end

-- A nest asteroid with a bowl on top, in its zone's colors.
local function buildNest(
	name: string,
	center: Vector3,
	size: number,
	look: ZoneLooks.ZoneLook,
	random: Random
): NestSite
	local model = Instance.new("Model")
	model.Name = name

	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * size
	rock.CFrame = CFrame.new(center)
	rock.Material = look.rockMaterial
	rock.Color = look.rockColors[random:NextInteger(1, #look.rockColors)]
	rock.Anchored = true
	rock.CanTouch = false
	rock.Parent = model

	-- The bowl sits a little into the rock's top so it looks embedded.
	local top = center + Vector3.yAxis * (size / 2 - 0.6)
	local bowl = disc("Bowl", top, NEST_BOWL_RADIUS, NEST_BOWL_THICKNESS)
	bowl.Material = Enum.Material.Basalt
	bowl.Color = NEST_BOWL_COLOR
	bowl.Anchored = true
	bowl.CanTouch = false
	bowl.Parent = model

	model.PrimaryPart = rock
	return {
		id = name,
		model = model,
		-- Filled by the caller.
		zone = "DebrisBelt",
		eggCFrame = CFrame.new(top + Vector3.yAxis * NEST_EGG_LIFT),
	}
end

-- Nest asteroids zone by zone: evenly spread around each zone's ring with seeded jitter.
local function buildNests(parent: Instance): { NestSite }
	local random = Random.new(WorldConfig.SEED + 1)
	local folder = Instance.new("Folder")
	folder.Name = "Nests"
	local sites: { NestSite } = {}

	for _, zoneId in ZoneConfig.ZONE_ORDER do
		local zone = ZoneConfig.ZONES[zoneId]
		local look = ZoneLooks.ZONES[zoneId]
		for index = 1, zone.nestCount do
			local angle = (index - 1 + random:NextNumber(-0.3, 0.3)) / zone.nestCount * math.pi * 2
			local distance = random:NextNumber(zone.ringMin, zone.ringMax)
			local height = random:NextNumber(-zone.heightSpread, zone.heightSpread)
			local center = StationConfig.PLATFORM_CENTER
				+ Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
			local size = random:NextNumber(WorldConfig.NEST_ASTEROID_MIN_SIZE, WorldConfig.NEST_ASTEROID_MAX_SIZE)
			local site = buildNest(`{zoneId}Nest{index}`, center, size, look, random)
			site.zone = zoneId
			site.model.Parent = folder
			table.insert(sites, site)
		end
	end

	folder.Parent = parent
	return sites
end

-- Landmarks that tell the zones apart from afar: a band of ice, a red haze, the black hole.
local function buildLandmarks(parent: Instance)
	local random = Random.new(WorldConfig.SEED + 2)
	local folder = Instance.new("Folder")
	folder.Name = "Landmarks"
	local center = StationConfig.PLATFORM_CENTER

	local ice = ZoneConfig.ZONES.IceRings
	for index = 1, ZoneLooks.ICE_CHUNK_COUNT do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(ice.ringMin, ice.ringMax)
		local chunk = Instance.new("Part")
		chunk.Name = `Ice{index}`
		chunk.Shape = Enum.PartType.Ball
		chunk.Size = Vector3.one * random:NextNumber(ZoneLooks.ICE_CHUNK_MIN_SIZE, ZoneLooks.ICE_CHUNK_MAX_SIZE)
		chunk.CFrame = CFrame.new(
			center
				+ Vector3.new(
					math.cos(angle) * distance,
					random:NextNumber(-ZoneLooks.ICE_BAND_HEIGHT, ZoneLooks.ICE_BAND_HEIGHT),
					math.sin(angle) * distance
				)
		)
		chunk.Material = Enum.Material.Ice
		chunk.Color = ZoneLooks.ICE_COLOR
		chunk.CanCollide = false
		scenery(chunk)
		chunk.Parent = folder
	end

	local nebula = ZoneConfig.ZONES.RedNebula
	for index = 1, ZoneLooks.HAZE_COUNT do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(nebula.ringMin, nebula.ringMax)
		local haze = Instance.new("Part")
		haze.Name = `Haze{index}`
		haze.Shape = Enum.PartType.Ball
		haze.Size = Vector3.one * random:NextNumber(ZoneLooks.HAZE_MIN_SIZE, ZoneLooks.HAZE_MAX_SIZE)
		haze.CFrame = CFrame.new(
			center
				+ Vector3.new(
					math.cos(angle) * distance,
					random:NextNumber(-nebula.heightSpread, nebula.heightSpread),
					math.sin(angle) * distance
				)
		)
		haze.Material = Enum.Material.ForceField
		haze.Color = ZoneLooks.HAZE_COLOR
		haze.Transparency = ZoneLooks.HAZE_TRANSPARENCY
		haze.CanCollide = false
		scenery(haze)
		haze.Parent = folder
	end

	local holeAngle = random:NextNumber(0, math.pi * 2)
	local holeCenter = center
		+ Vector3.new(
			math.cos(holeAngle) * ZoneLooks.BLACK_HOLE_DISTANCE,
			0,
			math.sin(holeAngle) * ZoneLooks.BLACK_HOLE_DISTANCE
		)
	local rim = Instance.new("Part")
	rim.Name = "BlackHoleRim"
	rim.Shape = Enum.PartType.Ball
	rim.Size = Vector3.one * ZoneLooks.BLACK_HOLE_RIM_RADIUS * 2
	rim.CFrame = CFrame.new(holeCenter)
	rim.Material = Enum.Material.Neon
	rim.Color = ZoneLooks.BLACK_HOLE_RIM_COLOR
	rim.Transparency = ZoneLooks.BLACK_HOLE_RIM_TRANSPARENCY
	rim.CanCollide = false
	scenery(rim)
	rim.Parent = folder
	local hole = Instance.new("Part")
	hole.Name = "BlackHole"
	hole.Shape = Enum.PartType.Ball
	hole.Size = Vector3.one * ZoneLooks.BLACK_HOLE_RADIUS * 2
	hole.CFrame = CFrame.new(holeCenter)
	hole.Material = Enum.Material.SmoothPlastic
	hole.Color = ZoneLooks.BLACK_HOLE_COLOR
	hole.CanCollide = false
	scenery(hole)
	hole.Parent = folder

	folder.Parent = parent
end

-- The visible edge of the map. A part cannot be wider than MAX_PART_SIZE, so the sphere is a
-- mesh scaled past it; the real wall is in the simulation (Bounds).
local MAX_PART_SIZE = 2048

local function buildBoundary(parent: Instance)
	local shell = Instance.new("Part")
	shell.Name = "Boundary"
	shell.Size = Vector3.one * MAX_PART_SIZE
	shell.CFrame = CFrame.new(StationConfig.PLATFORM_CENTER)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.one * (WorldConfig.BOUNDARY_RADIUS * 2 / MAX_PART_SIZE)
	mesh.Parent = shell
	shell.Material = Enum.Material.ForceField
	shell.Color = BOUNDARY_COLOR
	shell.Transparency = BOUNDARY_TRANSPARENCY
	shell.CanCollide = false
	scenery(shell)
	shell.Parent = parent
end

local function configureLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(90, 96, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 126, 155)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.FogEnd = 1e5

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = STAR_COUNT
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	-- Space has no air: a hazy atmosphere would hide the asteroid field.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0
		atmosphere.Haze = 0
		atmosphere.Glare = 0
	end
end

function WorldService.new(): WorldService
	local spawn: SpawnLocation? = nil
	local nestSites: { NestSite } = {}

	local function start()
		local existing = workspace:FindFirstChild(WORLD_FOLDER_NAME)
		if existing then
			existing:Destroy()
		end
		local world = Instance.new("Folder")
		world.Name = WORLD_FOLDER_NAME
		spawn = buildStation(world)
		local shop = ShopModel.build()
		CollectionService:AddTag(shop, ShopConfig.TAG)
		shop.Parent = world
		buildAsteroids(world)
		nestSites = buildNests(world)
		buildLandmarks(world)
		buildBoundary(world)
		world.Parent = workspace
		configureLighting()
	end

	return {
		name = "WorldService",
		start = start,
		getSpawn = function()
			return spawn
		end,
		getNestSites = function()
			return nestSites
		end,
	}
end

return table.freeze(WorldService)
