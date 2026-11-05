--!strict

local MeteorShower = require("../../src/shared/Domain/MeteorShower")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: MeteorShower.Tuning = { EGGS_PER_PLAYER = 2, MIN_EGGS = 4, MAX_EGGS = 16, FALL_STEP_SECONDS = 3 }

describe("MeteorShower.eggCount", function()
	it("grows with the players within the bounds", function()
		expect(MeteorShower.eggCount(1, TUNING)).toBe(4)
		expect(MeteorShower.eggCount(3, TUNING)).toBe(6)
		expect(MeteorShower.eggCount(8, TUNING)).toBe(16)
		expect(MeteorShower.eggCount(30, TUNING)).toBe(16)
	end)
end)

describe("MeteorShower.fallTimes", function()
	it("drops one meteor a step, the first a step after the start", function()
		local times = MeteorShower.fallTimes(4, TUNING)
		expect(#times).toBe(4)
		expect(times[1]).toBe(3)
		expect(times[2]).toBe(6)
		expect(times[4]).toBe(12)
	end)

	it("keeps the same step however many meteors fall", function()
		local times = MeteorShower.fallTimes(16, TUNING)
		expect(times[16]).toBe(48)
	end)
end)

describe("MeteorShower.zones", function()
	it("shares the meteors out among the zones from the station outwards", function()
		local zones = MeteorShower.zones(6, { "A", "B", "C", "D" })
		expect(zones).toEqual({ "A", "B", "C", "D", "A", "B" })
	end)
end)
