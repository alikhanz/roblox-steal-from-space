--!strict

local GuardianBrain = require("../../src/shared/Domain/GuardianBrain")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: GuardianBrain.Tuning = {
	leashRadius = 200,
	maxChaseSeconds = 20,
	homeRadius = 3,
	catchRadius = 6,
}

local function situation(overrides: { [string]: any }): GuardianBrain.Situation
	local base: { [string]: any } = {
		alertAwake = false,
		hasTarget = false,
		targetInStation = false,
		targetDistanceFromNest = 0,
		distanceToNest = 0,
		chaseSeconds = 0,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

describe("GuardianBrain.next", function()
	it("sleeps until the alert is full and a thief is near", function()
		expect(GuardianBrain.next("Sleep", situation({ alertAwake = false, hasTarget = true }), TUNING)).toBe("Sleep")
		expect(GuardianBrain.next("Sleep", situation({ alertAwake = true, hasTarget = false }), TUNING)).toBe("Sleep")
		expect(GuardianBrain.next("Sleep", situation({ alertAwake = true, hasTarget = true }), TUNING)).toBe("Chase")
	end)

	it("keeps chasing a thief in range", function()
		local chasing = situation({ hasTarget = true, targetDistanceFromNest = 150, chaseSeconds = 10 })
		expect(GuardianBrain.next("Chase", chasing, TUNING)).toBe("Chase")
	end)

	it("gives up when the thief is lost, safe, too far or chased too long", function()
		local cases = {
			situation({ hasTarget = false }),
			situation({ hasTarget = true, targetInStation = true }),
			situation({ hasTarget = true, targetDistanceFromNest = 201 }),
			situation({ hasTarget = true, chaseSeconds = 21 }),
		}
		for _, case in cases do
			expect(GuardianBrain.next("Chase", case, TUNING)).toBe("Return")
		end
	end)

	it("goes back to sleep once home", function()
		expect(GuardianBrain.next("Return", situation({ distanceToNest = 50 }), TUNING)).toBe("Return")
		expect(GuardianBrain.next("Return", situation({ distanceToNest = 2 }), TUNING)).toBe("Sleep")
	end)

	it("does not wake again on the way home", function()
		local noisy = situation({ alertAwake = true, hasTarget = true, distanceToNest = 50 })
		expect(GuardianBrain.next("Return", noisy, TUNING)).toBe("Return")
	end)
end)

describe("GuardianBrain.canCatch", function()
	it("catches only while chasing and close enough", function()
		expect(GuardianBrain.canCatch("Chase", 5, TUNING)).toBe(true)
		expect(GuardianBrain.canCatch("Chase", 7, TUNING)).toBe(false)
		expect(GuardianBrain.canCatch("Return", 1, TUNING)).toBe(false)
	end)
end)
