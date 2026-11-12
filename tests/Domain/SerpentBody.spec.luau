--!strict

local roblox = require("@lune/roblox")

local SerpentBody = require("../../src/shared/Domain/SerpentBody")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude < 1e-6).toBe(true)
end

describe("SerpentBody.place", function()
	it("lays segments along a straight path, spacing apart", function()
		local trail = { Vector3.new(-100, 0, 0) }
		local segments = SerpentBody.place(Vector3.new(0, 0, 0), trail, 5, 3)
		expect(#segments).toBe(3)
		near(segments[1], Vector3.new(-5, 0, 0))
		near(segments[2], Vector3.new(-10, 0, 0))
		near(segments[3], Vector3.new(-15, 0, 0))
	end)

	it("follows the path round a corner", function()
		-- Head at the origin; the path goes 3 studs back along X, then along Z.
		local trail = { Vector3.new(-3, 0, 0), Vector3.new(-3, 0, 20) }
		local segments = SerpentBody.place(Vector3.new(0, 0, 0), trail, 5, 2)
		near(segments[1], Vector3.new(-3, 0, 2))
		near(segments[2], Vector3.new(-3, 0, 7))
	end)

	it("bunches the segments past the end of a short path at its end", function()
		local segments = SerpentBody.place(Vector3.new(0, 0, 0), { Vector3.new(-6, 0, 0) }, 5, 3)
		near(segments[1], Vector3.new(-5, 0, 0))
		near(segments[2], Vector3.new(-6, 0, 0))
		near(segments[3], Vector3.new(-6, 0, 0))
	end)

	it("keeps a fresh serpent with no path in one spot", function()
		local segments = SerpentBody.place(Vector3.new(1, 2, 3), {}, 5, 2)
		near(segments[1], Vector3.new(1, 2, 3))
		near(segments[2], Vector3.new(1, 2, 3))
	end)
end)

describe("SerpentBody.record", function()
	it("adds a point only once the head has moved a step", function()
		local trail: { Vector3 } = {}
		SerpentBody.record(trail, Vector3.new(0, 0, 0), 2, 100)
		SerpentBody.record(trail, Vector3.new(1, 0, 0), 2, 100)
		expect(#trail).toBe(1)
		SerpentBody.record(trail, Vector3.new(3, 0, 0), 2, 100)
		expect(#trail).toBe(2)
		near(trail[1], Vector3.new(3, 0, 0))
	end)

	it("drops the path past the body's length, keeping one point beyond it", function()
		local trail: { Vector3 } = {}
		for x = 0, 100, 10 do
			SerpentBody.record(trail, Vector3.new(x, 0, 0), 1, 25)
		end
		-- Newest first: 100, 90, 80, 70 (30 studs back, past 25).
		expect(#trail).toBe(4)
		near(trail[4], Vector3.new(70, 0, 0))
	end)
end)

describe("SerpentBody.sizeOf", function()
	it("tapers evenly from the neck to the tail", function()
		expect(SerpentBody.sizeOf(1, 18, 9, 3)).toBe(9)
		expect(SerpentBody.sizeOf(18, 18, 9, 3)).toBe(3)
		expect(math.abs(SerpentBody.sizeOf(10, 19, 9, 3) - 6) < 1e-9).toBe(true)
	end)

	it("gives a body of one segment the neck's size", function()
		expect(SerpentBody.sizeOf(1, 1, 9, 3)).toBe(9)
	end)
end)

describe("SerpentBody.stretchOf", function()
	it("keeps a segment of the kit's size as it was made", function()
		local across, along = SerpentBody.stretchOf(9, 9, 0.55)
		expect(across).toBe(1)
		expect(along).toBe(1)
	end)

	it("shortens a thin segment less than it narrows it", function()
		local across, along = SerpentBody.stretchOf(3, 9, 0.55)
		expect(math.abs(across - 1 / 3) < 1e-9).toBe(true)
		expect(math.abs(along - 0.7) < 1e-9).toBe(true)
	end)
end)

describe("SerpentBody.starred", function()
	it("puts the flank stars on every third segment", function()
		expect(SerpentBody.starred(1, 3)).toBe(false)
		expect(SerpentBody.starred(3, 3)).toBe(true)
		expect(SerpentBody.starred(6, 3)).toBe(true)
		expect(SerpentBody.starred(7, 3)).toBe(false)
	end)

	it("puts them nowhere when every is zero", function()
		expect(SerpentBody.starred(3, 0)).toBe(false)
	end)
end)

describe("SerpentBody.hitSpheres", function()
	it("covers the head and every segment down the path, each a little wider than drawn", function()
		local head = Vector3.new(7, 0, 0)
		local neck = Vector3.new(0, 0, 0)
		local trail = { Vector3.new(-100, 0, 0) }
		local spheres = SerpentBody.hitSpheres(head, 8, neck, trail, 6, 3, 9, 3, 2)
		expect(#spheres).toBe(4)
		near(spheres[1].center, head)
		expect(spheres[1].radius).toBe(8)
		-- The segments where the clients draw them, as thick as drawn plus the padding.
		local placed = SerpentBody.place(neck, trail, 6, 3)
		for index = 1, 3 do
			near(spheres[index + 1].center, placed[index])
			expect(spheres[index + 1].radius).toBe(SerpentBody.sizeOf(index, 3, 9, 3) / 2 + 2)
		end
		-- The tail end, 18 studs behind the neck, is in reach.
		expect(spheres[4].center.X).toBeCloseTo(-18, 1e-6)
	end)

	it("has no gaps: neighbouring spheres overlap down the body", function()
		local trail = { Vector3.new(-200, 0, 0) }
		local spheres = SerpentBody.hitSpheres(Vector3.new(7, 0, 0), 8, Vector3.new(0, 0, 0), trail, 6, 18, 9, 3, 2)
		for index = 2, #spheres do
			local gap = (spheres[index].center - spheres[index - 1].center).Magnitude
			expect(gap < spheres[index].radius + spheres[index - 1].radius).toBe(true)
		end
	end)
end)
