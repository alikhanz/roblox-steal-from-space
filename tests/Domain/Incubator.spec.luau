--!strict
-- The island incubator (docs/design/screens/incubator.md): the order of its slots round the ring,
-- the height of the chips over its eggs, that a large egg fits a capsule, and that the kit of meshes
-- is modelled to the same numbers.

local fs = require("@lune/fs")

local EggConfig = require("../../src/shared/Config/EggConfig")
local Incubator = require("../../src/shared/Domain/Incubator")
local IncubatorShape = require("../../src/shared/Config/IncubatorShape")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- A medium egg's height (EggLooks.EGG_SIZE.Y, which needs Roblox's Vector3).
local MEDIUM_EGG_HEIGHT = 2.1

local function close(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

describe("Incubator.slotAngle", function()
	it("puts the first slot toward the entrance and the next ones to either side by turns", function()
		local step = math.pi * 2 / IncubatorShape.POSITIONS
		expect(close(Incubator.slotAngle(1, IncubatorShape), math.pi)).toBe(true)
		expect(close(Incubator.slotAngle(2, IncubatorShape), math.pi + step)).toBe(true)
		expect(close(Incubator.slotAngle(3, IncubatorShape), math.pi - step)).toBe(true)
		expect(close(Incubator.slotAngle(4, IncubatorShape), math.pi + 2 * step)).toBe(true)
	end)

	it("gives every slot its own place round the ring", function()
		local seen: { [number]: boolean } = {}
		for index = 1, IncubatorShape.POSITIONS do
			local angle = Incubator.slotAngle(index, IncubatorShape) % (math.pi * 2)
			local position = math.floor(angle / (math.pi * 2) * IncubatorShape.POSITIONS + 0.5)
				% IncubatorShape.POSITIONS
			expect(seen[position]).toBe(nil)
			seen[position] = true
		end
	end)

	it("refuses a slot the ring does not have", function()
		expect(pcall(Incubator.slotAngle, 0, IncubatorShape)).toBe(false)
		expect(pcall(Incubator.slotAngle, IncubatorShape.POSITIONS + 1, IncubatorShape)).toBe(false)
	end)
end)

describe("Incubator.chipAbove", function()
	it("hangs the chips of eggs lower than the petals in one row over the tips", function()
		for _, size in EggConfig.SIZES do
			local height = MEDIUM_EGG_HEIGHT * size.scale
			if IncubatorShape.EGG_FLOOR + height + 0.5 < IncubatorShape.POD_HEIGHT then
				local centre = IncubatorShape.EGG_FLOOR + height / 2
				local chip = centre + Incubator.chipAbove(height, height / 2, IncubatorShape, 0.6, 0.5)
				expect(close(chip, IncubatorShape.POD_HEIGHT + 0.6)).toBe(true)
			end
		end
	end)

	it("hangs a taller egg's chip over the egg itself", function()
		local height = 4
		expect(close(Incubator.chipAbove(height, height / 2, IncubatorShape, 0.6, 0.5), height / 2 + 0.5)).toBe(true)
	end)

	it("hangs the chip over what an egg wears on top, not its box", function()
		local height = 3
		expect(close(Incubator.chipAbove(height, 2.6, IncubatorShape, 0.6, 0.5), 3.1)).toBe(true)
	end)
end)

describe("IncubatorShape", function()
	it("holds a large egg under the petals' tips", function()
		local largest = 0
		for _, size in EggConfig.SIZES do
			largest = math.max(largest, size.scale)
		end
		expect(IncubatorShape.EGG_FLOOR + MEDIUM_EGG_HEIGHT * largest <= IncubatorShape.POD_HEIGHT + 1e-9).toBe(true)
	end)

	it("stands the slots on the dais, apart from each other and from the heater", function()
		local shape = IncubatorShape
		expect(shape.RING_RADIUS + shape.SOCKET_RADIUS <= shape.DAIS_RADIUS).toBe(true)
		expect(shape.RING_RADIUS - shape.SOCKET_RADIUS > shape.CORE_RADIUS).toBe(true)
		local between = 2 * shape.RING_RADIUS * math.sin(math.pi / shape.POSITIONS)
		expect(between > 2 * shape.SOCKET_RADIUS).toBe(true)
		expect(shape.BUD_HEIGHT < shape.POD_HEIGHT).toBe(true)
	end)

	it("matches the kit Blender models", function()
		local source = fs.readFile("assets/blender/bay/incubator_kit.py")
		for _, name in
			{
				"RING_RADIUS",
				"DAIS_RADIUS",
				"DAIS_HEIGHT",
				"CORE_RADIUS",
				"CORE_HEIGHT",
				"SOCKET_RADIUS",
				"EGG_FLOOR",
				"POD_HEIGHT",
				"BUD_HEIGHT",
			}
		do
			local text: string? = string.match(source, `\n{name} = ([%d%.]+)`)
			assert(text, `incubator_kit.py has no {name}`)
			local value = tonumber(text)
			expect(value).toBe((IncubatorShape :: any)[name])
		end
	end)
end)
