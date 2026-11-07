--!strict
-- Station layout (decision 068): the central platform and, on a ring around it, one island per
-- player's bay. Each sits under its own dome like a bubble; under a dome, right above its
-- platform, is a station zone (walking with gravity); everything else is open space. The sizes
-- all come from StationSize.

local StationSize = require("./StationSize")
local Zones = require("../Domain/Zones")

-- Top surface of the central platform, the station's reference point.
local PLATFORM_CENTER = Vector3.zero
local PLATFORM_RADIUS = StationSize.PLATFORM_RADIUS
local PLATFORM_THICKNESS = 4
local RIM_WIDTH = 2
local DOME_RADIUS = StationSize.DOME_RADIUS

-- A station zone on the platform whose top surface is centred at `center`: the dome raised so
-- its sphere meets the platform exactly at the rim.
local function stationAt(center: Vector3, platformRadius: number, domeRadius: number): Zones.Station
	local rise = math.sqrt(domeRadius ^ 2 - (platformRadius + RIM_WIDTH) ^ 2)
	return table.freeze({
		domeCenter = center + Vector3.yAxis * rise,
		domeRadius = domeRadius,
		platformCenter = center,
		platformRadius = platformRadius,
		floorY = center.Y - PLATFORM_THICKNESS,
	})
end

local STATION = stationAt(PLATFORM_CENTER, PLATFORM_RADIUS, DOME_RADIUS)

-- The frame of island `index` (1-based): its platform's top centre on the ring, facing the
-- station center. Bays are built in this frame (BayModel.origin).
local function islandFrame(index: number): CFrame
	local angle = (index - 1) / StationSize.ISLAND_COUNT * math.pi * 2
	local radius = StationSize.ISLAND_RING_RADIUS
	local position = PLATFORM_CENTER + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	return CFrame.lookAt(position, Vector3.new(PLATFORM_CENTER.X, position.Y, PLATFORM_CENTER.Z))
end

local ISLANDS: { Zones.Station } = {}
local ISLAND_FRAMES: { CFrame } = {}
for index = 1, StationSize.ISLAND_COUNT do
	local frame = islandFrame(index)
	ISLAND_FRAMES[index] = frame
	ISLANDS[index] = stationAt(frame.Position, StationSize.ISLAND_RADIUS, StationSize.ISLAND_DOME_RADIUS)
end

-- Every station zone: the center first, then the islands in their order.
local STATIONS: { Zones.Station } = { STATION }
for _, island in ISLANDS do
	table.insert(STATIONS, island)
end

return table.freeze({
	-- The central station.
	STATION = STATION,
	ISLANDS = table.freeze(ISLANDS),
	ISLAND_FRAMES = table.freeze(ISLAND_FRAMES),
	STATIONS = table.freeze(STATIONS),
	PLATFORM_CENTER = PLATFORM_CENTER,
	PLATFORM_RADIUS = PLATFORM_RADIUS,
	PLATFORM_THICKNESS = PLATFORM_THICKNESS,
	RIM_WIDTH = RIM_WIDTH,
	-- Studs past the boundary needed to switch between walking and flying (see Zones.nextInSpace).
	ZONE_MARGIN = 3,
	-- The hull under a platform hides the part of the dome sphere that pokes out below.
	HULL_STEPS = 4,
	-- The station border (StationSize), from the central dome's center, studs: drawn as a faint
	-- shell with a glowing ring.
	BORDER_RADIUS = StationSize.BORDER_RADIUS,
	SPAWN_OFFSET = Vector3.new(0, 0.5, StationSize.SPAWN_DISTANCE),
	-- A player's spawn on their island, in the island's frame (toward the station center).
	ISLAND_SPAWN_OFFSET = Vector3.new(0, 0.5, -StationSize.ISLAND_SPAWN_DISTANCE),
	BAY_RING_RADIUS = StationSize.BAY_RING_RADIUS,
})
