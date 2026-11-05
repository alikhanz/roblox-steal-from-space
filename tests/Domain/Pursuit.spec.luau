--!strict

local roblox = require("@lune/roblox")

local Pursuit = require("../../src/shared/Domain/Pursuit")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local function expectVector(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeCloseTo(0, 1e-4)
end

describe("Pursuit.interceptPoint", function()
	it("leads a moving target by the time needed to reach it", function()
		-- 100 studs away at speed 50: two seconds of lead on a target moving +X at 10.
		local point = Pursuit.interceptPoint(Vector3.zero, Vector3.new(0, 0, 100), Vector3.new(10, 0, 0), 50, 5)
		expectVector(point, Vector3.new(20, 0, 100))
	end)

	it("caps the lead time", function()
		local point = Pursuit.interceptPoint(Vector3.zero, Vector3.new(0, 0, 100), Vector3.new(10, 0, 0), 10, 3)
		expectVector(point, Vector3.new(30, 0, 100))
	end)

	it("aims straight at a still target", function()
		local target = Vector3.new(5, 5, 5)
		expectVector(Pursuit.interceptPoint(Vector3.zero, target, Vector3.zero, 20, 3), target)
	end)
end)

describe("Pursuit.seekVelocity", function()
	it("heads for the goal at top speed when far", function()
		expectVector(Pursuit.seekVelocity(Vector3.zero, Vector3.new(0, 0, -100), 30, 10), Vector3.new(0, 0, -30))
	end)

	it("eases off inside the arrive radius", function()
		expectVector(Pursuit.seekVelocity(Vector3.zero, Vector3.new(5, 0, 0), 30, 10), Vector3.new(15, 0, 0))
	end)

	it("stops at the goal", function()
		expectVector(Pursuit.seekVelocity(Vector3.one, Vector3.one, 30, 10), Vector3.zero)
	end)
end)

describe("Pursuit.fleeVelocity", function()
	it("heads straight away from the threat at the given speed", function()
		local velocity = Pursuit.fleeVelocity(Vector3.new(10, 0, 0), Vector3.new(0, 0, 0), 30)
		expectVector(velocity, Vector3.new(30, 0, 0))
	end)

	it("stays put with the threat right on top", function()
		local velocity = Pursuit.fleeVelocity(Vector3.new(5, 5, 5), Vector3.new(5, 5, 5), 30)
		expect(velocity.Magnitude).toBe(0)
	end)
end)
