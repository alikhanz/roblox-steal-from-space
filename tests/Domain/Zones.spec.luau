--!strict

local roblox = require("@lune/roblox")

local Test = require("../../lune/lib/Test")
local Zones = require("../../src/shared/Domain/Zones")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
-- A platform of radius 40 at y = 0 (underside at -4) under a dome of radius 50 centered at y = 30.
local STATION: Zones.Station = {
	domeCenter = Vector3.new(0, 30, 0),
	domeRadius = 50,
	platformCenter = Vector3.zero,
	platformRadius = 40,
	floorY = -4,
}
local MARGIN = 3

describe("Zones.isInStation", function()
	it("is inside right above the platform and under the dome", function()
		expect(Zones.isInStation(Vector3.new(0, 3, 0), STATION)).toBe(true)
		expect(Zones.isInStation(Vector3.new(30, 3, 0), STATION)).toBe(true)
		expect(Zones.isInStation(Vector3.new(0, 70, 0), STATION)).toBe(true)
	end)

	it("is outside under the dome but beyond the platform's edge", function()
		expect(Zones.isInStation(Vector3.new(45, 10, 0), STATION)).toBe(false)
	end)

	it("is outside under the platform", function()
		expect(Zones.isInStation(Vector3.new(0, -10, 0), STATION)).toBe(false)
	end)

	it("is outside beyond the dome", function()
		expect(Zones.isInStation(Vector3.new(0, 90, 0), STATION)).toBe(false)
	end)
end)

describe("Zones.nextInSpace", function()
	it("keeps the jetpack while flying in until over the floor", function()
		-- Inside the dome sphere, but past the platform's edge: still flying.
		expect(Zones.nextInSpace(true, Vector3.new(44, 10, 0), STATION, MARGIN)).toBe(true)
		-- Over the edge, but not yet past the margin: still flying.
		expect(Zones.nextInSpace(true, Vector3.new(38, 10, 0), STATION, MARGIN)).toBe(true)
		-- Well over the floor: lands.
		expect(Zones.nextInSpace(true, Vector3.new(36, 10, 0), STATION, MARGIN)).toBe(false)
	end)

	it("starts flying just past the rim when walking off the edge", function()
		expect(Zones.nextInSpace(false, Vector3.new(42, 3, 0), STATION, MARGIN)).toBe(false)
		expect(Zones.nextInSpace(false, Vector3.new(44, 3, 0), STATION, MARGIN)).toBe(true)
	end)

	it("keeps walking on the floor boundary and flies only past the margin below it", function()
		expect(Zones.nextInSpace(false, Vector3.new(0, -4, 0), STATION, MARGIN)).toBe(false)
		expect(Zones.nextInSpace(false, Vector3.new(0, -8, 0), STATION, MARGIN)).toBe(true)
	end)

	it("does not flip while hovering exactly on the boundary", function()
		local boundary = Vector3.new(40, 10, 0)
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
end)
