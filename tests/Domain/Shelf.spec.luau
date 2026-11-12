--!strict
-- The island's shelf (docs/design/screens/storage-shelf.md): the order its niches fill in, where
-- an alien stands in one, and that the kit of meshes is modelled to the same numbers.

local fs = require("@lune/fs")

local BayConfig = require("../../src/shared/Config/BayConfig")
local Shelf = require("../../src/shared/Domain/Shelf")
local ShelfShape = require("../../src/shared/Config/ShelfShape")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local SHAPE: Shelf.Shape = {
	COLUMNS = 4,
	TIERS = 3,
	CELL_WIDTH = 2,
	CELL_HEIGHT = 2,
	DEPTH = 2,
	RADIUS = 10,
	BASE_HEIGHT = 0.5,
	BOARD_THICKNESS = 0.2,
	CROWN_HEIGHT = 0.4,
	UPRIGHT_WIDTH = 0.25,
	BACK_THICKNESS = 0.1,
}

local function close(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

describe("Shelf.niche", function()
	it("fills the middle tier from the middle out, then below, then above", function()
		local order = {}
		for index = 1, Shelf.capacity(SHAPE) do
			local niche = assert(Shelf.niche(index, SHAPE))
			table.insert(order, `{niche.tier}:{niche.column}`)
		end
		expect(table.concat(order, " ")).toBe("2:2 2:3 2:1 2:4 1:2 1:3 1:1 1:4 3:2 3:3 3:1 3:4")
	end)

	it("gives every niche once", function()
		local seen: { [string]: boolean } = {}
		for index = 1, Shelf.capacity(ShelfShape) do
			local niche = assert(Shelf.niche(index, ShelfShape))
			local key = `{niche.tier}:{niche.column}`
			expect(seen[key]).toBeNil()
			seen[key] = true
		end
	end)

	it("has no niche past the last, or for a non-whole index", function()
		expect(Shelf.niche(0, SHAPE)).toBeNil()
		expect(Shelf.niche(Shelf.capacity(SHAPE) + 1, SHAPE)).toBeNil()
		expect(Shelf.niche(1.5, SHAPE)).toBeNil()
	end)

	it("holds as many aliens as the island showed on its floor", function()
		expect(Shelf.capacity(ShelfShape)).toBe(24)
	end)

	it("has a niche for every alien the shelf may hold (decision 110)", function()
		expect(Shelf.capacity(ShelfShape)).toBe(BayConfig.SHELF_SLOTS)
	end)
end)

describe("Shelf.spot", function()
	it("stands an alien on its niche's board", function()
		local bottom = Shelf.spot({ column = 1, tier = 1 }, SHAPE)
		local top = Shelf.spot({ column = 1, tier = 3 }, SHAPE)
		expect(close(bottom.y, 0.7)).toBe(true)
		expect(close(top.y, 4.7)).toBe(true)
	end)

	it("spaces the niches by their width along the arc, mirrored about the middle", function()
		for column = 1, SHAPE.COLUMNS - 1 do
			local a = Shelf.spot({ column = column, tier = 1 }, SHAPE)
			local b = Shelf.spot({ column = column + 1, tier = 1 }, SHAPE)
			local arc = (b.angle - a.angle) * SHAPE.RADIUS
			expect(close(arc, SHAPE.CELL_WIDTH)).toBe(true)
		end
		local left = Shelf.spot({ column = 1, tier = 2 }, SHAPE)
		local right = Shelf.spot({ column = SHAPE.COLUMNS, tier = 2 }, SHAPE)
		expect(close(left.x, -right.x)).toBe(true)
		expect(close(left.z, right.z)).toBe(true)
	end)

	it("bends the ends toward the player and faces each niche to the arc's centre", function()
		local middle = Shelf.spot({ column = 2, tier = 1 }, SHAPE)
		local edge = Shelf.spot({ column = 1, tier = 1 }, SHAPE)
		expect(edge.z < middle.z).toBe(true)
		for column = 1, SHAPE.COLUMNS do
			local spot = Shelf.spot({ column = column, tier = 1 }, SHAPE)
			-- CFrame.Angles(0, angle, 0) turns -Z to (-sin, 0, -cos): toward (0, 0, -radius).
			local toCentreX, toCentreZ = -spot.x, -SHAPE.RADIUS - spot.z
			local length = math.sqrt(toCentreX ^ 2 + toCentreZ ^ 2)
			expect(close(toCentreX / length, -math.sin(spot.angle))).toBe(true)
			expect(close(toCentreZ / length, -math.cos(spot.angle))).toBe(true)
		end
	end)

	it("leaves room between the uprights and under the next board", function()
		local width, height = Shelf.room(SHAPE)
		expect(close(width, 1.75)).toBe(true)
		expect(close(height, 1.8)).toBe(true)
		expect(close(Shelf.height(SHAPE), 0.5 + 6 + 0.4)).toBe(true)
	end)
end)

-- A number constant `NAME = 1.5` of the Blender kit script.
local function blender(source: string, name: string): number
	local value = string.match(source, `\n{name} = ([%d%.]+)`)
	return assert(tonumber(value), `storage_kit.py has no {name}`)
end

describe("ShelfShape", function()
	it("matches the kit of meshes modelled in Blender", function()
		local source = fs.readFile("assets/blender/bay/storage_kit.py")
		for _, name in
			{
				"COLUMNS",
				"TIERS",
				"CELL_WIDTH",
				"CELL_HEIGHT",
				"DEPTH",
				"RADIUS",
				"BASE_HEIGHT",
				"BOARD_THICKNESS",
				"CROWN_HEIGHT",
				"UPRIGHT_WIDTH",
				"BACK_THICKNESS",
			}
		do
			expect(blender(source, name)).toBe((ShelfShape :: any)[name])
		end
	end)
end)
