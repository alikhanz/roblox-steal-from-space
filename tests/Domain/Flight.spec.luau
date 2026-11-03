--!strict

local roblox = require("@lune/roblox")

local Flight = require("../../src/shared/Domain/Flight")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
local UP = Vector3.yAxis
local FORWARD = Vector3.new(0, 0, -1)
local RIGHT = Vector3.xAxis
local MAX_SPEED = 40
local TUNING: Flight.Tuning = { response = 4, driftRetentionPerSecond = 0.5 }

-- Vector3 components are float32, so long iterations accumulate small errors.
local function expectVector(actual: Vector3, expected: Vector3, tolerance: number?)
	expect((actual - expected).Magnitude).toBeCloseTo(0, tolerance or 1e-5)
end

describe("Flight.sanitizeAim", function()
	it("normalizes a usable aim", function()
		expectVector(Flight.sanitizeAim(Vector3.new(0, 0, -3)) :: Vector3, FORWARD)
	end)

	it("rejects zero, tiny and non-finite aims", function()
		expect(Flight.sanitizeAim(Vector3.zero)).toBeNil()
		expect(Flight.sanitizeAim(Vector3.new(0.1, 0, 0))).toBeNil()
		expect(Flight.sanitizeAim(Vector3.new(0 / 0, 0, 1))).toBeNil()
		expect(Flight.sanitizeAim(Vector3.new(math.huge, 0, 0))).toBeNil()
	end)
end)

describe("Flight.direction", function()
	it("flies where the camera looks when moving forward", function()
		local aim = Vector3.new(0, 1, -1).Unit
		expectVector(Flight.direction(FORWARD, aim, UP, 0), aim)
	end)

	it("keeps strafing horizontal", function()
		local aim = Vector3.new(0, 1, -1).Unit
		expectVector(Flight.direction(RIGHT, aim, UP, 0), RIGHT)
	end)

	it("flies backwards against the aim", function()
		local aim = Vector3.new(0, -1, -1).Unit
		expectVector(Flight.direction(-FORWARD, aim, UP, 0), -aim)
	end)

	it("adds vertical input and caps the magnitude at 1", function()
		local direction = Flight.direction(FORWARD, FORWARD, UP, 1)
		expect(direction.Magnitude).toBeCloseTo(1, 1e-6)
		expectVector(direction, (FORWARD + UP).Unit)
		expectVector(Flight.direction(Vector3.zero, FORWARD, UP, -1), -UP)
	end)

	it("stays horizontal without a usable aim", function()
		expectVector(Flight.direction(FORWARD, nil, UP, 0), FORWARD)
	end)

	it("ignores the aim when looking straight up", function()
		expectVector(Flight.direction(FORWARD, UP, UP, 0), FORWARD)
	end)

	it("clamps vertical input", function()
		expectVector(Flight.direction(Vector3.zero, nil, UP, 5), UP)
	end)
end)

describe("Flight.nextVelocity", function()
	it("approaches the target speed with input", function()
		local velocity = Vector3.zero
		for _ = 1, 600 do
			velocity = Flight.nextVelocity(velocity, FORWARD, 1 / 60, MAX_SPEED, TUNING)
		end
		expectVector(velocity, FORWARD * MAX_SPEED, 1e-3)
	end)

	it("is independent of the frame rate", function()
		local fast, slow = Vector3.zero, Vector3.zero
		for _ = 1, 60 do
			fast = Flight.nextVelocity(fast, FORWARD, 1 / 60, MAX_SPEED, TUNING)
		end
		for _ = 1, 30 do
			slow = Flight.nextVelocity(slow, FORWARD, 1 / 30, MAX_SPEED, TUNING)
		end
		expectVector(fast, slow, 1e-3)
	end)

	it("glides and loses the configured share of speed per second without input", function()
		local velocity = FORWARD * 20
		for _ = 1, 60 do
			velocity = Flight.nextVelocity(velocity, Vector3.zero, 1 / 60, MAX_SPEED, TUNING)
		end
		expectVector(velocity, FORWARD * 10, 1e-3)
	end)
end)
