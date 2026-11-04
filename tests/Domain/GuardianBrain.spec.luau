--!strict

local GuardianBrain = require("../../src/shared/Domain/GuardianBrain")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: GuardianBrain.Tuning = {
	aggroDelaySeconds = 1,
	leashRadius = 200,
	maxChaseSeconds = 20,
	homeRadius = 3,
	catchRadius = 6,
}

local function situation(overrides: { [string]: any }): GuardianBrain.Situation
	local base: { [string]: any } = {
		hasTarget = false,
		stolenSeconds = 0,
		targetInStation = false,
		targetDistanceFromHome = 0,
		distanceToHome = 0,
		chaseSeconds = 0,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

describe("GuardianBrain.next", function()
	it("sleeps while nobody carries its egg", function()
		expect(GuardianBrain.next("Sleep", situation({}), TUNING)).toBe("Sleep")
	end)

	it("wakes up only after the aggro delay", function()
		local justTaken = situation({ hasTarget = true, stolenSeconds = 0.5 })
		expect(GuardianBrain.next("Sleep", justTaken, TUNING)).toBe("Sleep")
		local afterDelay = situation({ hasTarget = true, stolenSeconds = 1 })
		expect(GuardianBrain.next("Sleep", afterDelay, TUNING)).toBe("Chase")
	end)

	it("stays asleep if the thief is already safe or out of range", function()
		local safe = situation({ hasTarget = true, stolenSeconds = 2, targetInStation = true })
		expect(GuardianBrain.next("Sleep", safe, TUNING)).toBe("Sleep")
		local far = situation({ hasTarget = true, stolenSeconds = 2, targetDistanceFromHome = 201 })
		expect(GuardianBrain.next("Sleep", far, TUNING)).toBe("Sleep")
	end)

	it("keeps chasing a thief in range", function()
		local chasing = situation({ hasTarget = true, targetDistanceFromHome = 150, chaseSeconds = 10 })
		expect(GuardianBrain.next("Chase", chasing, TUNING)).toBe("Chase")
	end)

	it("gives up when the thief is lost, safe, too far or chased too long", function()
		local cases = {
			situation({ hasTarget = false }),
			situation({ hasTarget = true, targetInStation = true }),
			situation({ hasTarget = true, targetDistanceFromHome = 201 }),
			situation({ hasTarget = true, chaseSeconds = 21 }),
		}
		for _, case in cases do
			expect(GuardianBrain.next("Chase", case, TUNING)).toBe("Return")
		end
	end)

	it("goes back to sleep once home", function()
		expect(GuardianBrain.next("Return", situation({ distanceToHome = 50 }), TUNING)).toBe("Return")
		expect(GuardianBrain.next("Return", situation({ distanceToHome = 2 }), TUNING)).toBe("Sleep")
	end)

	it("turns around on the way home once its egg is taken again", function()
		local thief = situation({ hasTarget = true, stolenSeconds = 1, distanceToHome = 50 })
		expect(GuardianBrain.next("Return", thief, TUNING)).toBe("Chase")
		local justTaken = situation({ hasTarget = true, stolenSeconds = 0.5, distanceToHome = 50 })
		expect(GuardianBrain.next("Return", justTaken, TUNING)).toBe("Return")
		local far =
			situation({ hasTarget = true, stolenSeconds = 5, distanceToHome = 50, targetDistanceFromHome = 201 })
		expect(GuardianBrain.next("Return", far, TUNING)).toBe("Return")
	end)
end)

describe("GuardianBrain.canCatch", function()
	it("catches only while chasing and close enough", function()
		expect(GuardianBrain.canCatch("Chase", 5, TUNING)).toBe(true)
		expect(GuardianBrain.canCatch("Chase", 7, TUNING)).toBe(false)
		expect(GuardianBrain.canCatch("Return", 1, TUNING)).toBe(false)
	end)
end)
