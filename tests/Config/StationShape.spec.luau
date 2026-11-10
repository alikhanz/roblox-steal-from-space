--!strict
-- The central station's shape (decision 087): the hull, the ring of screens and its struts fit the
-- platform and dome they are built round, and the numbers match the kit Blender models.

local fs = require("@lune/fs")

local StationShape = require("../../src/shared/Config/StationShape")
local StationSize = require("../../src/shared/Config/StationSize")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- The dome sphere's radius at height `y` above the platform's top (0 above or below the sphere).
local function domeRadiusAt(y: number): number
	local fromCenter = y - StationSize.DOME_RISE
	return math.sqrt(math.max(0, StationSize.DOME_RADIUS ^ 2 - fromCenter ^ 2))
end

-- A number constant `NAME = 1.5` of the Blender kit script.
local function blender(source: string, name: string): number
	local value = string.match(source, `\n{name} = ([%d%.]+)`)
	return assert(tonumber(value), `station_kit.py has no {name}`)
end

describe("StationShape", function()
	it("hides the dome's sphere below the floor inside the hull", function()
		local floorDepth = StationSize.PLATFORM_THICKNESS
		local sphereBottom = StationSize.DOME_RADIUS - StationSize.DOME_RISE
		expect(floorDepth + StationShape.HULL_DEPTH > sphereBottom).toBe(true)
		for depth = 0, StationShape.HULL_DEPTH, 0.5 do
			expect(StationShape.hullRadiusAt(depth) >= domeRadiusAt(-floorDepth - depth)).toBe(true)
		end
	end)

	it("keeps the ring clear of the dome and of the islands' domes", function()
		local bottom = StationShape.RING_LIFT - StationShape.RING_HEIGHT / 2
		local top = StationShape.RING_LIFT + StationShape.RING_HEIGHT / 2
		for y = bottom, top, 0.5 do
			expect(StationShape.RING_INNER_RADIUS > domeRadiusAt(y)).toBe(true)
		end
		-- High on the dome, but below its top: the ring circles it, it doesn't hang above it.
		expect(top < StationSize.DOME_RISE + StationSize.DOME_RADIUS).toBe(true)
		local nearestIsland = StationSize.ISLAND_RING_RADIUS - StationSize.ISLAND_DOME_RADIUS
		expect(StationShape.RING_OUTER_RADIUS < nearestIsland).toBe(true)
	end)

	it("gives every island its screen, set into its segment", function()
		expect(StationShape.RING_SEGMENTS).toBe(StationSize.ISLAND_COUNT)
		-- The screen's corners stay inside the band's outer face.
		local corner = math.sqrt(StationShape.SCREEN_BACK ^ 2 + (StationShape.SCREEN_WIDTH / 2) ^ 2)
		expect(corner < StationShape.RING_OUTER_RADIUS).toBe(true)
		expect(StationShape.SCREEN_BACK > StationShape.RING_INNER_RADIUS).toBe(true)
		expect(StationShape.SCREEN_HEIGHT < StationShape.RING_HEIGHT - 2 * StationShape.RING_TRIM_SIZE).toBe(true)
		-- Narrower than the segment's own share of the ring.
		local chord = 2 * StationShape.SCREEN_BACK * math.sin(math.pi / StationShape.RING_SEGMENTS)
		expect(StationShape.SCREEN_WIDTH < chord).toBe(true)
	end)

	it("stands the struts between screens, from the rim up to the ring's underside", function()
		local segment = 2 * math.pi / StationShape.RING_SEGMENTS
		for index = 1, StationShape.PYLON_COUNT do
			local angle = StationShape.PYLON_FIRST_ANGLE + (index - 1) * 2 * math.pi / StationShape.PYLON_COUNT
			local fromScreen = angle % segment
			expect(fromScreen > segment * 0.25 and fromScreen < segment * 0.75).toBe(true)
		end
		expect(StationShape.PYLON_FOOT_RADIUS >= StationSize.PLATFORM_RADIUS).toBe(true)
		expect(StationShape.PYLON_FOOT_RADIUS <= StationSize.PLATFORM_RADIUS + StationSize.RIM_WIDTH).toBe(true)
		expect(StationShape.PYLON_TOP_RADIUS > StationShape.RING_INNER_RADIUS).toBe(true)
		expect(StationShape.PYLON_TOP_RADIUS < StationShape.RING_OUTER_RADIUS).toBe(true)
		-- The strut leans out as it rises, clear of the dome.
		expect(StationShape.PYLON_TOP_RADIUS > StationShape.PYLON_FOOT_RADIUS).toBe(true)
	end)

	it("stands the kiosks in a circle on the platform, apart, with the spawn between two", function()
		local radius = StationShape.KIOSK_CIRCLE_RADIUS
		local footprint = StationShape.KIOSK_FOOTPRINT_RADIUS
		expect(radius + footprint < StationSize.PLATFORM_RADIUS).toBe(true)
		-- Neighbours leave a walkway between them, wider than a kiosk.
		local neighbours = 2 * radius * math.sin(math.pi / StationShape.KIOSK_SLOTS)
		expect(neighbours - 2 * footprint > 2 * footprint).toBe(true)
		-- The spawn is clear of every kiosk.
		local spawnX = math.cos(StationShape.SPAWN_ANGLE) * StationSize.SPAWN_DISTANCE
		local spawnZ = math.sin(StationShape.SPAWN_ANGLE) * StationSize.SPAWN_DISTANCE
		for slot = 1, StationShape.KIOSK_SLOTS do
			local angle = StationShape.kioskAngle(slot)
			local distance =
				math.sqrt((math.cos(angle) * radius - spawnX) ^ 2 + (math.sin(angle) * radius - spawnZ) ^ 2)
			expect(distance > 2 * footprint).toBe(true)
		end
	end)

	it("matches the kit Blender models (assets/blender/station/station_kit.py)", function()
		local source = fs.readFile("assets/blender/station/station_kit.py")
		local scale = StationShape.SCALE
		expect(blender(source, "RING_SEGMENTS")).toBe(StationShape.RING_SEGMENTS)
		expect(blender(source, "RING_OUTER") * scale).toBeCloseTo(StationShape.RING_OUTER_RADIUS, 1e-6)
		expect(blender(source, "RING_THICKNESS") * scale).toBeCloseTo(
			StationShape.RING_OUTER_RADIUS - StationShape.RING_INNER_RADIUS,
			1e-6
		)
		expect(blender(source, "RING_HEIGHT") * scale).toBeCloseTo(StationShape.RING_HEIGHT, 1e-6)
		expect(blender(source, "SCREEN_BACK") * scale).toBeCloseTo(StationShape.SCREEN_BACK, 1e-6)
		expect(blender(source, "TRIM_SIZE") * scale).toBeCloseTo(StationShape.RING_TRIM_SIZE, 1e-6)
		expect(blender(source, "HULL_TOP_RADIUS") * scale).toBeCloseTo(StationShape.HULL_TOP_RADIUS, 1e-6)
		expect(blender(source, "HULL_BOTTOM_RADIUS") * scale).toBeCloseTo(StationShape.HULL_BOTTOM_RADIUS, 1e-6)
		expect(blender(source, "HULL_DEPTH") * scale).toBeCloseTo(StationShape.HULL_DEPTH, 1e-6)
		expect(blender(source, "ENGINE_COUNT")).toBe(StationShape.ENGINE_COUNT)
		expect(blender(source, "KIOSK_GLOW_RADIUS") * scale).toBeCloseTo(StationShape.KIOSK_FOOTPRINT_RADIUS, 1e-6)
	end)
end)
