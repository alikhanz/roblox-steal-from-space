--!strict

local Grab = require("../../src/shared/Domain/Grab")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Grab.step", function()
	it("fills over the grab time while holding in reach", function()
		local progress = 0
		for _ = 1, 30 do
			progress = Grab.step(progress, true, true, 1, 1 / 60)
		end
		expect(progress).toBeCloseTo(0.5, 1e-9)
		for _ = 1, 30 do
			progress = Grab.step(progress, true, true, 1, 1 / 60)
		end
		expect(Grab.isComplete(progress)).toBe(true)
	end)

	it("resets when letting go or drifting out of reach", function()
		expect(Grab.step(0.8, false, true, 1, 1 / 60)).toBe(0)
		expect(Grab.step(0.8, true, false, 1, 1 / 60)).toBe(0)
	end)

	it("caps at complete", function()
		expect(Grab.step(0.99, true, true, 1, 1)).toBe(1)
	end)

	it("completes instantly with no grab time", function()
		expect(Grab.step(0, true, true, 0, 1 / 60)).toBe(1)
	end)
end)

describe("Grab.magnetVelocity", function()
	local roblox = require("@lune/roblox")
	-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
	local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
	local MAGNET: Grab.MagnetTuning = { speed = 14, holdDistance = 3, response = 6 }

	it("pulls toward the egg from a distance", function()
		local velocity = Grab.magnetVelocity(Vector3.zero, Vector3.new(10, 0, 0), Vector3.zero, 1, MAGNET)
		expect(velocity.X < 0).toBe(true)
		expect(math.abs(velocity.Y) + math.abs(velocity.Z) < 1e-6).toBe(true)
		expect(velocity.Magnitude <= MAGNET.speed + 1e-6).toBe(true)
	end)

	it("kills the drift at the hold distance", function()
		local velocity = Vector3.new(0, 0, 20)
		for _ = 1, 120 do
			velocity = Grab.magnetVelocity(velocity, Vector3.new(3, 0, 0), Vector3.zero, 1 / 60, MAGNET)
		end
		expect(velocity.Magnitude).toBeCloseTo(0, 1e-3)
	end)

	it("settles at the hold distance instead of overshooting", function()
		local position = Vector3.new(12, 0, 0)
		local velocity = Vector3.zero
		for _ = 1, 600 do
			velocity = Grab.magnetVelocity(velocity, position, Vector3.zero, 1 / 60, MAGNET)
			position += velocity * (1 / 60)
		end
		expect(position.Magnitude).toBeCloseTo(MAGNET.holdDistance, 0.05)
		expect(velocity.Magnitude).toBeCloseTo(0, 0.05)
	end)
end)
