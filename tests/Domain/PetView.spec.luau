--!strict

local PetView = require("../../src/shared/Domain/PetView")
local Test = require("../../lune/lib/Test")
local roblox = require("@lune/roblox")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

describe("PetView.shows", function()
	it("shows an island's pets within reach and keeps them until past the margin", function()
		expect(PetView.shows(199, false, 200, 60)).toBe(true)
		expect(PetView.shows(200, false, 200, 60)).toBe(true)
		expect(PetView.shows(230, false, 200, 60)).toBe(false)
		expect(PetView.shows(230, true, 200, 60)).toBe(true)
		expect(PetView.shows(260, true, 200, 60)).toBe(true)
		expect(PetView.shows(261, true, 200, 60)).toBe(false)
	end)
end)

describe("PetView.nearest", function()
	it("gives the island whose centre is nearest", function()
		local centres = { Vector3.new(100, 0, 0), Vector3.new(0, 0, 100), Vector3.new(-100, 0, 0) }
		expect(PetView.nearest(Vector3.new(90, 5, 10), centres)).toBe(1)
		expect(PetView.nearest(Vector3.new(-20, 0, 80), centres)).toBe(2)
		expect(PetView.nearest(Vector3.new(-120, 30, -10), centres)).toBe(3)
	end)
end)

describe("PetView.toDrop", function()
	it("keeps islands hidden for less than the hold", function()
		expect(PetView.toDrop({ [1] = 10, [4] = 30 }, 60, 60, 2)).toEqual({})
	end)

	it("drops an island once it has been hidden for the hold", function()
		expect(PetView.toDrop({ [1] = 10, [4] = 30 }, 70, 60, 2)).toEqual({ 1 })
		expect(PetView.toDrop({ [1] = 10, [4] = 30 }, 95, 60, 2)).toEqual({ 1, 4 })
	end)

	it("keeps only the newest few hidden, the oldest going first", function()
		expect(PetView.toDrop({ [3] = 20, [5] = 10, [2] = 30 }, 31, 60, 2)).toEqual({ 5 })
		expect(PetView.toDrop({ [3] = 20, [5] = 10, [2] = 30, [7] = 25 }, 31, 60, 2)).toEqual({ 5, 3 })
		expect(PetView.toDrop({ [3] = 20, [5] = 10 }, 31, 60, 0)).toEqual({ 5, 3 })
	end)

	it("drops in a steady order islands hidden at the same moment", function()
		expect(PetView.toDrop({ [6] = 10, [2] = 10, [4] = 10 }, 11, 60, 1)).toEqual({ 2, 4 })
	end)

	it("has nothing to drop with nothing hidden", function()
		expect(PetView.toDrop({}, 100, 60, 2)).toEqual({})
	end)
end)
