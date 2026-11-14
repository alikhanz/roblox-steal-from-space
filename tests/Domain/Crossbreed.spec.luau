--!strict

local Crossbreed = require("../../src/shared/Domain/Crossbreed")
local Loot = require("../../src/shared/Domain/Loot")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

describe("Crossbreed.check", function()
	local function usual(grade: number, tier: string?): Crossbreed.Parent
		return { grade = grade, tier = tier or "Common", variant = "Normal" }
	end
	local function meteor(grade: number): Crossbreed.Parent
		return { grade = grade, tier = "Common", variant = "Meteor" }
	end

	it("accepts the required number of aliens of one grade, tier and variant", function()
		expect(Crossbreed.check({ usual(2), usual(2), usual(2) }, 3)).toBeNil()
		expect(Crossbreed.check({ usual(2, "Epic"), usual(2, "Epic"), usual(2, "Epic") }, 3)).toBeNil()
		expect(Crossbreed.check({ meteor(4), meteor(4), meteor(4) }, 3)).toBeNil()
	end)

	it("rejects the wrong count", function()
		expect(Crossbreed.check({ usual(1), usual(1) }, 3)).toBe("WrongCount")
		expect(Crossbreed.check({}, 3)).toBe("WrongCount")
	end)

	it("rejects mixed grades", function()
		expect(Crossbreed.check({ usual(1), usual(1), usual(2) }, 3)).toBe("MixedGrades")
	end)

	it("rejects mixed tiers of one grade", function()
		expect(Crossbreed.check({ usual(1), usual(1, "Rare"), usual(1) }, 3)).toBe("MixedTiers")
	end)

	it("rejects mixed variants of one grade", function()
		expect(Crossbreed.check({ usual(3), meteor(3), usual(3) }, 3)).toBe("MixedVariants")
	end)
end)

describe("Crossbreed.mismatch", function()
	it("names the first difference: grade, then tier, then variant", function()
		local function parent(grade: number, tier: string, variant: string): Crossbreed.Parent
			return { grade = grade, tier = tier, variant = variant }
		end
		expect(Crossbreed.mismatch(parent(1, "Rare", "Normal"), parent(1, "Rare", "Normal"))).toBeNil()
		expect(Crossbreed.mismatch(parent(1, "Rare", "Normal"), parent(2, "Epic", "Meteor"))).toBe("MixedGrades")
		expect(Crossbreed.mismatch(parent(2, "Rare", "Normal"), parent(2, "Epic", "Meteor"))).toBe("MixedTiers")
		expect(Crossbreed.mismatch(parent(2, "Rare", "Normal"), parent(2, "Rare", "Meteor"))).toBe("MixedVariants")
	end)
end)

