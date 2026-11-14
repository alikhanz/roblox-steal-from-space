--!strict

local PetBox = require("../../src/shared/Domain/PetBox")
local Test = require("../../lune/lib/Test")
local roblox = require("@lune/roblox")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global types describe them.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
local CFrame = (roblox :: any).CFrame :: typeof(CFrame)

local function near(a: number, b: number)
	expect(math.abs(a - b) < 1e-4).toBe(true)
end

-- A body 4 wide at x = 10, and a wing 6 wide to its right.
local BODY = { cframe = CFrame.new(10, 2, 0), size = Vector3.new(4, 4, 4) }
local WING = { cframe = CFrame.new(15, 3, 0), size = Vector3.new(6, 1, 2) }

describe("PetBox.bounds", function()
	it("boxes the pieces in the frame's space", function()
		local low, high = PetBox.bounds({ BODY, WING }, CFrame.new(10, 0, 0))
		assert(low and high, "a box")
		near(low.X, -2)
		near(high.X, 8)
		near(low.Y, 0)
		near(high.Y, 4)
	end)

	it("has no box for no pieces", function()
		local low, high = PetBox.bounds({}, CFrame.new())
		expect(low).toBe(nil)
		expect(high).toBe(nil)
	end)

	it("reads a turned piece by its corners", function()
		local turned = { cframe = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0), size = Vector3.new(6, 2, 2) }
		local low, high = PetBox.bounds({ turned }, CFrame.new())
		assert(low and high, "a box")
		near(high.Z - low.Z, 6)
		near(high.X - low.X, 2)
	end)
end)

describe("PetBox.middle", function()
	it("is the body's middle across the floor, whatever dresses it", function()
		-- In the space of the box round body and wing (centred at x = 13), the body's middle is 3 left.
		local x, z = PetBox.middle({ BODY }, CFrame.new(13, 2.5, 0))
		near(x, -3)
		near(z, 0)
	end)

	it("turns with the frame", function()
		local frame = CFrame.new(10, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		local x, z = PetBox.middle({ { cframe = CFrame.new(10, 0, -3), size = Vector3.one } }, frame)
		near(x, 3)
		near(z, 0)
	end)

	it("is the frame's own axis for no pieces", function()
		local x, z = PetBox.middle({}, CFrame.new(5, 5, 5))
		expect(x).toBe(0)
		expect(z).toBe(0)
	end)
end)

describe("PetBox.reach", function()
	it("is how far the farthest side reaches from the axis", function()
		-- From the body's middle the wing reaches 8 to the right, the body 2 to the left.
		near(PetBox.reach({ BODY, WING }, CFrame.new(10, 0, 0)), 8)
	end)

	it("counts depth as well as width", function()
		local long = { cframe = CFrame.new(0, 0, 4), size = Vector3.new(2, 2, 10) }
		near(PetBox.reach({ long }, CFrame.new()), 9)
	end)

	it("is nothing for no pieces", function()
		expect(PetBox.reach({}, CFrame.new())).toBe(0)
	end)
end)
