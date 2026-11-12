--!strict

local roblox = require("@lune/roblox")

local Storm = require("../../src/shared/Domain/Storm")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local CENTER = Vector3.new(0, 10, 0)
local BORDER = 500

describe("Storm.bringsHome", function()
	it("brings home a flyer past the border", function()
		expect(Storm.bringsHome(true, Vector3.new(800, 10, 0), CENTER, BORDER)).toBe(true)
		expect(Storm.bringsHome(true, Vector3.new(0, 10, -500), CENTER, BORDER)).toBe(true)
	end)

	it("leaves a flyer within the border where they are", function()
		-- Between an island and the central station.
		expect(Storm.bringsHome(true, Vector3.new(250, 10, 0), CENTER, BORDER)).toBe(false)
		expect(Storm.bringsHome(true, Vector3.new(0, 300, 350), CENTER, BORDER)).toBe(false)
	end)

	it("never moves anyone on a station", function()
		expect(Storm.bringsHome(false, Vector3.new(0, 10, 0), CENTER, BORDER)).toBe(false)
		-- A stale mode far out is still not in space: only the mode says so.
		expect(Storm.bringsHome(false, Vector3.new(900, 10, 0), CENTER, BORDER)).toBe(false)
	end)
end)
