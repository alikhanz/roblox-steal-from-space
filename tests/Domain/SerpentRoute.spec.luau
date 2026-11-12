--!strict

local roblox = require("@lune/roblox")

local SerpentConfig = require("../../src/shared/Config/SerpentConfig")
local SerpentRoute = require("../../src/shared/Domain/SerpentRoute")
local StationSize = require("../../src/shared/Config/StationSize")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local TUNING = SerpentConfig.ROUTE
local BAND: SerpentRoute.Band = {
	center = Vector3.new(0, 50, 0),
	up = Vector3.new(0, 1, 0),
	across = Vector3.new(1, 0, 0),
	inner = SerpentConfig.INNER_RADIUS,
	outer = SerpentConfig.OUTER_RADIUS,
	height = SerpentConfig.ROUTE_HEIGHT,
}
local TICK = SerpentConfig.TICK_SECONDS

-- Dice that roll the same every run.
local function dice(seed: number): SerpentRoute.Roll
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function flatRadius(position: Vector3): number
	return (SerpentRoute.locate(BAND, position))
end

type Flight = {
	positions: { Vector3 },
	headings: { Vector3 },
	-- Where the chaser was each tick, if there was one.
	chasers: { Vector3 },
}

type Start = { position: Vector3, heading: Vector3 }

-- Flies the route for `seconds` from `start` at `speed`; with `chaseSpeed`, a player starts
-- 100 studs behind and flies straight at it, and it flees them.
local function fly(start: Start, seconds: number, speed: number, seed: number, chaseSpeed: number?): Flight
	local roll = dice(seed)
	local position = start.position
	local heading = start.heading
	local route = SerpentRoute.start(BAND, TUNING, position, roll)
	local chaser = if chaseSpeed then position - heading * 100 else nil
	local flight: Flight = { positions = {}, headings = {}, chasers = {} }
	for _ = 1, math.floor(seconds / TICK) do
		route, heading = SerpentRoute.step(route, BAND, TUNING, position, heading, speed, TICK, roll, chaser)
		position += heading * speed * TICK
		if chaser and chaseSpeed then
			local toward = position - chaser
			if toward.Magnitude > 1 then
				chaser += toward.Unit * math.min(chaseSpeed * TICK, toward.Magnitude)
			end
			table.insert(flight.chasers, chaser)
		end
		table.insert(flight.positions, position)
		table.insert(flight.headings, heading)
	end
	return flight
end

