--!strict

local PetMotion = require("../../src/shared/Domain/PetMotion")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- The largest jump between two samples `step` seconds apart over [from, to].
local function largestJump(curve: (number) -> number, from: number, to: number, step: number): number
	local largest = 0
	local previous = curve(from)
	local t = from + step
	while t <= to do
		local value = curve(t)
		largest = math.max(largest, math.abs(value - previous))
		previous = value
		t += step
	end
	return largest
end

describe("PetMotion", function()
	it("keeps the eyes open except during a blink, nearly shut in its middle", function()
		expect(PetMotion.eyeOpen(-1, false)).toBe(1)
		expect(PetMotion.eyeOpen(5, true)).toBe(1)
		expect(PetMotion.eyeOpen(0.07, false)).toBeCloseTo(0.1, 1e-6)
		-- A double blink shuts them a second time.
		expect(PetMotion.eyeOpen(0.29, true) < 0.2).toBe(true)
		expect(PetMotion.eyeOpen(0.29, false)).toBe(1)
	end)

	it("opens a jaw to its angle, holds it and snaps it shut", function()
		expect(PetMotion.jawOpen(-1, false, 0.45)).toBe(0)
		expect(PetMotion.jawOpen(0.4, false, 0.45)).toBeCloseTo(0.45, 1e-6)
		expect(PetMotion.jawOpen(1, false, 0.45)).toBe(0)
		expect(PetMotion.jawOpen(0.6 + 0.4, true, 0.45)).toBeCloseTo(0.45, 1e-6)
	end)

	it("hops without a jerk: the jelly and the lift change smoothly all through", function()
		local step = 1 / 240
		local jelly = largestJump(function(t)
			return (PetMotion.hop(t, 0.12))
		end, -0.1, PetMotion.HOP_SECONDS + 0.1, step)
		local lift = largestJump(function(t)
			local _, up = PetMotion.hop(t, 0.12)
			return up
		end, -0.1, PetMotion.HOP_SECONDS + 0.1, step)
		-- At 240 frames a second no frame moves more than a few hundredths of the pet's height.
		expect(jelly < 0.02).toBe(true)
		expect(lift < 0.01).toBe(true)
	end)

	it("draws a pet in full near the camera, its main effects farther, nothing far away", function()
		expect(PetMotion.detail(30, 5, nil, 70, 160, 10)).toBe(1)
		expect(PetMotion.detail(100, 5, nil, 70, 160, 10)).toBe(2)
		expect(PetMotion.detail(400, 5, nil, 70, 160, 10)).toBe(3)
		-- A giant counts from its own edge.
		expect(PetMotion.detail(100, 40, nil, 70, 160, 10)).toBe(1)
	end)

	it("keeps a pet's detail at the edge until it is past the margin", function()
		-- Just past the near edge: still in full, until the margin is crossed.
		expect(PetMotion.detail(80, 5, 1, 70, 160, 10)).toBe(1)
		expect(PetMotion.detail(86, 5, 1, 70, 160, 10)).toBe(2)
		expect(PetMotion.detail(170, 5, 2, 70, 160, 10)).toBe(2)
		expect(PetMotion.detail(180, 5, 2, 70, 160, 10)).toBe(3)
		-- Coming closer takes more detail at once.
		expect(PetMotion.detail(74, 5, 2, 70, 160, 10)).toBe(1)
		expect(PetMotion.detail(160, 5, 3, 70, 160, 10)).toBe(2)
	end)

	it("lifts the slime only while it is in the air, at most the hop's height", function()
		local highest = 0
		for t = 0, PetMotion.HOP_SECONDS, 0.01 do
			local _, lift = PetMotion.hop(t, 0.12)
			highest = math.max(highest, lift)
		end
		expect(highest).toBeCloseTo(0.12, 1e-3)
		local _, crouched = PetMotion.hop(0.1, 0.12)
		local _, landed = PetMotion.hop(1.5, 0.12)
		expect(crouched).toBe(0)
		expect(landed).toBe(0)
	end)
end)
