--!strict

local roblox = require("@lune/roblox")

local Test = require("../../lune/lib/Test")
local Zones = require("../../src/shared/Domain/Zones")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
-- A dome of radius 50 centered 30 studs above a platform whose underside is at y = -4.
local STATION: Zones.Station = { domeCenter = Vector3.new(0, 30, 0), domeRadius = 50, floorY = -4 }
local MARGIN = 3

describe("Zones.isInStation", function()
	it("is inside above the platform and under the dome", function()
		expect(Zones.isInStation(Vector3.new(0, 3, 0), STATION)).toBe(true)
		expect(Zones.isInStation(Vector3.new(0, 70, 0), STATION)).toBe(true)
	end)

	it("is outside under the platform even within the dome sphere", function()
		expect(Zones.isInStation(Vector3.new(0, -10, 0), STATION)).toBe(false)
	end)

	it("is outside beyond the dome", function()
		expect(Zones.isInStation(Vector3.new(0, 90, 0), STATION)).toBe(false)
		expect(Zones.isInStation(Vector3.new(60, 30, 0), STATION)).toBe(false)
	end)
end)

describe("Zones.nextInSpace", function()
	it("keeps walking on the boundary and switches to flight only past the margin", function()
		local onFloor = Vector3.new(0, -4, 0)
		expect(Zones.nextInSpace(false, onFloor, STATION, MARGIN)).toBe(false)
		expect(Zones.nextInSpace(false, Vector3.new(0, -6, 0), STATION, MARGIN)).toBe(false)
		expect(Zones.nextInSpace(false, Vector3.new(0, -8, 0), STATION, MARGIN)).toBe(true)
	end)

	it("keeps flying on the boundary and switches to walking only past the margin", function()
		local justInside = Vector3.new(0, 30, 48)
		expect(Zones.nextInSpace(true, justInside, STATION, MARGIN)).toBe(true)
		expect(Zones.nextInSpace(true, Vector3.new(0, 30, 45), STATION, MARGIN)).toBe(false)
	end)

	it("does not flip while hovering exactly on the boundary", function()
		local boundary = Vector3.new(0, 30, 50)
		local inSpace = true
		for _ = 1, 10 do
			inSpace = Zones.nextInSpace(inSpace, boundary, STATION, MARGIN)
		end
		expect(inSpace).toBe(true)

		local walking = false
		for _ = 1, 10 do
			walking = Zones.nextInSpace(walking, boundary, STATION, MARGIN)
		end
		expect(walking).toBe(false)
	end)

	it("flies right under the platform after walking off its edge", function()
		expect(Zones.nextInSpace(false, Vector3.new(58, -8, 0), STATION, MARGIN)).toBe(true)
	end)
end)
