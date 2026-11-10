--!strict
-- Builds the greybox world at server start: station platform, dome, spawn, asteroid field and
-- space lighting. Code-owned so the world lives in Git; real models replace the parts later.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BorderLooks = require(ReplicatedStorage.Shared.Config.BorderLooks)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local KioskModel = require(script.Parent.Parent.World.KioskModel)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local LeaderboardModel = require(script.Parent.Parent.World.LeaderboardModel)
local MeteorLooks = require(ReplicatedStorage.Shared.Config.MeteorLooks)
local NestLayout = require(ReplicatedStorage.Shared.Domain.NestLayout)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local SkyLooks = require(ReplicatedStorage.Shared.Config.SkyLooks)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local StationModel = require(script.Parent.Parent.World.StationModel)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local ZoneBlend = require(ReplicatedStorage.Shared.Domain.ZoneBlend)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local ZoneKit = require(script.Parent.Parent.World.ZoneKit)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)
local Zones = require(ReplicatedStorage.Shared.Domain.Zones)

local WORLD_FOLDER_NAME = "World"
local NESTS_FOLDER_NAME = "Nests"
local DOME_TRANSPARENCY = 0.75
local DOME_COLOR = Color3.fromRGB(110, 190, 255)
local PLATFORM_COLOR = Color3.fromRGB(128, 136, 160)
local HULL_COLOR = Color3.fromRGB(70, 76, 94)
-- Glowing rim around the platform: makes the station easy to find from the asteroid field.
local RIM_COLOR = Color3.fromRGB(90, 200, 255)
-- The map edge: a faint shell so players see where space ends (Bounds stops them there).
local BOUNDARY_COLOR = Color3.fromRGB(150, 90, 255)
local BOUNDARY_TRANSPARENCY = 0.9

export type NestSite = {
	id: string,
	model: Model,
	zone: ZoneConfig.ZoneId,
	-- Where an egg rests in this nest.
	eggCFrame: CFrame,
	-- The guardian post within its zone (1 innermost) for a nest of the world's layout
	-- (Domain/NestLayout); nil for a meteor crater, which takes its nearest nest's.
	post: number?,
}

