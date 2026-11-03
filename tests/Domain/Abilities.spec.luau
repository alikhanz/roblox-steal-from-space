--!strict

local Abilities = require("../../src/shared/Domain/Abilities")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local ORIGIN = { x = 0, y = 0, z = 0 }
local FORWARD = { x = 0, y = 0, z = -1 }

describe("Abilities.isReady", function()
	it("is ready when never used or once the cooldown passed", function()
		expect(Abilities.isReady(0, 5, 3)).toBe(true)
		expect(Abilities.isReady(10, 12, 3)).toBe(false)
		expect(Abilities.isReady(10, 13, 3)).toBe(true)
	end)
end)

describe("Abilities.isInCone", function()
	it("hits ahead within reach and angle, misses behind, beside and far", function()
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -5 }, 9, math.rad(35))).toBe(true)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 3, y = 0, z = -5 }, 9, math.rad(35))).toBe(true)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 5, y = 0, z = -5 }, 9, math.rad(35))).toBe(false)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 0, y = 0, z = 5 }, 9, math.rad(35))).toBe(false)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -10 }, 9, math.rad(35))).toBe(false)
		expect(Abilities.isInCone(ORIGIN, FORWARD, ORIGIN, 9, math.rad(35))).toBe(true)
	end)

	it("does not care about the facing vector's length", function()
		local longFacing = { x = 0, y = 0, z = -40 }
		expect(Abilities.isInCone(ORIGIN, longFacing, { x = 2, y = 0, z = -6 }, 9, math.rad(35))).toBe(true)
	end)
end)

describe("Abilities.nearestInCone", function()
	it("picks the nearest target in the cone", function()
		local targets = {
			{ id = "far", position = { x = 0, y = 0, z = -8 } },
			{ id = "near", position = { x = 1, y = 0, z = -3 } },
			{ id = "beside", position = { x = 8, y = 0, z = -1 } },
		}
		expect(Abilities.nearestInCone(ORIGIN, FORWARD, targets, 9, math.rad(35))).toBe("near")
		expect(Abilities.nearestInCone(ORIGIN, FORWARD, {}, 9, math.rad(35))).toBeNil()
	end)
end)

describe("Abilities.withinRadius", function()
	it("lists everyone inside the radius", function()
		local targets = {
			{ id = "a", position = { x = 10, y = 0, z = 0 } },
			{ id = "b", position = { x = 0, y = 30, z = 0 } },
			{ id = "c", position = { x = 0, y = 0, z = 25 } },
		}
		expect(Abilities.withinRadius(ORIGIN, targets, 25)).toEqual({ "a", "c" })
	end)
end)
