--!strict

local roblox = require("@lune/roblox")

local Stand = require("../../src/shared/Domain/Stand")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local function input(inZone: boolean, moving: boolean, jumping: boolean): Stand.Input
	return { inZone = inZone, moving = moving, jumping = jumping }
end

describe("Stand.next", function()
	it("boards whoever walks into the zone, even still moving", function()
		expect(Stand.next(nil, input(true, true, false))).toBe("Boarding")
		expect(Stand.next("Boarding", input(true, true, false))).toBe("Boarding")
	end)

	it("holds them once the move input is let go", function()
		expect(Stand.next("Boarding", input(true, false, false))).toBe("On")
		expect(Stand.next("On", input(true, false, false))).toBe("On")
	end)

	it("lets them off with a step or a jump", function()
		expect(Stand.next("On", input(true, true, false))).toBe("Left")
		expect(Stand.next("On", input(true, false, true))).toBe("Left")
		expect(Stand.next("Boarding", input(true, true, true))).toBe("Left")
	end)

	it("does not pull back someone who stepped off until they leave the zone", function()
		expect(Stand.next("Left", input(true, false, false))).toBe("Left")
		expect(Stand.next("Left", input(false, false, false))).toBeNil()
		expect(Stand.next(nil, input(true, false, false))).toBe("Boarding")
	end)

	it("forgets the stand outside its zone", function()
		expect(Stand.next("On", input(false, false, false))).toBeNil()
		expect(Stand.next("Boarding", input(false, true, false))).toBeNil()
	end)
end)

describe("Stand.isTraining and Stand.parse", function()
	it("trains while boarding or on the stand", function()
		expect(Stand.isTraining("Boarding")).toBe(true)
		expect(Stand.isTraining("On")).toBe(true)
		expect(Stand.isTraining("Left")).toBe(false)
		expect(Stand.isTraining(nil)).toBe(false)
	end)

	it("reads only known states", function()
		expect(Stand.parse("On")).toBe("On")
		expect(Stand.parse("Flying")).toBeNil()
		expect(Stand.parse(3)).toBeNil()
		expect(Stand.parse(nil)).toBeNil()
	end)
end)

describe("Stand.pullVelocity", function()
	it("gets there in the given time", function()
		local velocity = Stand.pullVelocity(Vector3.new(0, 0, 0), Vector3.new(3, 0, 0), 0.3, 100)
		expect(velocity.X).toBeCloseTo(10, 1e-6)
	end)

	it("never pulls faster than the cap", function()
		local velocity = Stand.pullVelocity(Vector3.new(0, 0, 0), Vector3.new(0, 0, 30), 0.3, 25)
		expect(velocity.Magnitude).toBeCloseTo(25, 1e-6)
	end)
end)

describe("Stand.flameScale", function()
	it("grows from 1 to the most, then stays", function()
		expect(Stand.flameScale(0, 3, 20)).toBeCloseTo(1, 1e-9)
		expect(Stand.flameScale(20, 3, 20)).toBeCloseTo(3, 1e-9)
		expect(Stand.flameScale(500, 3, 20)).toBeCloseTo(3, 1e-9)
		local middle = Stand.flameScale(4, 3, 20)
		expect(middle > 1 and middle < 3).toBe(true)
		-- Logarithmic: the early levels count the most.
		expect(Stand.flameScale(4, 3, 20) - 1 > (3 - 1) * 4 / 20).toBe(true)
	end)
end)