describe("Crossbreed.resultEntries", function()
	it("gives the parents' tier or one up, by the chance", function()
		local chances = Loot.chances(Crossbreed.resultEntries(TIERS, 1, 0.43))
		expect(chances.Common).toBeCloseTo(0.57, 1e-9)
		expect(chances.Uncommon).toBeCloseTo(0.43, 1e-9)
		expect(chances.Rare).toBeNil()
	end)

	it("never goes down", function()
		local entries = Crossbreed.resultEntries(TIERS, 4, 0.27)
		expect(#entries).toBe(2)
		expect(entries[1].id).toBe("Epic")
		expect(entries[2].id).toBe("Legendary")
	end)

	it("gives the top tier from the top tier", function()
		expect(Crossbreed.resultEntries(TIERS, 5, 0.5)).toEqual({ { id = "Legendary", weight = 1 } })
		expect(Crossbreed.resultEntries(TIERS, 5, 0)).toEqual({ { id = "Legendary", weight = 1 } })
	end)

	it("rejects positions out of range", function()
		expect(function()
			Crossbreed.resultEntries(TIERS, 0, 0.5)
		end).toThrow("out of range")
		expect(function()
			Crossbreed.resultEntries(TIERS, 6, 0.5)
		end).toThrow("out of range")
	end)
end)

describe("Crossbreed.resultKind", function()
	it("gives the kind of one of the parents, each parent as likely", function()
		local kinds = { "crabDrone", "droneRay", "crabDrone" }
		expect(Crossbreed.resultKind(kinds, 0)).toBe("crabDrone")
		expect(Crossbreed.resultKind(kinds, 0.4)).toBe("droneRay")
		expect(Crossbreed.resultKind(kinds, 0.99)).toBe("crabDrone")
	end)

	it("needs a parent", function()
		expect(function()
			Crossbreed.resultKind({}, 0.5)
		end).toThrow("at least one parent")
	end)
end)

describe("Crossbreed.trios", function()
	-- "<grade>.<tier>.<variant>.<income>"
	local function parentOf(id: string): Crossbreed.Parent?
		local grade, tier, variant = string.match(id, "^(%d+)%.(%a+)%.(%a+)%.")
		return if grade
				and tier
				and variant
			then { grade = tonumber(grade) :: number, tier = tier, variant = variant }
			else nil
	end
	-- The income in the id, times the alien's roll.
	local function incomeOf(alien: { read id: string, read incomePercent: number }): number
		return (tonumber(string.match(alien.id, "(%d+)$")) :: number) * alien.incomePercent / 100
	end
	local function owned(uid: number, id: string, incomePercent: number?): PlayerData.AlienRecord
		return { uid = uid, id = id, incomePercent = incomePercent or 100 }
	end

	it("finds groups of one grade, tier and variant, with their weakest three", function()
		local trios = Crossbreed.trios({
			owned(1, "1.Common.Normal.5"),
			owned(2, "1.Common.Normal.1"),
			owned(3, "1.Common.Normal.9"),
			owned(4, "1.Common.Normal.1"),
			owned(5, "1.Common.Meteor.2"),
			owned(6, "2.Common.Normal.3"),
		}, parentOf, incomeOf, 3)
		expect(#trios).toBe(1)
		expect(trios[1].grade).toBe(1)
		expect(trios[1].tier).toBe("Common")
		expect(trios[1].variant).toBe("Normal")
		expect(trios[1].count).toBe(4)
		expect(trios[1].uids).toEqual({ 2, 4, 1 })
	end)

	it("offers the unluckiest rolls first (decision 130)", function()
		local trios = Crossbreed.trios({
			owned(1, "1.Common.Normal.10", 130),
			owned(2, "1.Common.Normal.10", 70),
			owned(3, "1.Common.Normal.10", 100),
			owned(4, "1.Common.Normal.10", 85),
		}, parentOf, incomeOf, 3)
		expect(trios[1].uids).toEqual({ 2, 4, 3 })
	end)

	it("keeps tiers apart", function()
		local trios = Crossbreed.trios({
			owned(1, "1.Common.Normal.1"),
			owned(2, "1.Common.Normal.1"),
			owned(3, "1.Rare.Normal.5"),
			owned(4, "1.Rare.Normal.5"),
		}, parentOf, incomeOf, 3)
		expect(#trios).toBe(0)
	end)

	it("keeps variants apart and puts the best group first", function()
		local trios = Crossbreed.trios({
			owned(1, "1.Common.Normal.1"),
			owned(2, "1.Common.Normal.1"),
			owned(3, "1.Common.Normal.1"),
			owned(4, "3.Rare.Meteor.40"),
			owned(5, "3.Rare.Meteor.40"),
			owned(6, "3.Rare.Meteor.40"),
			owned(7, "unknown"),
		}, parentOf, incomeOf, 3)
		expect(#trios).toBe(2)
		expect(trios[1].variant).toBe("Meteor")
		expect(trios[1].tier).toBe("Rare")
		expect(trios[1].uids).toEqual({ 4, 5, 6 })
		expect(trios[2].uids).toEqual({ 1, 2, 3 })
	end)

	it("finds nothing with fewer than three of a kind", function()
		expect(
			#Crossbreed.trios({ owned(1, "1.Common.Normal.1"), owned(2, "1.Common.Normal.1") }, parentOf, incomeOf, 3)
		).toBe(0)
	end)
end)