export type WorldService = {
	name: string,
	start: () -> (),
	-- Where players spawn at first, on the central station; nil before the world is built.
	getSpawn: () -> SpawnLocation?,
	-- The spawn on island `index` (its owner's home, decision 068); nil before the world is built.
	getIslandSpawn: (index: number) -> SpawnLocation?,
	-- Nest locations; empty before the world is built.
	getNestSites: () -> { NestSite },
	-- The coin board stand on the platform; nil before the world is built.
	getCoinBoard: () -> Model?,
	-- Builds a meteor crater (a nest of its own) at `center` in the world's nests; nil before
	-- the world is built.
	buildCrater: (name: string, zone: ZoneConfig.ZoneId, center: Vector3) -> NestSite?,
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
local function buildHull(parent: Instance, station: Zones.Station)
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

-- The sphere guardians never cross: a barely visible shell and a ring of neon segments around
-- its equator, at the height of the dome's center.
local function buildBorder(parent: Instance)
	local center = StationConfig.STATION.domeCenter
	local radius = StationConfig.BORDER_RADIUS
	local folder = Instance.new("Folder")
	folder.Name = "StationBorder"

	local shell = Instance.new("Part")
	shell.Name = BorderLooks.SHELL_NAME
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * radius * 2
	shell.CFrame = CFrame.new(center)
	shell.Material = Enum.Material.ForceField
	shell.Color = BorderLooks.COLOR
	shell.Transparency = BorderLooks.SHELL_TRANSPARENCY
	shell.CanCollide = false
	scenery(shell)
	shell.Parent = folder

	-- Each segment is a chord of the circle, a hair longer than the chord so the joints close.
	local thickness = BorderLooks.RING_THICKNESS
	local step = 2 * math.pi / BorderLooks.RING_SEGMENTS
	local chord = 2 * radius * math.sin(step / 2)
	for index = 1, BorderLooks.RING_SEGMENTS do
		local angle = (index - 0.5) * step
		local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * math.cos(step / 2)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local segment = Instance.new("Part")
		segment.Name = `Ring{index}`
		segment.Size = Vector3.new(thickness, thickness, chord + thickness)
		segment.CFrame = CFrame.lookAlong(position, tangent)
		segment.Material = Enum.Material.Neon
		segment.Color = BorderLooks.COLOR
		segment.CanCollide = false
		scenery(segment)
		segment.Parent = folder
	end

	CollectionService:AddTag(folder, BorderLooks.TAG)
	folder.Parent = parent
end

-- A platform under its dome (the central station or an island, decision 068): the walkable
-- floor, a glowing rim, the dome's shell and the hull under it, in `parent`.
local function buildDomedPlatform(parent: Instance, station: Zones.Station)
	local platformCenter = station.platformCenter - Vector3.yAxis * StationConfig.PLATFORM_THICKNESS / 2

	local platform = disc("Platform", platformCenter, station.platformRadius, StationConfig.PLATFORM_THICKNESS)
	platform.Material = Enum.Material.DiamondPlate
	platform.Color = PLATFORM_COLOR
	platform.Anchored = true
	platform.CanTouch = false
	platform.Parent = parent

	local rim = disc(
		"Rim",
		platformCenter,
		station.platformRadius + StationConfig.RIM_WIDTH,
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

	buildHull(parent, station)
end

-- A spawn point at `position`: any player may spawn there.
local function spawnAt(name: string, position: Vector3, parent: Instance): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(position)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Anchored = true
	spawn.CanTouch = false
	spawn.Parent = parent
	return spawn
end

local function buildStation(parent: Instance): SpawnLocation
	StationModel.build(parent)
	local spawn = spawnAt("StationSpawn", StationConfig.PLATFORM_CENTER + StationConfig.SPAWN_OFFSET, parent)
	buildBorder(parent)
	return spawn
end

-- The station's kiosks in their circle (decision 087); the jetpacks' one is the jetpack shop.
local function buildKiosks(parent: Instance)
	for _, kiosk in StationLooks.KIOSKS do
		local model = KioskModel.build(kiosk, KioskModel.frameAt(StationConfig.PLATFORM_CENTER, kiosk.slot))
		if kiosk.id == "Jetpacks" then
			CollectionService:AddTag(model, ShopConfig.TAG)
		end
		model.Parent = parent
	end
end

-- The islands around the station, one per player's bay (decision 068), each with the spawn of
-- its owner. Returns the spawns in island order.
local function buildIslands(parent: Instance): { SpawnLocation }
	local spawns: { SpawnLocation } = {}
	for index, island in StationConfig.ISLANDS do
		local folder = Instance.new("Folder")
		folder.Name = `Island{index}`
		buildDomedPlatform(folder, island)
		local frame = StationConfig.ISLAND_FRAMES[index]
		spawns[index] = spawnAt("IslandSpawn", (frame * CFrame.new(StationConfig.ISLAND_SPAWN_OFFSET)).Position, folder)
		folder.Parent = parent
	end
	return spawns
end

local function randomInField(random: Random): Vector3
	-- Uniform over the disc area between the inner and outer radius.
	local inner, outer = WorldConfig.INNER_RADIUS, WorldConfig.OUTER_RADIUS
	local distance = math.sqrt(random:NextNumber(inner * inner, outer * outer))
	local angle = random:NextNumber(0, math.pi * 2)
	local height = random:NextNumber(-WorldConfig.VERTICAL_SPREAD, WorldConfig.VERTICAL_SPREAD)
	return StationConfig.PLATFORM_CENTER + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
end

local function pickKind(kinds: { ZoneLooks.FieldKind }, random: Random): ZoneLooks.FieldKind
	local total = 0
	for _, kind in kinds do
		total += kind.weight
	end
	local roll = random:NextNumber(0, total)
	for _, kind in kinds do
		roll -= kind.weight
		if roll <= 0 then
			return kind
		end
	end
	return kinds[#kinds]
end

local function randomTurn(random: Random): CFrame
	local tau = math.pi * 2
	return CFrame.Angles(random:NextNumber(0, tau), random:NextNumber(0, tau), random:NextNumber(0, tau))
end

-- A copy of a kit piece about `width` studs wide; nil without the kit.
local function kitPiece(id: string, width: number): MeshPart?
	local part = ZoneKit.piece(id :: ZoneKit.PieceId)
	if part then
		part.Size *= width / ZoneKit.SIZE
	end
	return part
end

-- One rock of the field (ZoneLooks.FIELD): a kit shape of its kind, turned at random, with the
-- crystals or the ring its kind carries. Without the kit, a ball.
local function buildFieldRock(
	name: string,
	kind: ZoneLooks.FieldKind,
	at: Vector3,
	width: number,
	random: Random,
	parent: Instance
)
	local frame = CFrame.new(at) * randomTurn(random)
	local rock: BasePart? = kitPiece(kind.pieces[random:NextInteger(1, #kind.pieces)], width)
	if rock then
		rock.Size *= kind.stretch or Vector3.one
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * width
		rock = ball
	end
	local part = rock :: BasePart
	part.Name = name
	part.CFrame = frame
	part.Material = kind.material
	part.Color = kind.colors[random:NextInteger(1, #kind.colors)]
	part.Transparency = kind.transparency or 0
	part.Anchored = true
	part.CanTouch = false
	part.CanCollide = not kind.loose
	part.CanQuery = not kind.loose
	part.Parent = parent

	local crystals = kind.crystals
	if crystals then
		local bunch = kitPiece(if random:NextNumber() < 0.5 then "Crystals1" else "Crystals2", width * 0.9)
		if bunch then
			-- Rooted a little into the rock's top, growing out along its up.
			bunch.Name = `{name}Crystals`
			bunch.CFrame = frame * CFrame.new(0, part.Size.Y * 0.3 + bunch.Size.Y * 0.35, 0)
			bunch.Material = Enum.Material.Glass
			bunch.Color = crystals.color
			bunch.Transparency = crystals.transparency
			scenery(bunch)
			bunch.CanCollide = false
			bunch.Parent = parent
		end
	end
	if kind.ring then
		local ring = kitPiece("Ring", width * 1.6)
		if ring then
			ring.Name = `{name}Ring`
			ring.CFrame = CFrame.new(at) * CFrame.Angles(random:NextNumber(-0.6, 0.6), random:NextNumber(0, math.pi), 0)
			ring.Material = Enum.Material.Neon
			ring.Color = kind.ring
			scenery(ring)
			ring.CanCollide = false
			ring.Parent = parent
		end
	end
end

-- The asteroid field: rocks of the zone each floats in (Domain/ZoneBlend: across the gap between
-- two zones' rings, a mix), seeded, so every server builds the same field.
local function buildAsteroids(parent: Instance)
	local random = Random.new(WorldConfig.SEED)
	local folder = Instance.new("Folder")
	folder.Name = "Asteroids"
	for index = 1, WorldConfig.ASTEROID_COUNT do
		local at = randomInField(random)
		local width = random:NextNumber(WorldConfig.MIN_SIZE, WorldConfig.MAX_SIZE)
		local offset = at - StationConfig.PLATFORM_CENTER
		local zone = ZoneBlend.pick(Vector3.new(offset.X, 0, offset.Z).Magnitude, random:NextNumber())
		buildFieldRock(`Asteroid{index}`, pickKind(ZoneLooks.FIELD[zone], random), at, width, random, folder)
	end
	folder.Parent = parent
end

-- Debris Belt: wrecked plates and girders drifting through the zone, some with a little light.
local function buildScrap(parent: Instance)
	local random = Random.new(WorldConfig.SEED + 4)
	local zone = ZoneConfig.ZONES.DebrisBelt
	local folder = Instance.new("Folder")
	folder.Name = "Scrap"
	for index = 1, ZoneLooks.SCRAP_COUNT do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(zone.ringMin, zone.ringMax)
		local at = StationConfig.PLATFORM_CENTER
			+ Vector3.new(
				math.cos(angle) * distance,
				random:NextNumber(-zone.heightSpread, zone.heightSpread),
				math.sin(angle) * distance
			)
		local length = random:NextNumber(ZoneLooks.SCRAP_LENGTH.Min, ZoneLooks.SCRAP_LENGTH.Max)
		local piece = Instance.new("Part")
		piece.Name = `Scrap{index}`
		-- Every other one a flat hull plate, the rest girders.
		piece.Size = if index % 2 == 0 then Vector3.new(length * 0.6, 0.4, length) else Vector3.new(0.8, 0.8, length)
		piece.CFrame = CFrame.new(at) * randomTurn(random)
		piece.Material = if index % 2 == 0 then Enum.Material.DiamondPlate else Enum.Material.Metal
		piece.Color = ZoneLooks.SCRAP_COLORS[random:NextInteger(1, #ZoneLooks.SCRAP_COLORS)]
		piece.CanCollide = false
		scenery(piece)
		piece.Parent = folder
		if index % ZoneLooks.SCRAP_LIGHT_EVERY == 0 then
			local light = Instance.new("Part")
			light.Name = `Scrap{index}Light`
			light.Shape = Enum.PartType.Ball
			light.Size = Vector3.one * 0.7
			light.CFrame = piece.CFrame * CFrame.new(0, piece.Size.Y / 2 + 0.3, length * 0.35)
			light.Material = Enum.Material.Neon
			light.Color = ZoneLooks.SCRAP_LIGHT_COLOR
			light.CanCollide = false
			scenery(light)
			light.Parent = folder
		end
	end
	folder.Parent = parent
end

-- How a nest looks: its rock and pad (the zone's, ZoneLooks) and its accent, the rim and the
-- cradle (its guardian's colour).
type NestLook = {
	rockMaterial: Enum.Material,
	rockColor: Color3,
	padMaterial: Enum.Material,
	padColor: Color3,
	accent: Color3,
}

-- A part of a nest: anchored; the rock, pillar and pad are solid, the rim and cradle only a look.
local function nestPart(part: BasePart, model: Model, collides: boolean)
	part.Anchored = true
	part.CanTouch = false
	part.CanCollide = collides
	part.CanQuery = collides
	part.Parent = model
end

-- A ring of the kit lying flat, `radius` out to its middle; nil without the kit.
local function ring(name: string, center: Vector3, radius: number, thickness: number): MeshPart?
	local part = ZoneKit.piece("Ring")
	if not part then
		return nil
	end
	part.Name = name
	part.Size = Vector3.new(radius * 2 + thickness, thickness, radius * 2 + thickness)
	part.CFrame = CFrame.new(center)
	return part
end

-- A nest (ZoneLooks.NEST): a flat-topped rock `size` wide, a pillar, a wide landing pad with a
-- glowing rim and a cradle in the middle where the egg lies. Without the zones' kit in the place
-- the rock is a ball and the rim and cradle are left out.
local function buildNest(
	name: string,
	zone: ZoneConfig.ZoneId,
	center: Vector3,
	size: number,
	look: NestLook,
	random: Random
): NestSite
	local shape = ZoneLooks.NEST
	local model = Instance.new("Model")
	model.Name = name

	local rock: BasePart
	local kitRock = ZoneKit.piece(if random:NextNumber() < 0.5 then "NestRock1" else "NestRock2")
	if kitRock then
		kitRock.Size = shape.rockStretch * size
		kitRock.CFrame = CFrame.new(center) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		rock = kitRock
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * size
		ball.CFrame = CFrame.new(center)
		rock = ball
	end
	rock.Name = "Rock"
	rock.Material = look.rockMaterial
	rock.Color = look.rockColor
	nestPart(rock, model, true)

	-- The pillar stands a little into the rock's top so it looks rooted.
	local rockTop = center.Y + rock.Size.Y / 2 - 0.3
	local pillarCenter = Vector3.new(center.X, rockTop + shape.pillarHeight / 2, center.Z)
	local pillar = disc("Pillar", pillarCenter, shape.pillarRadius, shape.pillarHeight + 0.3)
	pillar.Material = look.padMaterial
	pillar.Color = look.padColor
	nestPart(pillar, model, true)

	local padCenter = pillarCenter + Vector3.yAxis * (shape.pillarHeight / 2 + shape.padThickness / 2)
	local pad = disc("Pad", padCenter, shape.padRadius, shape.padThickness)
	pad.Material = look.padMaterial
	pad.Color = look.padColor
	nestPart(pad, model, true)

	local padTop = padCenter + Vector3.yAxis * (shape.padThickness / 2)
	local rim = ring("Rim", padTop, shape.padRadius - shape.rimThickness / 2, shape.rimThickness)
	if rim then
		rim.Material = Enum.Material.Neon
		rim.Color = look.accent
		nestPart(rim, model, false)
	end
	local cradle = ring("Cradle", padTop, shape.cradleRadius, shape.cradleThickness)
	if cradle then
		cradle.Material = shape.cradleMaterial
		cradle.Color = look.accent
		nestPart(cradle, model, false)
	end

	model.PrimaryPart = rock
	return {
		id = name,
		model = model,
		zone = zone,
		-- Where a medium egg lies; any egg stands on its bottom there (EggLooks.liftOf).
		eggCFrame = CFrame.new(padTop + Vector3.yAxis * (shape.eggGap + EggLooks.EGG_SIZE.Y / 2)),
	}
end

-- A meteor's crater: a small scorched nest rock, glowing (MeteorLooks.CRATER).
local function buildCrater(name: string, zone: ZoneConfig.ZoneId, center: Vector3): NestSite
	local looks = MeteorLooks.CRATER
	local site = buildNest(name, zone, center, looks.rockSize, {
		rockMaterial = looks.rockMaterial,
		rockColor = looks.rockColor,
		padMaterial = looks.rockMaterial,
		padColor = looks.rockColor,
		accent = looks.glowColor,
	}, Random.new())
	local glow = Instance.new("PointLight")
	glow.Color = looks.glowColor
	glow.Range = looks.glowRange
	glow.Brightness = looks.glowBrightness
	glow.Parent = site.model.PrimaryPart
	return site
end

-- Nest asteroids zone by zone, each guardian post on its own ring within the zone's
-- (Domain/NestLayout), with seeded jitter.
local function buildNests(parent: Instance): { NestSite }
	local random = Random.new(WorldConfig.SEED + 1)
	local function roll(): number
		return random:NextNumber()
	end
	-- The rocks' shapes and turns roll apart, so the nests stay where they were.
	local shapes = Random.new(WorldConfig.SEED + 3)
	local folder = Instance.new("Folder")
	folder.Name = NESTS_FOLDER_NAME
	local sites: { NestSite } = {}

	for _, zoneId in ZoneConfig.ZONE_ORDER do
		local zone = ZoneConfig.ZONES[zoneId]
		local look = ZoneLooks.ZONES[zoneId]
		for index, spot in NestLayout.place(zone, roll) do
			local center = StationConfig.PLATFORM_CENTER
				+ Vector3.new(math.cos(spot.angle) * spot.distance, spot.height, math.sin(spot.angle) * spot.distance)
			local size = random:NextNumber(WorldConfig.NEST_ASTEROID_MIN_SIZE, WorldConfig.NEST_ASTEROID_MAX_SIZE)
			local post = GuardianConfig.POSTS[ZoneConfig.postIndex(zoneId, spot.post)]
			local site = buildNest(`{zoneId}Nest{index}`, zoneId, center, size, {
				rockMaterial = look.rockMaterial,
				rockColor = look.rockColors[random:NextInteger(1, #look.rockColors)],
				padMaterial = look.padMaterial,
				padColor = look.padColor,
				accent = GuardianLooks.POSTS[post.id].color,
			}, shapes)
			site.post = spot.post
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
		local size = random:NextNumber(ZoneLooks.ICE_CHUNK_MIN_SIZE, ZoneLooks.ICE_CHUNK_MAX_SIZE)
		local chunk: BasePart
		local kitChunk = kitPiece(if index % 2 == 0 then "IceChunk1" else "IceChunk2", size)
		if kitChunk then
			chunk = kitChunk
		else
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.one * size
			chunk = ball
		end
		chunk.Name = `Ice{index}`
		chunk.CFrame = CFrame.new(
			center
				+ Vector3.new(
					math.cos(angle) * distance,
					random:NextNumber(-ZoneLooks.ICE_BAND_HEIGHT, ZoneLooks.ICE_BAND_HEIGHT),
					math.sin(angle) * distance
				)
		) * CFrame.Angles(index, index * 1.7, index * 0.3)
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
	Lighting.ClockTime = SkyLooks.CLOCK_TIME
	Lighting.GeographicLatitude = SkyLooks.LATITUDE
	Lighting.Brightness = SkyLooks.BRIGHTNESS
	Lighting.Ambient = SkyLooks.AMBIENT
	Lighting.OutdoorAmbient = SkyLooks.OUTDOOR_AMBIENT
	Lighting.ColorShift_Top = SkyLooks.COLOR_SHIFT_TOP
	Lighting.EnvironmentDiffuseScale = SkyLooks.ENVIRONMENT_DIFFUSE
	Lighting.EnvironmentSpecularScale = SkyLooks.ENVIRONMENT_SPECULAR
	Lighting.GlobalShadows = SkyLooks.GLOBAL_SHADOWS
	Lighting.FogEnd = 1e5

	-- Our own space skybox, and the sun in it (the stars are in the skybox).
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.SkyboxFt = SkyLooks.SKYBOX.Ft
	sky.SkyboxBk = SkyLooks.SKYBOX.Bk
	sky.SkyboxLf = SkyLooks.SKYBOX.Lf
	sky.SkyboxRt = SkyLooks.SKYBOX.Rt
	sky.SkyboxUp = SkyLooks.SKYBOX.Up
	sky.SkyboxDn = SkyLooks.SKYBOX.Dn
	sky.StarCount = 0
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = SkyLooks.SUN_ANGULAR_SIZE
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
	local islandSpawns: { SpawnLocation } = {}
	local nestSites: { NestSite } = {}
	local coinBoard: Model? = nil

	local function start()
		local existing = workspace:FindFirstChild(WORLD_FOLDER_NAME)
		if existing then
			existing:Destroy()
		end
		local world = Instance.new("Folder")
		world.Name = WORLD_FOLDER_NAME
		spawn = buildStation(world)
		islandSpawns = buildIslands(world)
		buildKiosks(world)
		local board = LeaderboardModel.build()
		CollectionService:AddTag(board, LeaderboardConfig.TAG)
		board.Parent = world
		coinBoard = board
		buildAsteroids(world)
		buildScrap(world)
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
		getIslandSpawn = function(index)
			return islandSpawns[index]
		end,
		getNestSites = function()
			return nestSites
		end,
		getCoinBoard = function()
			return coinBoard
		end,
		buildCrater = function(name, zone, center)
			local world = workspace:FindFirstChild(WORLD_FOLDER_NAME)
			local folder = world and world:FindFirstChild(NESTS_FOLDER_NAME)
			if not folder then
				return nil
			end
			local site = buildCrater(name, zone, center)
			site.model.Parent = folder
			return site
		end,
	}
end

return table.freeze(WorldService)
