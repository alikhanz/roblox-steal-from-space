--!strict

local JetpackSwitch = require("../../src/shared/Domain/JetpackSwitch")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: JetpackSwitch.Tuning = {
	doubleTapSeconds = 0.4,
	minReleaseSeconds = 0.05,
	landPushSpeed = 4,
	landStillSpeed = 1,
}
local STEP = 1 / 60

type Frame = { pressed: boolean?, inSpace: boolean?, landed: boolean? }

-- Runs `steps` simulation steps with the same input from `state`.
local function run(state: JetpackSwitch.State, frame: Frame, steps: number): JetpackSwitch.State
	local input: JetpackSwitch.Input = {
		inSpace = frame.inSpace == true,
		pressed = frame.pressed == true,
		landed = frame.landed == true,
	}
	for _ = 1, steps do
		state = JetpackSwitch.step(state, input, STEP, TUNING)
	end
	return state
end

-- A tap under the dome: pressed for 6 steps, let go for 6 (0.1 s each).
local function tap(state: JetpackSwitch.State): JetpackSwitch.State
	return run(run(state, { pressed = true }, 6), {}, 6)
end

local WALKING = JetpackSwitch.initial(TUNING)

describe("JetpackSwitch.step", function()
	it("starts walking", function()
		expect(WALKING.on).toBe(false)
	end)

	it("is always on in space", function()
		expect(run(WALKING, { inSpace = true }, 1).on).toBe(true)
		expect(run(WALKING, { inSpace = true, landed = true }, 1).on).toBe(true)
	end)

	it("keeps flying when a flyer comes in under the dome", function()
		local flying = run(WALKING, { inSpace = true }, 1)
		expect(run(flying, {}, 120).on).toBe(true)
	end)

	it("does not switch on with one jump", function()
		expect(run(tap(WALKING), {}, 60).on).toBe(false)
	end)

	it("switches on with a double jump", function()
		expect(tap(tap(WALKING)).on).toBe(true)
	end)

	it("switches off with a double tap of up while flying", function()
		local flying = tap(tap(WALKING))
		expect(tap(tap(flying)).on).toBe(false)
	end)

	it("needs the second tap soon after the first", function()
		local slow = tap(run(tap(WALKING), {}, 30))
		expect(slow.on).toBe(false)
	end)

	it("does not count a held jump as taps", function()
		local holding = run(WALKING, { pressed = true }, 3)
		-- The character starts a jump: Roblox lets go of the input for a single step.
		holding = run(holding, {}, 1)
		holding = run(holding, { pressed = true }, 3)
		expect(holding.on).toBe(false)
		expect(holding.tapWindow > 0).toBe(true)
	end)

	it("does not let taps in space start a double jump under the dome", function()
		local inSpace = run(WALKING, { inSpace = true, pressed = true }, 6)
		inSpace = run(inSpace, { inSpace = true }, 6)
		-- One tap after coming in under the dome: still flying.
		expect(tap(inSpace).on).toBe(true)
	end)

	it("switches off on landing", function()
		local flying = run(WALKING, { inSpace = true }, 1)
		expect(run(flying, { landed = true }, 1).on).toBe(false)
	end)

	it("stops counting the release once it is long enough", function()
		local released = run(WALKING, {}, 600)
		expect(released.releasedFor).toBe(TUNING.minReleaseSeconds)
		expect(released.tapWindow).toBe(0)
	end)
end)

describe("JetpackSwitch.isLanding", function()
	it("lands when pushing down while the floor holds the body", function()
		expect(JetpackSwitch.isLanding(true, -30, 0, TUNING)).toBe(true)
	end)

	it("does not land while still falling freely", function()
		expect(JetpackSwitch.isLanding(true, -30, -29, TUNING)).toBe(false)
	end)

	it("does not land without holding down", function()
		expect(JetpackSwitch.isLanding(false, -30, 0, TUNING)).toBe(false)
	end)

	it("does not land at the very start of a descent", function()
		expect(JetpackSwitch.isLanding(true, -2, 0, TUNING)).toBe(false)
	end)
end)
