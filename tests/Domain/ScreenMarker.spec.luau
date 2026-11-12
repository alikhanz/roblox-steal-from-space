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

describe("ScreenMarker.placeIn", function()
	-- The left HUD column and the flight buttons in the bottom-right corner.
	local COLUMN: ScreenMarker.Rect = { left = 0, top = 50, right = 300, bottom = 350 }
	local BUTTONS: ScreenMarker.Rect = { left = 750, top = 400, right = 1000, bottom = 600 }
	local function area(keepOut: { ScreenMarker.Rect }, minReach: number?): ScreenMarker.Area
		return {
			centerX = 500,
			centerY = 300,
			bounds = { left = 40, top = 60, right = 960, bottom = 560 },
			keepOut = keepOut,
			minReach = minReach or 0,
		}
	end

	it("keeps a point in view where it is, even over the HUD", function()
		local placement = ScreenMarker.placeIn(100, 200, IN_FRONT, area({ COLUMN }))
		expect(placement.onScreen).toBe(true)
		near(placement.x, 100)
		near(placement.y, 200)
	end)

	it("pins to its own bounds, not the whole screen", function()
		local placement = ScreenMarker.placeIn(500, -900, IN_FRONT, area({}))
		near(placement.x, 500)
		near(placement.y, 60)
	end)

	it("steps an edge marker back off the HUD along its own direction", function()
		-- Straight left: the ray hits the column at its right side.
		local placement = ScreenMarker.placeIn(-2000, 300, IN_FRONT, area({ COLUMN }))
		expect(placement.onScreen).toBe(false)
		near(placement.x, 300)
		near(placement.y, 300)
		near(placement.angle, 180)
	end)

	it("keeps the direction when it steps back on a slant", function()
		local placement = ScreenMarker.placeIn(-1000, 0, IN_FRONT, area({ COLUMN }))
		-- On the ray from (500, 300) towards (-1000, 0): the slope stays 1/5.
		near((300 - placement.y) / (500 - placement.x), 0.2)
		expect(placement.x >= 300 - 1e-6 or placement.y >= 350 - 1e-6).toBe(true)
	end)

	it("leaves a marker that misses the HUD at the edge", function()
		local placement = ScreenMarker.placeIn(3000, 300, IN_FRONT, area({ COLUMN, BUTTONS }))
		near(placement.x, 960)
		near(placement.y, 300)
	end)

	it("steps out of two blocks in a row", function()
		local inner: ScreenMarker.Rect = { left = 200, top = 280, right = 320, bottom = 320 }
		local placement = ScreenMarker.placeIn(-2000, 300, IN_FRONT, area({ inner, COLUMN }))
		near(placement.x, 320)
	end)

	it("never comes nearer the center than its minimum reach", function()
		local wide: ScreenMarker.Rect = { left = 0, top = 0, right = 480, bottom = 600 }
		local placement = ScreenMarker.placeIn(-2000, 300, IN_FRONT, area({ wide }, 0.5))
		-- Half of the 460 pixels from the center to the left bound.
		near(placement.x, 500 - 230)
	end)
end)

describe("ScreenMarker.separate", function()
	local WIDTH, HEIGHT = 160, 50

	it("leaves signs that do not touch where they are", function()
		local points = ScreenMarker.separate({ { x = 100, y = 100 }, { x = 400, y = 100 } }, WIDTH, HEIGHT, SCREEN)
		near(points[1].y, 100)
		near(points[2].x, 400)
		near(points[2].y, 100)
	end)

	it("steps a covered sign down in the top half, keeping the first in place", function()
		local points = ScreenMarker.separate({ { x = 500, y = 100 }, { x = 520, y = 110 } }, WIDTH, HEIGHT, SCREEN)
		near(points[1].y, 100)
		near(points[2].x, 520)
		near(points[2].y, 150)
	end)

	it("steps up in the bottom half, so signs stay on screen", function()
		local points = ScreenMarker.separate({ { x = 500, y = 560 }, { x = 500, y = 560 } }, WIDTH, HEIGHT, SCREEN)
		near(points[2].y, 510)
	end)

	it("stacks signs pinned to one spot of the edge one above another", function()
		local same = { x = 960, y = 200 }
		local points = ScreenMarker.separate({ same, same, same, same }, WIDTH, HEIGHT, SCREEN)
		near(points[1].y, 200)
		near(points[2].y, 250)
		near(points[3].y, 300)
		near(points[4].y, 350)
	end)
end)
