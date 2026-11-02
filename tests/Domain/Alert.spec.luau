--!strict

local Alert = require("../../src/shared/Domain/Alert")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: Alert.Tuning = {
	noiseRadius = 40,
	noisePerSecond = 0.8,
	grabPerSecond = 0.5,
	decayPerSecond = 0.1,
}

describe("Alert.noise", function()
	it("is loudest at top speed right at the nest", function()
		expect(Alert.noise(0, 1, TUNING)).toBe(1)
	end)

	it("fades with distance and is silent outside the radius", function()
		expect(Alert.noise(20, 1, TUNING)).toBeCloseTo(0.5)
		expect(Alert.noise(40, 1, TUNING)).toBe(0)
		expect(Alert.noise(100, 1, TUNING)).toBe(0)
	end)

	it("is quiet when moving slowly", function()
		expect(Alert.noise(0, 0.1, TUNING)).toBeCloseTo(0.1)
	end)
end)

describe("Alert.step", function()
	it("rises with noise and wakes the guardian at full", function()
		local level = 0
		for _ = 1, 60 do
			level = Alert.step(level, 1, false, 1 / 60, TUNING)
		end
		expect(level).toBeCloseTo(0.7, 1e-6)
		for _ = 1, 120 do
			level = Alert.step(level, 1, false, 1 / 60, TUNING)
		end
		expect(Alert.isAwake(level)).toBe(true)
	end)

	it("lets a slow, sneaky approach stay below the decay", function()
		local level = 0.5
		for _ = 1, 60 do
			level = Alert.step(level, 0.1, false, 1 / 60, TUNING)
		end
		expect(level < 0.5).toBe(true)
	end)

	it("rises while grabbing even in silence", function()
		local level = Alert.step(0, 0, true, 1, TUNING)
		expect(level).toBeCloseTo(0.4)
	end)

	it("settles back to zero and never goes negative", function()
		expect(Alert.step(0.05, 0, false, 1, TUNING)).toBe(0)
	end)
end)
