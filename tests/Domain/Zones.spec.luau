--!strict

local roblox = require("@lune/roblox")

local Test = require("../../lune/lib/Test")
local Zones = require("../../src/shared/Domain/Zones")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
local DOME: Zones.Dome = { center = Vector3.new(0, 100, 0), radius = 50 }

describe("Zones.isInsideDome", function()
	it("is inside near the center and on the boundary", function()
		expect(Zones.isInsideDome(Vector3.new(0, 100, 0), DOME)).toBe(true)
		expect(Zones.isInsideDome(Vector3.new(50, 100, 0), DOME)).toBe(true)
	end)

	it("is outside past the radius in any direction", function()
		expect(Zones.isInsideDome(Vector3.new(0, 151, 0), DOME)).toBe(false)
		expect(Zones.isInsideDome(Vector3.new(0, 49, 0), DOME)).toBe(false)
		expect(Zones.isInsideDome(Vector3.new(40, 100, 40), DOME)).toBe(false)
	end)
end)
