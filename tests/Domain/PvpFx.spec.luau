--!strict

local PvpFx = require("../../src/shared/Domain/PvpFx")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local CHARGE: PvpFx.Charge = {
	spinFrom = 1,
	spinTo = 3,
	blinkFrom = 2,
	blinkTo = 2,
	collapseSeconds = 0.2,
	collapseScale = 0.5,
}

local WAVE: PvpFx.Wave = { startRadius = 2, growSeconds = 0.3, holdSeconds = 0.1, fadeSeconds = 0.2 }

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

describe("PvpFx.driftDistance", function()
	it("coasts towards speed / ln(1 / retention) and matches a step-by-step drift", function()
		local stepped, speed = 0, 40
		for _ = 1, 1000 do
			stepped += speed * 0.001
			speed *= 0.1 ^ 0.001
		end
		expect(math.abs(PvpFx.driftDistance(40, 0.1, 1) - stepped) < 0.05).toBe(true)
		expect(math.abs(PvpFx.driftDistance(40, 0.1, 100) - 40 / math.log(10)) < 1e-6).toBe(true)
	end)

	it("is nothing at the start and straight without losing speed", function()
		expect(PvpFx.driftDistance(40, 0.1, 0)).toBe(0)
		expect(PvpFx.driftDistance(10, 1, 2)).toBe(20)
	end)

	it("slows the egg by its retention every second", function()
		expect(near(PvpFx.driftSpeed(40, 0.1, 1), 4)).toBe(true)
		expect(PvpFx.driftSpeed(40, 0.1, -1)).toBe(40)
	end)
end)

describe("PvpFx.bombCharge", function()
	it("spins faster towards the end of the fuse", function()
		local first = PvpFx.bombCharge(0.5, 1, CHARGE)
		local whole = PvpFx.bombCharge(1, 1, CHARGE)
		-- 1 turn/s rising to 3: half a second is 0.75 turns, the whole fuse 2 turns.
		expect(near(first, 2 * math.pi * 0.75)).toBe(true)
		expect(near(whole, 2 * math.pi * 2)).toBe(true)
		expect(near(PvpFx.bombCharge(5, 1, CHARGE), whole)).toBe(true)
	end)

	it("keeps the orbits full until the last moments, then closes them in", function()
		local _, early = PvpFx.bombCharge(0.7, 1, CHARGE)
		local _, middle = PvpFx.bombCharge(0.9, 1, CHARGE)
		local _, last = PvpFx.bombCharge(1, 1, CHARGE)
		expect(early).toBe(1)
		expect(near(middle, 0.75)).toBe(true)
		expect(near(last, 0.5)).toBe(true)
	end)

	it("blinks: lit for the first half of every blink", function()
		local _, _, lit = PvpFx.bombCharge(0.1, 1, CHARGE)
		local _, _, dark = PvpFx.bombCharge(0.3, 1, CHARGE)
		expect(lit).toBe(true)
		expect(dark).toBe(false)
	end)
end)

describe("PvpFx.wave", function()
	it("grows from its start out to the blast's radius, holds, then fades away", function()
		local start, startFade = PvpFx.wave(0, 25, WAVE)
		local grown = PvpFx.wave(0.3, 25, WAVE)
		local held, heldFade = PvpFx.wave(0.35, 25, WAVE)
		local _, fading = PvpFx.wave(0.5, 25, WAVE)
		local gone = PvpFx.wave(0.61, 25, WAVE)
		expect(start).toBe(2)
		expect(startFade).toBe(0)
		expect(grown).toBe(25)
		expect(held).toBe(25)
		expect(heldFade).toBe(0)
		expect(near(fading, 0.5)).toBe(true)
		expect(gone).toBe(nil)
	end)
end)

describe("PvpFx.waveReach", function()
	it("strikes as far as the ring is drawn while it grows and holds", function()
		for _, elapsed in { 0, 0.1, 0.2, 0.3, 0.35, 0.4 } do
			expect(PvpFx.waveReach(elapsed, 25, WAVE)).toBe((PvpFx.wave(elapsed, 25, WAVE)))
		end
	end)

	it("strikes no more once the ring fades", function()
		expect(PvpFx.waveReach(0.41, 25, WAVE)).toBeNil()
		expect(PvpFx.wave(0.41, 25, WAVE) ~= nil).toBe(true)
	end)
end)

describe("PvpFx.burst", function()
	it("swells and fades over its time", function()
		local first, clear = PvpFx.burst(0, 0.2, 1, 3)
		local later, faded = PvpFx.burst(0.1, 0.2, 1, 3)
		expect(first).toBe(1)
		expect(clear).toBe(0)
		expect((later :: number) > 2).toBe(true)
		expect(near(faded, 0.5)).toBe(true)
		expect(PvpFx.burst(0.2, 0.2, 1, 3)).toBe(nil)
	end)
end)
