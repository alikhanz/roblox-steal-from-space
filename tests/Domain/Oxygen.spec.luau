--!strict

local Oxygen = require("../../src/shared/Domain/Oxygen")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: Oxygen.Tuning = { drainPerSecond = 2, refillPerSecond = 10 }

describe("Oxygen", function()
	it("drains in space", function()
		expect(Oxygen.step(50, 100, true, 1, TUNING)).toBe(48)
	end)

	it("refills under the dome", function()
		expect(Oxygen.step(50, 100, false, 1, TUNING)).toBe(60)
	end)

	it("stays within the tank", function()
		expect(Oxygen.step(1, 100, true, 5, TUNING)).toBe(0)
		expect(Oxygen.step(99, 100, false, 5, TUNING)).toBe(100)
	end)

	it("reports an empty tank", function()
		expect(Oxygen.isEmpty(0)).toBe(true)
		expect(Oxygen.isEmpty(0.01)).toBe(false)
	end)

	it("reports the fill fraction", function()
		expect(Oxygen.fraction(25, 100)).toBe(0.25)
		expect(Oxygen.fraction(150, 100)).toBe(1)
		expect(Oxygen.fraction(10, 0)).toBe(0)
	end)
end)
