--!strict

local HintStrip = require("../../src/shared/Domain/HintStrip")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- The slow-mode button reaches 289 points from the right edge (right 245, size 44).
local function phone(width: number, height: number, scale: number?): HintStrip.Spec
	return {
		screenWidth = width,
		screenHeight = height,
		scale = scale or 1,
		edge = 16,
		flightReach = 289,
		clearance = 8,
	}
end

local function near(value: number, expected: number)
	expect(math.abs(value - expected) < 1e-6).toBe(true)
end

describe("HintStrip.stickRight", function()
	it("puts the ring's right edge at 103 pixels on a phone", function()
		near(HintStrip.stickRight(667, 317), 103)
	end)

	it("doubles it on a screen whose shorter side is over 500", function()
		near(HintStrip.stickRight(1180, 760), 206)
	end)
end)

describe("HintStrip.of", function()
	it("runs from right of the stick's ring to short of the flight buttons on a small phone", function()
		local strip = HintStrip.of(phone(667, 317))
		-- 103 + 8 = 111 to 667 - 297 = 370.
		near(strip.width, 259)
		near(strip.centre, 240.5)
	end)

	it("widens with the phone", function()
		local strip = HintStrip.of(phone(750, 343))
		near(strip.width, 342)
		near(strip.centre, 282)
	end)

	it("counts points through the HUD's scale on a tablet", function()
		local strip = HintStrip.of(phone(1180, 760, 1.6))
		-- 206 + 12.8 = 218.8 to 1180 - 475.2 = 704.8 pixels.
		near(strip.centre, 461.8)
		near(strip.width, 486 / 1.6)
	end)

	it("never gives a negative width on a screen too narrow for it", function()
		expect(HintStrip.of(phone(300, 200)).width).toBe(0)
	end)
end)
