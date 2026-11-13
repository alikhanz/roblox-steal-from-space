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

describe("PetView.levels", function()
	local REACH = { REACH = 200, MARGIN = 60, NEIGHBOURS = 2, NEIGHBOUR_REACH = 600 }

	it("shows the near island whole and the next two nearest plain", function()
		expect(PetView.levels({ 50, 300, 560, 700, 300, 560 }, {}, REACH)).toEqual({
			[1] = "Whole",
			[2] = "Plain",
			[5] = "Plain",
		})
	end)

	it("shows two islands plain with none near", function()
		expect(PetView.levels({ 400, 400, 400, 400 }, {}, REACH)).toEqual({ [1] = "Plain", [2] = "Plain" })
		expect(PetView.levels({ 500, 420, 450, 410 }, {}, REACH)).toEqual({ [2] = "Plain", [4] = "Plain" })
	end)

	it("shows nothing far out in space", function()
		expect(PetView.levels({ 900, 1200, 650 }, {}, REACH)).toEqual({})
	end)

	it("keeps a plain island until another is a margin nearer", function()
		local was: { [number]: PetView.Level } = { [1] = "Plain", [2] = "Plain" }
		expect(PetView.levels({ 400, 420, 380 }, was, REACH)).toEqual({ [1] = "Plain", [2] = "Plain" })
		expect(PetView.levels({ 400, 450, 380 }, was, REACH)).toEqual({ [1] = "Plain", [3] = "Plain" })
	end)

	it("keeps a plain island until past the neighbours' reach by the margin", function()
		expect(PetView.levels({ 640 }, { [1] = "Plain" }, REACH)).toEqual({ [1] = "Plain" })
		expect(PetView.levels({ 640 }, {}, REACH)).toEqual({})
		expect(PetView.levels({ 661 }, { [1] = "Plain" }, REACH)).toEqual({})
	end)

	it("keeps a whole island whole until past the margin, then plain", function()
		expect(PetView.levels({ 250 }, { [1] = "Whole" }, REACH)).toEqual({ [1] = "Whole" })
		expect(PetView.levels({ 250 }, { [1] = "Plain" }, REACH)).toEqual({ [1] = "Plain" })
		expect(PetView.levels({ 270 }, { [1] = "Whole" }, REACH)).toEqual({ [1] = "Plain" })
	end)

	it("shows every near island whole, however many", function()
		expect(PetView.levels({ 150, 180, 190, 300 }, {}, REACH)).toEqual({
			[1] = "Whole",
			[2] = "Whole",
			[3] = "Whole",
			[4] = "Plain",
		})
	end)
end)

describe("PetView.ahead", function()
	it("leads the camera along its flight", function()
		local ahead = PetView.ahead(Vector3.new(10, 0, 0), Vector3.new(0, 0, 0), 0.25, 0.75, 600)
		expect(ahead.X).toBe(40)
		expect(ahead.Y).toBe(0)
	end)

	it("stays put for a camera standing still, a jump or no time", function()
		local eye = Vector3.new(5, 0, 5)
		expect(PetView.ahead(eye, eye, 0.25, 0.75, 600)).toBe(eye)
		expect(PetView.ahead(eye, Vector3.new(1000, 0, 0), 0.25, 0.75, 600)).toBe(eye)
		expect(PetView.ahead(eye, Vector3.zero, 0, 0.75, 600)).toBe(eye)
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
