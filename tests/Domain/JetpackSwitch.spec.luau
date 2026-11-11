--!strict

local JetpackSwitch = require("../../src/shared/Domain/JetpackSwitch")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: JetpackSwitch.Tuning = {
	doubleTapSeconds = 0.4,
	minReleaseSeconds = 0.05,
	landGap = 0.75,
	landRiseSpeed = 2,
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
	it("lands with the feet on the floor", function()
		expect(JetpackSwitch.isLanding(0, 0, false, TUNING)).toBe(true)
		expect(JetpackSwitch.isLanding(0.5, -30, false, TUNING)).toBe(true)
	end)

	it("lands without holding down", function()
		expect(JetpackSwitch.isLanding(0.2, -0.5, false, TUNING)).toBe(true)
	end)

	it("does not land with no floor near", function()
		expect(JetpackSwitch.isLanding(nil, 0, false, TUNING)).toBe(false)
		expect(JetpackSwitch.isLanding(3, -10, false, TUNING)).toBe(false)
	end)

	it("does not land while taking off", function()
		-- The double jump starts right over the floor, the jump still carrying the body up.
		expect(JetpackSwitch.isLanding(0.3, 40, false, TUNING)).toBe(false)
		expect(JetpackSwitch.isLanding(0.3, 0, true, TUNING)).toBe(false)
	end)
end)

describe("JetpackSwitch.floorReach", function()
	it("looks a little under the feet when still or climbing", function()
		expect(JetpackSwitch.floorReach(0, 1 / 60, TUNING)).toBe(TUNING.landGap)
		expect(JetpackSwitch.floorReach(50, 1 / 60, TUNING)).toBe(TUNING.landGap)
	end)

	it("looks two steps ahead when falling fast", function()
		expect(JetpackSwitch.floorReach(-240, 1 / 60, TUNING)).toBeCloseTo(TUNING.landGap + 8)
	end)
end)

describe("JetpackSwitch.limitDescent", function()
	local STEP_TIME = 1 / 60

	it("leaves the velocity alone with no floor near", function()
		expect(JetpackSwitch.limitDescent(-250, nil, STEP_TIME)).toBe(-250)
	end)

	it("never takes a fast flyer through the floor in one step", function()
		local limited = JetpackSwitch.limitDescent(-250, 2, STEP_TIME)
		expect(limited).toBeCloseTo(-120)
		-- One step at the limit ends on the floor, not under it.
		expect(2 + limited * STEP_TIME).toBeCloseTo(0)
	end)

	it("stops the descent on the floor and inside it", function()
		expect(JetpackSwitch.limitDescent(-30, 0, STEP_TIME)).toBe(0)
		expect(JetpackSwitch.limitDescent(-30, -0.4, STEP_TIME)).toBe(0)
	end)

	it("lets a flyer climb and slide along the floor", function()
		expect(JetpackSwitch.limitDescent(20, 0, STEP_TIME)).toBe(20)
		expect(JetpackSwitch.limitDescent(-1, 3, STEP_TIME)).toBe(-1)
	end)
end)
