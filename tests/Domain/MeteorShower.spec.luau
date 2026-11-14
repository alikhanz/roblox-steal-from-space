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

describe("MeteorShower.posts", function()
	it("gives each player a crater of their level and one post above", function()
		expect(MeteorShower.posts({ 3, 12 }, 4, 24)).toEqual({ 3, 12, 4, 13 })
	end)

	it("gives a lone player their level, one above and one below", function()
		expect(MeteorShower.posts({ 10 }, 4, 24)).toEqual({ 10, 11, 9, 10 })
	end)

	it("keeps the posts within the map", function()
		expect(MeteorShower.posts({ 1 }, 3, 24)).toEqual({ 1, 2, 1 })
		expect(MeteorShower.posts({ 24 }, 2, 24)).toEqual({ 24, 24 })
	end)

	it("drops nothing with nobody to steal", function()
		expect(MeteorShower.posts({}, 4, 24)).toEqual({})
	end)
end)
