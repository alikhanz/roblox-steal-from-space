--!strict

local Carry = require("../../src/shared/Domain/Carry")
local Grab = require("../../src/shared/Domain/Grab")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Grab.step", function()
	it("fills over the grab time while holding in reach", function()
		local progress = 0
		for _ = 1, 30 do
			progress = Grab.step(progress, true, true, 1, 1 / 60)
		end
		expect(progress).toBeCloseTo(0.5, 1e-9)
		for _ = 1, 30 do
			progress = Grab.step(progress, true, true, 1, 1 / 60)
		end
		expect(Grab.isComplete(progress)).toBe(true)
	end)

	it("resets when letting go or drifting out of reach", function()
		expect(Grab.step(0.8, false, true, 1, 1 / 60)).toBe(0)
		expect(Grab.step(0.8, true, false, 1, 1 / 60)).toBe(0)
	end)

	it("caps at complete", function()
		expect(Grab.step(0.99, true, true, 1, 1)).toBe(1)
	end)

	it("completes instantly with no grab time", function()
		expect(Grab.step(0, true, true, 0, 1 / 60)).toBe(1)
	end)
end)

describe("Carry.speedMultiplier", function()
	it("slows by the egg's weight", function()
		expect(Carry.speedMultiplier(0.25, 0)).toBeCloseTo(0.75)
	end)

	it("lets strength offset the weight", function()
		expect(Carry.speedMultiplier(0.4, 0.5)).toBeCloseTo(0.8)
		expect(Carry.speedMultiplier(0.4, 1)).toBe(1)
	end)

	it("never drops below the minimum speed", function()
		expect(Carry.speedMultiplier(1, 0)).toBeCloseTo(0.3)
	end)

	it("is full speed without an egg", function()
		expect(Carry.speedMultiplier(0, 0)).toBe(1)
	end)
end)