-- Where it comes out (the middle of a zone, facing the station), and where it may be once its
-- egg is back inside after it guarded it: at the inner edge, at the outer one, flying along it
-- (the service's bounds keep it from flying through them: Bounds.keepOutside, limitVelocity).
local function facingStation(position: Vector3): Start
	return { position = position, heading = (BAND.center - position).Unit }
end
local STARTS: { Start } = {
	facingStation(Vector3.new(1500, 50, 0)),
	facingStation(Vector3.new(0, 50, -2200)),
	facingStation(Vector3.new(-2700, 50, 900)),
	{ position = Vector3.new(0, 50, SerpentConfig.INNER_RADIUS + 5), heading = Vector3.new(1, 0, 0) },
	{ position = Vector3.new(SerpentConfig.OUTER_RADIUS - 5, 50, 0), heading = Vector3.new(0, 0, -1) },
}

-- Every flight tried: each start, a few dice, roaming and fleeing at the fastest flee speed.
local function everyFlight(check: (Flight, number) -> ())
	for index, start in STARTS do
		for seed = 1, 4 do
			check(fly(start, 400, SerpentConfig.ROAM_SPEED, seed * 7 + index), SerpentConfig.ROAM_SPEED)
			local flee = SerpentConfig.fleeSpeedIn("EventHorizon")
			check(fly(start, 120, flee, seed * 13 + index, flee * 1.05), flee)
		end
	end
end

describe("SerpentRoute", function()
	it("never comes near a dome: it stays past every dome and past the station border", function()
		-- Every dome lies within this distance of the station's axis, across.
		local domes = math.max(StationSize.DOME_RADIUS, StationSize.ISLAND_RING_RADIUS + StationSize.ISLAND_DOME_RADIUS)
		expect(SerpentConfig.INNER_RADIUS > StationSize.BORDER_RADIUS).toBe(true)
		everyFlight(function(flight)
			for index, position in flight.positions do
				expect(flatRadius(position) > StationSize.BORDER_RADIUS).toBe(true)
				expect(flatRadius(position) > domes).toBe(true)
				-- Facing the station as it comes out, it may still be turning off it at first.
				if index > 15 / TICK then
					expect(flatRadius(position) >= BAND.inner).toBe(true)
				end
			end
		end)
	end)

	it("stays within the map's edge and its height", function()
		everyFlight(function(flight)
			for index, position in flight.positions do
				if index > 15 / TICK then
					expect((position - BAND.center).Magnitude <= BAND.outer + 1).toBe(true)
					local height = math.abs((position - BAND.center):Dot(BAND.up))
					expect(height <= BAND.height + TUNING.turnRadius * 2).toBe(true)
				end
			end
		end)
	end)

	it("never turns tighter than its turn radius", function()
		everyFlight(function(flight, speed)
			local most = speed * TICK / TUNING.turnRadius + 1e-4
			for index = 2, #flight.headings do
				local cos = math.clamp(flight.headings[index]:Dot(flight.headings[index - 1]), -1, 1)
				expect(math.acos(cos) <= most).toBe(true)
			end
		end)
	end)

	it("keeps turning: no long straight run", function()
		-- In any 15 seconds the heading turns by at least 20 degrees.
		local window = math.floor(15 / TICK)
		everyFlight(function(flight)
			for index = window + 1, #flight.headings, window do
				local turned = 0
				for step = index - window + 1, index do
					local cos = math.clamp(flight.headings[step]:Dot(flight.headings[step - 1]), -1, 1)
					turned += math.acos(cos)
				end
				expect(turned >= math.rad(20)).toBe(true)
			end
		end)
	end)

	it("roams the whole band: near the station and far out, all the way round", function()
		local width = BAND.outer - BAND.inner
		for seed = 1, 3 do
			local flight = fly(STARTS[1], 1800, SerpentConfig.ROAM_SPEED, seed, nil)
			local nearest, farthest = math.huge, 0
			local sides: { [number]: boolean } = {}
			for _, position in flight.positions do
				local radius, outward = SerpentRoute.locate(BAND, position)
				nearest = math.min(nearest, radius)
				farthest = math.max(farthest, radius)
				local angle = math.atan2(outward.Z, outward.X)
				sides[math.floor((angle + math.pi) / (math.pi / 2))] = true
			end
			expect(nearest < BAND.inner + width * 0.35).toBe(true)
			expect(farthest > BAND.inner + width * 0.65).toBe(true)
			-- Every quarter round the station.
			expect(sides[0] and sides[1] and sides[2] and sides[3]).toBe(true)
		end
	end)

	-- The nearest a chaser came to it.
	local function closest(flight: Flight): number
		local nearest = math.huge
		for index, position in flight.positions do
			nearest = math.min(nearest, (position - flight.chasers[index]).Magnitude)
		end
		return nearest
	end

	it("flees: a player with its stat catches it, a much slower one never does", function()
		local speed = SerpentConfig.fleeSpeedIn("RedNebula")
		for seed = 1, 8 do
			-- A player with its stat flies this much faster than it flees.
			local matched = fly(STARTS[1], 60, speed, seed, speed / SerpentConfig.FLEE_SPEED_SHARE)
			expect(closest(matched) < 5).toBe(true)
			local slow = fly(STARTS[1], 60, speed, seed, speed * 0.85)
			expect(closest(slow) > 20).toBe(true)
		end
	end)

	it("picks a waypoint away from a threat that its waypoint lies towards", function()
		local roll = dice(3)
		local position = Vector3.new(1500, 50, 0)
		local heading = Vector3.new(0, 0, 1)
		local route = { goal = Vector3.new(1500, 50, 400), turn = 1, age = 5 }
		-- The threat sits right on the way to the waypoint.
		local threat = Vector3.new(1500, 50, 120)
		local next = SerpentRoute.step(route, BAND, TUNING, position, heading, 100, TICK, roll, threat)
		local toGoal = (next.goal - position).Unit
		local toThreat = (threat - position).Unit
		expect(toGoal:Dot(toThreat) < math.cos(TUNING.threatAngle)).toBe(true)
		expect(next.age).toBe(0)
	end)

	it("turns towards its waypoint, but no faster than it may", function()
		local heading = Vector3.new(1, 0, 0)
		local turned = SerpentRoute.turnToward(BAND, heading, Vector3.new(0, 0, 1), 0.1)
		expect(math.acos(turned:Dot(heading))).toBeCloseTo(0.1, 1e-6)
		expect(turned.Z > 0).toBe(true)
		-- Straight behind, it still turns, across the band's plane.
		local back = SerpentRoute.turnToward(BAND, heading, Vector3.new(-1, 0, 0), 0.1)
		expect(math.acos(back:Dot(heading))).toBeCloseTo(0.1, 1e-6)
		expect(math.abs(back.Y) < 1e-6).toBe(true)
	end)
end)
