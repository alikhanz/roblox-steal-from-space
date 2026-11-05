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
