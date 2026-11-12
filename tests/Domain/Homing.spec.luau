--!strict

local roblox = require("@lune/roblox")

local Homing = require("../../src/shared/Domain/Homing")
local PvpConfig = require("../../src/shared/Config/PvpConfig")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local BOMB = PvpConfig.BOMB
local STEP = 1 / 60

local function expectVector(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeCloseTo(0, 1e-4)
end

-- A bomb thrown at `targetStart` by a thrower at the origin flying at `throwerVelocity`, aimed
-- along `aim`, against a target moving by `targetVelocityAt(seconds)`. Returns how near they
-- came over the fuse.
local function closest(
	throwerVelocity: Vector3,
	aim: Vector3,
	targetStart: Vector3,
	targetVelocityAt: (number) -> Vector3
): number
	local position = aim * PvpConfig.BOMB_START_STUDS
	-- As PvpService throws it.
	local velocity = Homing.ensureClosing(
		Homing.launchVelocity(throwerVelocity, aim, BOMB.throwSpeed),
		(targetStart - position).Unit,
		targetVelocityAt(0),
		BOMB.throwSpeed
	)
	local target = targetStart
	local nearest = math.huge
	local elapsed = 0
	while elapsed < BOMB.fuseSeconds do
		local targetVelocity = targetVelocityAt(elapsed)
		velocity =
			Homing.steer(position, velocity, target, targetVelocity, BOMB.throwSpeed, BOMB.steerAcceleration, STEP)
		local nextPosition = position + velocity * STEP
		local nextTarget = target + targetVelocity * STEP
		local distance = Homing.closestApproach(position, nextPosition, target, nextTarget)
		nearest = math.min(nearest, distance)
		position, target = nextPosition, nextTarget
		elapsed += STEP
	end
	return nearest
end

describe("Homing.launchVelocity", function()
	it("leaves ahead of a thrower at any flight speed", function()
		local aim = Vector3.new(0, 0, -1)
		for _, speed in { 0, 50, 250, 600 } do
			local thrower = Vector3.new(speed, 0, 0)
			local velocity = Homing.launchVelocity(thrower, aim, BOMB.throwSpeed)
			-- Seen from the thrower, it flies along the aim at the throw speed.
			expectVector(velocity - thrower, aim * BOMB.throwSpeed)
		end
	end)

	it("outruns a thrower flying along the aim", function()
		local aim = Vector3.new(1, 0, 0)
		local thrower = Vector3.new(250, 0, 0)
		local velocity = Homing.launchVelocity(thrower, aim, BOMB.throwSpeed)
		expect(velocity:Dot(aim) > thrower:Dot(aim)).toBe(true)
	end)
end)

describe("Homing.ensureClosing", function()
	local toward = Vector3.new(0, 0, -1)

	it("leaves a throw that already closes fast enough as it is", function()
		local velocity = Vector3.new(0, 0, -300)
		expectVector(Homing.ensureClosing(velocity, toward, Vector3.new(0, 0, -200), 80), velocity)
	end)

	it("speeds a throw up along the line to a faster target", function()
		-- The thrower flies at 150, the target flees at 250: the throw alone would fall behind.
		local velocity = Homing.launchVelocity(Vector3.new(0, 0, -150), toward, 80)
		local target = Vector3.new(0, 0, -250)
		local closing = (Homing.ensureClosing(velocity, toward, target, 80) - target):Dot(toward)
		expect(closing).toBeCloseTo(80, 1e-4)
	end)
end)

describe("Homing.steer", function()
	it("keeps its course when already coming straight at the target", function()
		local velocity = Vector3.new(0, 0, -60)
		local steered =
			Homing.steer(Vector3.zero, velocity, Vector3.new(0, 0, -50), Vector3.zero, 60, BOMB.steerAcceleration, STEP)
		expectVector(steered, velocity)
	end)

	it("changes the velocity by at most the acceleration for the step", function()
		local velocity = Vector3.new(60, 0, 0)
		local steered =
			Homing.steer(Vector3.zero, velocity, Vector3.new(0, 0, -50), Vector3.zero, 60, BOMB.steerAcceleration, STEP)
		expect((steered - velocity).Magnitude).toBeCloseTo(BOMB.steerAcceleration * STEP, 1e-4)
	end)

	it("never slows down how fast it already closes", function()
		local velocity = Vector3.new(0, 0, -200)
		local steered = Homing.steer(Vector3.zero, velocity, Vector3.new(0, 0, -50), Vector3.zero, 60, 1e6, STEP)
		expectVector(steered, velocity)
	end)

	it("does nothing on the target itself or with no time", function()
		local velocity = Vector3.new(1, 2, 3)
		expectVector(Homing.steer(Vector3.zero, velocity, Vector3.zero, Vector3.zero, 60, 100, STEP), velocity)
		expectVector(Homing.steer(Vector3.zero, velocity, Vector3.new(0, 0, 9), Vector3.zero, 60, 100, 0), velocity)
	end)
end)

describe("the bomb in flight", function()
	local function constant(velocity: Vector3): (number) -> Vector3
		return function()
			return velocity
		end
	end

	it("catches a carrier fleeing in a straight line from a chaser at full speed", function()
		local flight = Vector3.new(0, 0, -250)
		local distance = closest(flight, Vector3.new(0, 0, -1), Vector3.new(0, 0, -60), constant(flight))
		expect(distance <= BOMB.contactStuds).toBe(true)
	end)

	it("catches a carrier faster than the chaser", function()
		local distance = closest(
			Vector3.new(0, 0, -150),
			Vector3.new(0, 0, -1),
			Vector3.new(0, 0, -60),
			constant(Vector3.new(0, 0, -250))
		)
		expect(distance <= BOMB.contactStuds).toBe(true)
	end)

	it("catches a faster carrier at the edge of the homing range", function()
		local distance = closest(
			Vector3.new(0, 0, -150),
			Vector3.new(0, 0, -1),
			Vector3.new(0, 0, -(BOMB.homingRangeStuds - 5)),
			constant(Vector3.new(0, 0, -250))
		)
		expect(distance <= BOMB.contactStuds).toBe(true)
	end)

	it("bends to a target a little off the aim", function()
		local flight = Vector3.new(0, 0, -200)
		-- Aimed 15 degrees off where the target flies.
		local aim = Vector3.new(math.sin(math.rad(15)), 0, -math.cos(math.rad(15)))
		local distance = closest(flight, aim, Vector3.new(0, 0, -50), constant(flight))
		expect(distance <= BOMB.contactStuds).toBe(true)
	end)

	it("misses the same throw without homing", function()
		local flight = Vector3.new(0, 0, -200)
		local aim = Vector3.new(math.sin(math.rad(15)), 0, -math.cos(math.rad(15)))
		local position = aim * PvpConfig.BOMB_START_STUDS
		local velocity = Homing.launchVelocity(flight, aim, BOMB.throwSpeed)
		local target = Vector3.new(0, 0, -50)
		local nearest = math.huge
		for _ = 1, math.floor(BOMB.fuseSeconds / STEP) do
			local nextPosition, nextTarget = position + velocity * STEP, target + flight * STEP
			nearest = math.min(nearest, (Homing.closestApproach(position, nextPosition, target, nextTarget)))
			position, target = nextPosition, nextTarget
		end
		expect(nearest > BOMB.contactStuds).toBe(true)
	end)

	it("is dodged by a sharp turn", function()
		local flight = Vector3.new(0, 0, -200)
		-- The target, 60 studs ahead, breaks hard to the side a moment after the throw.
		local function turning(seconds: number): Vector3
			return if seconds < 0.2 then flight else Vector3.new(200, 0, 0)
		end
		local distance = closest(flight, Vector3.new(0, 0, -1), Vector3.new(0, 0, -60), turning)
		expect(distance > BOMB.contactStuds).toBe(true)
	end)
end)

describe("Homing.closestApproach", function()
	it("finds a meeting between two frames that the ends of the step miss", function()
		-- The bomb crosses 20 studs in one step, right through a still target.
		local distance, share = Homing.closestApproach(
			Vector3.new(-10, 0, 0),
			Vector3.new(10, 0, 0),
			Vector3.new(0, 1, 0),
			Vector3.new(0, 1, 0)
		)
		expect(distance).toBeCloseTo(1, 1e-4)
		expect(share).toBeCloseTo(0.5, 1e-4)
	end)

	it("follows both movers", function()
		-- Both move +X; the bomb also closes 4 studs on the target's side.
		local distance = Homing.closestApproach(
			Vector3.new(0, 4, 0),
			Vector3.new(10, 0, 0),
			Vector3.new(0, 0, 0),
			Vector3.new(10, 0, 0)
		)
		expect(distance).toBeCloseTo(0, 1e-4)
	end)

	it("takes the start when neither moves relative to the other", function()
		local distance, share =
			Homing.closestApproach(Vector3.new(0, 3, 0), Vector3.new(5, 3, 0), Vector3.zero, Vector3.new(5, 0, 0))
		expect(distance).toBeCloseTo(3, 1e-4)
		expect(share).toBe(0)
	end)
end)
