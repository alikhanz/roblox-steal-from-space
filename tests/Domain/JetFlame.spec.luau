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
