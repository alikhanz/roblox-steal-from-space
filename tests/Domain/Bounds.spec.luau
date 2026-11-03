--!strict

local roblox = require("@lune/roblox")

local Bounds = require("../../src/shared/Domain/Bounds")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local CENTER = Vector3.new(0, 0, 0)
local RADIUS = 100

local function expectVector(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeCloseTo(0, 1e-4)
end

describe("Bounds.isOutside", function()
	it("is outside at and past the edge", function()
		expect(Bounds.isOutside(Vector3.new(99, 0, 0), CENTER, RADIUS)).toBe(false)
		expect(Bounds.isOutside(Vector3.new(100, 0, 0), CENTER, RADIUS)).toBe(true)
		expect(Bounds.isOutside(Vector3.new(0, 0, 150), CENTER, RADIUS)).toBe(true)
	end)
end)

describe("Bounds.limitVelocity", function()
	it("leaves velocity alone inside the edge", function()
		local velocity = Vector3.new(50, 10, 0)
		expectVector(Bounds.limitVelocity(Vector3.new(90, 0, 0), velocity, CENTER, RADIUS), velocity)
	end)

	it("removes the outward component at the edge", function()
		local limited = Bounds.limitVelocity(Vector3.new(100, 0, 0), Vector3.new(50, 10, 0), CENTER, RADIUS)
		expectVector(limited, Vector3.new(0, 10, 0))
	end)

	it("keeps velocity pointing back in", function()
		local velocity = Vector3.new(-50, 10, 0)
		expectVector(Bounds.limitVelocity(Vector3.new(120, 0, 0), velocity, CENTER, RADIUS), velocity)
	end)

	it("keeps velocity along the edge", function()
		local velocity = Vector3.new(0, 0, 40)
		expectVector(Bounds.limitVelocity(Vector3.new(100, 0, 0), velocity, CENTER, RADIUS), velocity)
	end)
end)
