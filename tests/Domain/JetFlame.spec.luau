--!strict

local JetFlame = require("../../src/shared/Domain/JetFlame")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: JetFlame.Tuning = { idle = 0.4, burst = 1.4, step = 0.1 }

describe("JetFlame.power", function()
	it("burns at the idle share while hovering and full at top speed", function()
		expect(JetFlame.power({ thrust = 0, burst = false }, TUNING)).toBeCloseTo(0.4, 1e-9)
		expect(JetFlame.power({ thrust = 1, burst = false }, TUNING)).toBeCloseTo(1, 1e-9)
		expect(JetFlame.power({ thrust = 0.5, burst = false }, TUNING)).toBeCloseTo(0.7, 1e-9)
	end)

	it("keeps thrust within 0..1", function()
		expect(JetFlame.power({ thrust = 3, burst = false }, TUNING)).toBeCloseTo(1, 1e-9)
		expect(JetFlame.power({ thrust = -1, burst = false }, TUNING)).toBeCloseTo(0.4, 1e-9)
	end)

	it("flares past full in a burst", function()
		expect(JetFlame.power({ thrust = 0, burst = true }, TUNING)).toBeCloseTo(1.4, 1e-9)
	end)

	it("runs full on the stand, times the stand's scale, burst or not", function()
		expect(JetFlame.power({ thrust = 0, burst = false, standScale = 2.5 }, TUNING)).toBeCloseTo(2.5, 1e-9)
		expect(JetFlame.power({ thrust = 0, burst = true, standScale = 1 }, TUNING)).toBeCloseTo(1, 1e-9)
	end)

	it("changes in steps, so small speed changes keep the same value", function()
		local a = JetFlame.power({ thrust = 0.50, burst = false }, TUNING)
		local b = JetFlame.power({ thrust = 0.53, burst = false }, TUNING)
		expect(a).toBe(b)
	end)
end)

describe("JetFlame.detail", function()
	it("drops the core, then the light, with distance", function()
		expect(JetFlame.detail(50, 120, 350)).toBe(3)
		expect(JetFlame.detail(120, 120, 350)).toBe(3)
		expect(JetFlame.detail(200, 120, 350)).toBe(2)
		expect(JetFlame.detail(1000, 120, 350)).toBe(1)
	end)
end)

describe("JetFlame.trailLength", function()
	it("has no trail at level 0, the first length at level 1 and the last at the top", function()
		expect(JetFlame.trailLength(0, 21, 10, 120, 1.3)).toBe(0)
		expect(JetFlame.trailLength(1, 21, 10, 120, 1.3)).toBeCloseTo(10, 1e-9)
		expect(JetFlame.trailLength(21, 21, 10, 120, 1.3)).toBeCloseTo(120, 1e-9)
	end)

	it("grows with every level, faster near the top", function()
		local previous, previousStep = 0, 0
		for level = 1, 21 do
			local length = JetFlame.trailLength(level, 21, 10, 120, 1.3)
			expect(length > previous).toBe(true)
			if level > 2 then
				expect(length - previous >= previousStep).toBe(true)
			end
			previousStep = length - previous
			previous = length
		end
	end)

	it("is straight with a curve of 1", function()
		expect(JetFlame.trailLength(11, 21, 10, 110, 1)).toBeCloseTo(60, 1e-9)
	end)

	it("stops at the last length past the top", function()
		expect(JetFlame.trailLength(30, 21, 10, 120, 1.3)).toBeCloseTo(120, 1e-9)
	end)
end)

describe("JetFlame.trailLifetime", function()
	it("lives long enough to be its length at top speed", function()
		expect(JetFlame.trailLifetime(30, 60, 0.1, 3)).toBeCloseTo(0.5, 1e-9)
		expect(JetFlame.trailLifetime(60, 240, 0.1, 3)).toBeCloseTo(0.25, 1e-9)
	end)

	it("stays within its bounds", function()
		expect(JetFlame.trailLifetime(1, 250, 0.15, 2)).toBeCloseTo(0.15, 1e-9)
		expect(JetFlame.trailLifetime(100, 30, 0.15, 2)).toBeCloseTo(2, 1e-9)
	end)

	it("takes the shortest life without a speed", function()
		expect(JetFlame.trailLifetime(30, 0, 0.15, 2)).toBeCloseTo(0.15, 1e-9)
	end)
end)
