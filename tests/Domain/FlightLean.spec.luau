--!strict

local FlightLean = require("../../src/shared/Domain/FlightLean")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: FlightLean.Tuning = { maxPitch = 0.5, maxRoll = 0.3 }

describe("FlightLean.angles", function()
	it("stays upright when hovering", function()
		local pitch, roll = FlightLean.angles(0, 0, 40, TUNING)
		expect(pitch).toBe(0)
		expect(roll).toBe(0)
	end)

	it("leans forward in proportion to forward speed", function()
		expect((FlightLean.angles(20, 0, 40, TUNING))).toBeCloseTo(-0.25)
		expect((FlightLean.angles(40, 0, 40, TUNING))).toBeCloseTo(-0.5)
	end)

	it("leans back when flying backwards", function()
		expect((FlightLean.angles(-40, 0, 40, TUNING))).toBeCloseTo(0.5)
	end)

	it("banks into the strafe direction", function()
		local _, roll = FlightLean.angles(0, 40, 40, TUNING)
		expect(roll).toBeCloseTo(-0.3)
	end)

	it("caps the tilt above top speed", function()
		local pitch, roll = FlightLean.angles(400, -400, 40, TUNING)
		expect(pitch).toBeCloseTo(-0.5)
		expect(roll).toBeCloseTo(0.3)
	end)

	it("handles a zero max speed", function()
		local pitch, roll = FlightLean.angles(10, 10, 0, TUNING)
		expect(pitch).toBe(0)
		expect(roll).toBe(0)
	end)
end)
