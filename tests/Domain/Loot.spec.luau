--!strict

local Loot = require("../../src/shared/Domain/Loot")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TABLE: { Loot.Entry<string> } = {
	{ id = "Common", weight = 70 },
	{ id = "Uncommon", weight = 25 },
	{ id = "Rare", weight = 5 },
}

describe("Loot.pick", function()
	it("maps the roll onto cumulative weights", function()
		expect(Loot.pick(TABLE, 0)).toBe("Common")
		expect(Loot.pick(TABLE, 0.69)).toBe("Common")
		expect(Loot.pick(TABLE, 0.70)).toBe("Uncommon")
		expect(Loot.pick(TABLE, 0.94)).toBe("Uncommon")
		expect(Loot.pick(TABLE, 0.95)).toBe("Rare")
		expect(Loot.pick(TABLE, 0.999)).toBe("Rare")
	end)

	it("handles a roll of exactly 1", function()
		expect(Loot.pick(TABLE, 1)).toBe("Rare")
	end)

	it("never picks zero-weight entries", function()
		local entries: { Loot.Entry<string> } = {
			{ id = "Never", weight = 0 },
			{ id = "Always", weight = 1 },
			{ id = "AlsoNever", weight = 0 },
		}
		for _, roll in { 0, 0.5, 1 } do
			expect(Loot.pick(entries, roll)).toBe("Always")
		end
	end)

	it("rejects empty or weightless tables", function()
		expect(function()
			Loot.pick({}, 0.5)
		end).toThrow("at least one entry")
		expect(function()
			Loot.pick({ { id = "A", weight = 0 } }, 0.5)
		end).toThrow("positive total weight")
	end)
end)

describe("Loot.chances", function()
	it("normalizes weights", function()
		local chances = Loot.chances(TABLE)
		expect(chances.Common).toBeCloseTo(0.7)
		expect(chances.Rare).toBeCloseTo(0.05)
	end)
end)

describe("Loot.capped", function()
	local LADDER: { Loot.Entry<string> } = {
		{ id = "Common", weight = 30 },
		{ id = "Uncommon", weight = 35 },
		{ id = "Rare", weight = 26 },
		{ id = "Epic", weight = 7.5 },
		{ id = "Legendary", weight = 1.5 },
	}

	it("folds everything above the cap into it", function()
		local capped = Loot.capped(LADDER, "Rare")
		expect(#capped).toBe(3)
		expect(capped[3]).toEqual({ id = "Rare", weight = 35 })
		local chances = Loot.chances(capped)
		expect(chances.Common).toBeCloseTo(0.3, 1e-9)
		expect(chances.Rare).toBeCloseTo(0.35, 1e-9)
		expect(chances.Epic).toBeNil()
		expect(chances.Legendary).toBeNil()
	end)

	it("never picks above the cap, whatever the roll", function()
		local capped = Loot.capped(LADDER, "Rare")
		for roll = 0, 1, 0.01 do
			local picked = Loot.pick(capped, roll)
			expect(picked == "Epic" or picked == "Legendary").toBe(false)
		end
	end)

	it("leaves a table with nothing above the cap as it was", function()
		expect(Loot.capped(LADDER, "Legendary")).toEqual(LADDER :: any)
		local near: { Loot.Entry<string> } =
			{ { id = "Common", weight = 72 }, { id = "Uncommon", weight = 23 }, { id = "Rare", weight = 5 } }
		expect(Loot.capped(near, "Rare")).toEqual(near :: any)
		expect(Loot.capped(near, "Epic")).toEqual(near :: any)
	end)
end)
