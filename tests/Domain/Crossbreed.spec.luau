--!strict

local Crossbreed = require("../../src/shared/Domain/Crossbreed")
local Loot = require("../../src/shared/Domain/Loot")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TIERS: { Loot.Entry<string> } = {
	{ id = "Common", weight = 55 },
	{ id = "Uncommon", weight = 28 },
	{ id = "Rare", weight = 12 },
	{ id = "Epic", weight = 4 },
	{ id = "Legendary", weight = 1 },
}

describe("Crossbreed.check", function()
	local function usual(grade: number): Crossbreed.Parent
		return { grade = grade, variant = "Normal" }
	end
	local function meteor(grade: number): Crossbreed.Parent
		return { grade = grade, variant = "Meteor" }
	end

	it("accepts the required number of aliens of one grade and variant", function()
		expect(Crossbreed.check({ usual(2), usual(2), usual(2) }, 3)).toBeNil()
		expect(Crossbreed.check({ meteor(4), meteor(4), meteor(4) }, 3)).toBeNil()
	end)

	it("rejects the wrong count", function()
		expect(Crossbreed.check({ usual(1), usual(1) }, 3)).toBe("WrongCount")
		expect(Crossbreed.check({}, 3)).toBe("WrongCount")
	end)

	it("rejects mixed grades", function()
		expect(Crossbreed.check({ usual(1), usual(1), usual(2) }, 3)).toBe("MixedGrades")
	end)

	it("rejects mixed variants of one grade", function()
		expect(Crossbreed.check({ usual(3), meteor(3), usual(3) }, 3)).toBe("MixedVariants")
	end)
end)

describe("Crossbreed.mismatch", function()
	it("names the first difference, grade before variant", function()
		expect(Crossbreed.mismatch({ grade = 1, variant = "Normal" }, { grade = 1, variant = "Normal" })).toBeNil()
		expect(Crossbreed.mismatch({ grade = 1, variant = "Normal" }, { grade = 2, variant = "Meteor" })).toBe(
			"MixedGrades"
		)
		expect(Crossbreed.mismatch({ grade = 2, variant = "Normal" }, { grade = 2, variant = "Meteor" })).toBe(
			"MixedVariants"
		)
	end)
end)

describe("Crossbreed.resultEntries", function()
	it("never goes below the lowest tier put in", function()
		local entries = Crossbreed.resultEntries(TIERS, { 3, 5, 4 }, 0)
		expect(#entries).toBe(3)
		expect(entries[1].id).toBe("Rare")
		expect(entries[3].id).toBe("Legendary")
	end)

	it("tilts the odds up from there", function()
		local chances = Loot.chances(Crossbreed.resultEntries(TIERS, { 1, 1, 1 }, 0.5))
		-- 55 : 42 : 27 : 13.5 : 5.0625
		expect(chances.Common).toBeCloseTo(55 / 142.5625, 1e-9)
		expect(chances.Legendary).toBeCloseTo(5.0625 / 142.5625, 1e-9)
	end)

	it("keeps the top tier reachable from the top tier", function()
		local entries = Crossbreed.resultEntries(TIERS, { 5, 5, 5 }, 0.5)
		expect(entries).toEqual({ { id = "Legendary", weight = 1 } })
	end)

	it("rejects positions out of range", function()
		expect(function()
			Crossbreed.resultEntries(TIERS, {}, 0.5)
		end).toThrow()
		expect(function()
			Crossbreed.resultEntries(TIERS, { 0 }, 0.5)
		end).toThrow("out of range")
	end)
end)
