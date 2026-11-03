--!strict

local Hatch = require("../../src/shared/Domain/Hatch")
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

describe("Hatch.duration", function()
	it("spans the range by the roll", function()
		local range: Hatch.Range = { min = 30, max = 600 }
		expect(Hatch.duration(range, 0)).toBe(30)
		expect(Hatch.duration(range, 1)).toBe(600)
		expect(Hatch.duration(range, 0.5)).toBe(315)
		expect(Hatch.duration(range, 2)).toBe(600)
	end)

	it("rejects a backwards range", function()
		expect(function()
			Hatch.duration({ min = 10, max = 5 }, 0.5)
		end).toThrow("range")
	end)
end)

describe("Hatch.shiftedWeights", function()
	it("leaves the odds alone without luck", function()
		expect(Hatch.shiftedWeights(TIERS, 0)).toEqual(TIERS)
	end)

	it("doubles each tier's weight relative to the one below with luck 1", function()
		local shifted = Hatch.shiftedWeights(TIERS, 1)
		expect(shifted[1].weight).toBeCloseTo(55)
		expect(shifted[2].weight).toBeCloseTo(56)
		expect(shifted[3].weight).toBeCloseTo(48)
		expect(shifted[4].weight).toBeCloseTo(32)
		expect(shifted[5].weight).toBeCloseTo(16)
	end)

	it("never rules the bottom tier out", function()
		local chances = Loot.chances(Hatch.shiftedWeights(TIERS, 3))
		expect(chances.Common > 0).toBe(true)
		expect(chances.Legendary > chances.Common).toBe(true)
	end)

	it("rejects negative luck", function()
		expect(function()
			Hatch.shiftedWeights(TIERS, -0.1)
		end).toThrow("luck")
	end)
end)

describe("Hatch.pick", function()
	it("picks by the shifted odds", function()
		expect(Hatch.pick(TIERS, 0, 0)).toBe("Common")
		expect(Hatch.pick(TIERS, 0, 0.999)).toBe("Legendary")
		-- With luck 1 the Legendary share is 16/207: a roll just under 1 - 16/207 is still Epic.
		expect(Hatch.pick(TIERS, 1, 1 - 16 / 207 - 0.001)).toBe("Epic")
		expect(Hatch.pick(TIERS, 1, 1 - 16 / 207 + 0.001)).toBe("Legendary")
	end)
end)
