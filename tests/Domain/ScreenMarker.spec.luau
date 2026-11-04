--!strict

local ScreenMarker = require("../../src/shared/Domain/ScreenMarker")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local SCREEN: ScreenMarker.Screen = { width = 1000, height = 600, margin = 40 }
local IN_FRONT = 50
local BEHIND = -50

local function near(actual: number, expected: number)
	expect(math.abs(actual - expected) < 1e-6).toBe(true)
end

describe("ScreenMarker.place", function()
	it("sits right over a point in view", function()
		local placement = ScreenMarker.place(700, 200, IN_FRONT, SCREEN)
		expect(placement.onScreen).toBe(true)
		near(placement.x, 700)
		near(placement.y, 200)
	end)

	it("pins a point off to the right onto the right edge, pointing right", function()
		local placement = ScreenMarker.place(3000, 300, IN_FRONT, SCREEN)
		expect(placement.onScreen).toBe(false)
		near(placement.x, 1000 - 40)
		near(placement.y, 300)
		near(placement.angle, 0)
	end)

	it("pins a point above the screen onto the top edge, pointing up", function()
		local placement = ScreenMarker.place(500, -900, IN_FRONT, SCREEN)
		expect(placement.onScreen).toBe(false)
		near(placement.x, 500)
		near(placement.y, 40)
		near(placement.angle, -90)
	end)

	it("treats a point closer to the edge than the margin as off screen", function()
		local placement = ScreenMarker.place(990, 300, IN_FRONT, SCREEN)
		expect(placement.onScreen).toBe(false)
		near(placement.x, 1000 - 40)
	end)

	it("flips a point behind the camera to the opposite side", function()
		-- Projected left of center while behind: it really lies to the right.
		local placement = ScreenMarker.place(200, 300, BEHIND, SCREEN)
		expect(placement.onScreen).toBe(false)
		near(placement.x, 1000 - 40)
		near(placement.angle, 0)
	end)

	it("points down for a point straight behind", function()
		local placement = ScreenMarker.place(500, 300, BEHIND, SCREEN)
		expect(placement.onScreen).toBe(false)
		near(placement.x, 500)
		near(placement.y, 600 - 40)
		near(placement.angle, 90)
	end)
end)
