--!strict

local GuardianBrain = require("../../src/shared/Domain/GuardianBrain")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: GuardianBrain.Tuning = {
	aggroDelaySeconds = 1,
	homeRadius = 3,
	catchRadius = 6,
}

local function situation(overrides: { [string]: any }): GuardianBrain.Situation
	local base: { [string]: any } = {
		hasTarget = false,
		stolenSeconds = 0,
		targetSafe = false,
		distanceToHome = 0,
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

	it("stays asleep if the thief is already inside the station border", function()
		local safe = situation({ hasTarget = true, stolenSeconds = 2, targetSafe = true })
		expect(GuardianBrain.next("Sleep", safe, TUNING)).toBe("Sleep")
	end)

	it("keeps chasing however far and long the thief flies", function()
		local chasing = situation({ hasTarget = true, stolenSeconds = 120, distanceToHome = 5000 })
		expect(GuardianBrain.next("Chase", chasing, TUNING)).toBe("Chase")
	end)

	it("gives up only when the thief is lost or inside the station border", function()
		local lost = situation({ hasTarget = false })
		expect(GuardianBrain.next("Chase", lost, TUNING)).toBe("Return")
		local safe = situation({ hasTarget = true, stolenSeconds = 5, targetSafe = true })
		expect(GuardianBrain.next("Chase", safe, TUNING)).toBe("Return")
	end)

	it("goes back to sleep once home", function()
		expect(GuardianBrain.next("Return", situation({ distanceToHome = 50 }), TUNING)).toBe("Return")
		expect(GuardianBrain.next("Return", situation({ distanceToHome = 2 }), TUNING)).toBe("Sleep")
	end)

	it("turns around on the way home once its egg is out in space again", function()
		local thief = situation({ hasTarget = true, stolenSeconds = 1, distanceToHome = 50 })
		expect(GuardianBrain.next("Return", thief, TUNING)).toBe("Chase")
		local justTaken = situation({ hasTarget = true, stolenSeconds = 0.5, distanceToHome = 50 })
		expect(GuardianBrain.next("Return", justTaken, TUNING)).toBe("Return")
		local stillSafe = situation({ hasTarget = true, stolenSeconds = 5, distanceToHome = 50, targetSafe = true })
		expect(GuardianBrain.next("Return", stillSafe, TUNING)).toBe("Return")
	end)
end)

describe("GuardianBrain.canCatch", function()
	it("catches only while chasing and close enough", function()
		expect(GuardianBrain.canCatch("Chase", 5, TUNING)).toBe(true)
		expect(GuardianBrain.canCatch("Chase", 7, TUNING)).toBe(false)
		expect(GuardianBrain.canCatch("Return", 1, TUNING)).toBe(false)
	end)
end)

describe("GuardianBrain.pickTarget", function()
	local function thief(who: string, distance: number, safe: boolean?): GuardianBrain.Candidate<string>
		return { who = who, distance = distance, safe = safe == true }
	end

	it("has nobody to chase without thieves", function()
		expect(GuardianBrain.pickTarget(nil, {})).toBeNil()
		expect(GuardianBrain.pickTarget("A", {})).toBeNil()
	end)

	it("goes after the nearest thief in reach", function()
		expect(GuardianBrain.pickTarget(nil, { thief("A", 50), thief("B", 20) })).toBe("B")
		expect(GuardianBrain.pickTarget(nil, { thief("A", 50), thief("B", 20, true) })).toBe("A")
	end)

	it("keeps after the same thief while they are in reach, however near another one gets", function()
		expect(GuardianBrain.pickTarget("A", { thief("A", 80), thief("B", 5) })).toBe("A")
	end)

	it("turns to another thief once the chased one is safe or gone", function()
		expect(GuardianBrain.pickTarget("A", { thief("A", 5, true), thief("B", 80) })).toBe("B")
		expect(GuardianBrain.pickTarget("A", { thief("B", 80) })).toBe("B")
	end)

	it("names a safe thief when every one is safe, so the guardian heads home", function()
		expect(GuardianBrain.pickTarget(nil, { thief("A", 30, true), thief("B", 10, true) })).toBe("B")
	end)
end)
