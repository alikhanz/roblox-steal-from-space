--!strict

local Grab = require("../../src/shared/Domain/Grab")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Grab.step", function()
	it("fills over the grab time while holding in reach", function()
		local progress = 0
		for _ = 1, 30 do
			progress = Grab.step(progress, true, true, true, 1, 1 / 60)
		end
		expect(progress).toBeCloseTo(0.5, 1e-9)
		for _ = 1, 30 do
			progress = Grab.step(progress, true, true, true, 1, 1 / 60)
		end
		expect(Grab.isComplete(progress)).toBe(true)
	end)

	it("resets when letting go or losing the lock", function()
		expect(Grab.step(0.8, false, true, true, 1, 1 / 60)).toBe(0)
		expect(Grab.step(0.8, true, false, false, 1, 1 / 60)).toBe(0)
	end)

	it("holds while locked on but still being pulled into reach", function()
		expect(Grab.step(0.4, true, true, false, 1, 1 / 60)).toBe(0.4)
	end)

	it("caps at complete", function()
		expect(Grab.step(0.99, true, true, true, 1, 1)).toBe(1)
	end)

	it("completes instantly with no grab time", function()
		expect(Grab.step(0, true, true, true, 0, 1 / 60)).toBe(1)
	end)
end)

describe("Grab.lockRange", function()
	it("is the reach for a slow flyer and grows with top speed", function()
		expect(Grab.lockRange(30, 9, 0.2)).toBe(9)
		expect(Grab.lockRange(250, 9, 0.2)).toBeCloseTo(50, 1e-9)
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

	it("pulls a fast flyer in from the lock range at their own top speed", function()
		local velocity = Grab.magnetVelocity(Vector3.zero, Vector3.new(50, 0, 0), Vector3.zero, 1, MAGNET, 250)
		expect(velocity.Magnitude > MAGNET.speed * 5).toBe(true)
		expect(velocity.Magnitude <= 250 + 1e-6).toBe(true)
	end)

	it("brings a flyer passing at full speed to the egg", function()
		local position = Vector3.new(-50, 0, 10)
		local velocity = Vector3.new(250, 0, 0)
		for _ = 1, 300 do
			velocity = Grab.magnetVelocity(velocity, position, Vector3.zero, 1 / 60, MAGNET, 250)
			position += velocity * (1 / 60)
		end
		expect(position.Magnitude).toBeCloseTo(MAGNET.holdDistance, 0.1)
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

describe("Grab.nextEngaged", function()
	local function input(overrides: { [string]: any }): Grab.EngageInput
		local base: { [string]: any } = {
			engaged = nil,
			pressed = false,
			wasPressed = false,
			candidate = "Nest1",
			engagedPresent = false,
			movingAway = false,
			blocked = false,
		}
		for key, value in overrides do
			base[key] = value
		end
		return base :: any
	end

	it("locks on the offered egg with one press", function()
		expect(Grab.nextEngaged(input({ pressed = true }))).toBe("Nest1")
	end)

	it("needs a fresh press: holding the input does not lock on again", function()
		expect(Grab.nextEngaged(input({ pressed = true, wasPressed = true }))).toBe(nil)
	end)

	it("keeps the lock without holding the input", function()
		expect(Grab.nextEngaged(input({ engaged = "Nest1", engagedPresent = true }))).toBe("Nest1")
	end)

	it("lets go on a second press", function()
		expect(Grab.nextEngaged(input({ engaged = "Nest1", engagedPresent = true, pressed = true }))).toBe(nil)
	end)

	it("lets go when the egg is gone or the flyer steers away", function()
		expect(Grab.nextEngaged(input({ engaged = "Nest1", engagedPresent = false }))).toBe(nil)
		expect(Grab.nextEngaged(input({ engaged = "Nest1", engagedPresent = true, movingAway = true }))).toBe(nil)
	end)

	it("locks on afresh when pressed right after losing the lock", function()
		local next = Grab.nextEngaged(input({ engaged = "Loose1", engagedPresent = false, pressed = true }))
		expect(next).toBe("Nest1")
	end)

	it("lets go and refuses to lock on while grabbing is impossible", function()
		expect(Grab.nextEngaged(input({ engaged = "Nest1", engagedPresent = true, blocked = true }))).toBe(nil)
		expect(Grab.nextEngaged(input({ pressed = true, blocked = true }))).toBe(nil)
	end)

	it("does nothing on a press with no egg offered", function()
		local nothingNear = input({ pressed = true })
		nothingNear.candidate = nil
		expect(Grab.nextEngaged(nothingNear)).toBe(nil)
	end)
end)

describe("Grab.isMovingAway", function()
	local roblox = require("@lune/roblox")
	local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)
	local toEgg = Vector3.new(10, 3, 0)

	it("is true when steering clearly away from the egg", function()
		expect(Grab.isMovingAway(Vector3.new(-1, 0, 0), toEgg, 0.5, -0.5)).toBe(true)
		expect(Grab.isMovingAway(Vector3.new(-0.7, 0, 0.7), toEgg, 0.5, -0.5)).toBe(true)
	end)

	it("is false toward the egg, sideways, or with a light touch", function()
		expect(Grab.isMovingAway(Vector3.new(1, 0, 0), toEgg, 0.5, -0.5)).toBe(false)
		expect(Grab.isMovingAway(Vector3.new(0, 0, 1), toEgg, 0.5, -0.5)).toBe(false)
		expect(Grab.isMovingAway(Vector3.new(-0.3, 0, 0), toEgg, 0.5, -0.5)).toBe(false)
	end)

	it("ignores an egg straight above or below", function()
		expect(Grab.isMovingAway(Vector3.new(-1, 0, 0), Vector3.new(0, 8, 0), 0.5, -0.5)).toBe(false)
	end)
end)

describe("Grab.buttonRange", function()
	it("is the button's own range, or a fast flyer's longer lock range", function()
		expect(Grab.buttonRange(9, 30)).toBe(30)
		expect(Grab.buttonRange(50, 30)).toBe(50)
	end)
end)
