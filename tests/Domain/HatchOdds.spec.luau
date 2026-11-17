--!strict

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local EggConfig = require("../../src/shared/Config/EggConfig")
local HatchOdds = require("../../src/shared/Domain/HatchOdds")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function drawOf(egg: HatchOdds.Egg): HatchOdds.Draw
	return assert(HatchOdds.of(egg), "the egg can hatch")
end

local function sum(list: { HatchOdds.TierOdds }): number
	local total = 0
	for _, tier in list do
		for _, outcome in tier.outcomes do
			total += outcome.chance
		end
	end
	return total
end

describe("HatchOdds.of", function()
	it("knows nothing of an egg this build cannot hatch", function()
		expect(HatchOdds.of({ grade = 999, rarity = "Rare", size = "Medium" })).toBeNil()
		expect(HatchOdds.of({ grade = 1, rarity = "Mythic", size = "Medium" })).toBeNil()
		expect(HatchOdds.of({ grade = 1, rarity = "Rare", size = "Huge" })).toBeNil()
		expect(HatchOdds.of({ grade = 1, rarity = "Rare", size = "Medium", variant = "Golden" })).toBeNil()
	end)

	it("hatches a lucky egg by the odds of a large one", function()
		local lucky = drawOf({ grade = 1, rarity = "Rare", size = "Small", luck = 1 })
		local large = drawOf({ grade = 1, rarity = "Rare", size = "Large" })
		expect(lucky.tiers).toBe(large.tiers)
	end)
end)

describe("HatchOdds.list", function()
	it("lists every kind of every tier of a rare egg, the tier's chance shared evenly", function()
		local list = HatchOdds.list(drawOf({ grade = 1, rarity = "Rare", size = "Medium" }))
		expect(#list).toBe(3)
		expect(list[1].tier).toBe("Uncommon")
		expect(list[2].tier).toBe("Rare")
		expect(list[3].tier).toBe("Epic")
		expect(list[2].chance).toBeCloseTo(0.65, 1e-9)
		local grade = AlienConfig.GRADES[1]
		expect(#list[2].outcomes).toBe(#grade.kinds)
		for index, outcome in list[2].outcomes do
			expect(outcome.kind).toBe(grade.kinds[index])
			expect(outcome.alien).toBe(grade.variants.Normal[outcome.kind].Rare)
			expect(outcome.chance).toBeCloseTo(0.65 / #grade.kinds, 1e-12)
		end
	end)

	it("adds up to exactly one for every egg the game has", function()
		for grade in AlienConfig.GRADES do
			for _, variant in AlienConfig.VARIANT_ORDER do
				for _, rarity in EggConfig.RARITY_ORDER do
					for size in EggConfig.SIZES do
						for _, luck in { 0, 1 } do
							local list = HatchOdds.list(drawOf({
								grade = grade,
								rarity = rarity,
								size = size,
								variant = variant,
								luck = luck,
							}))
							expect(sum(list)).toBeCloseTo(1, 1e-9)
						end
					end
				end
			end
		end
	end)

	it("lists only meteor aliens for a meteor egg", function()
		local list = HatchOdds.list(drawOf({ grade = 5, rarity = "Epic", size = "Large", variant = "Meteor" }))
		for _, tier in list do
			for _, outcome in tier.outcomes do
				local alien = assert(AlienConfig.ALIENS[outcome.alien], "a known alien")
				expect(alien.variant).toBe("Meteor")
				expect(alien.tier).toBe(outcome.tier)
				expect(alien.grade).toBe(5)
			end
		end
	end)

	it("matches what the hatch picks, roll by roll", function()
		local draw = drawOf({ grade = 3, rarity = "Uncommon", size = "Small" })
		local expected: { [string]: number } = {}
		for _, tier in HatchOdds.list(draw) do
			for _, outcome in tier.outcomes do
				expected[outcome.alien] = outcome.chance
			end
		end
		-- An even grid of both rolls: each alien turns up as often as its listed chance.
		local kindSteps, tierSteps = 300, 400
		local counts: { [string]: number } = {}
		for kindStep = 0, kindSteps - 1 do
			for tierStep = 0, tierSteps - 1 do
				local alien = HatchOdds.pick(draw, (kindStep + 0.5) / kindSteps, (tierStep + 0.5) / tierSteps)
				expect(expected[alien]).toBeTruthy()
				counts[alien] = (counts[alien] or 0) + 1
			end
		end
		for alien, chance in expected do
			expect((counts[alien] or 0) / (kindSteps * tierSteps)).toBeCloseTo(chance, 1e-9)
		end
	end)
end)

describe("HatchOdds.income", function()
	it("tells every whole percent of the roll as equally likely", function()
		local income = HatchOdds.income()
		expect(income.min).toBe(AlienConfig.INCOME_ROLL.min)
		expect(income.max).toBe(AlienConfig.INCOME_ROLL.max)
		expect(income.chance * (income.max - income.min + 1)).toBeCloseTo(1, 1e-12)
	end)
end)

describe("HatchOdds.percentText", function()
	local function check(chance: number, text: string, rounded: boolean)
		local shown, wasRounded = HatchOdds.percentText(chance)
		expect(shown).toBe(text)
		expect(wasRounded).toBe(rounded)
	end

	it("shows exact chances as they are", function()
		check(0.2, "20", false)
		check(0.625, "62.5", false)
		check(0.05, "5", false)
		check(1, "100", false)
		check(0.075 / 3, "2.5", false)
	end)

	it("rounds the rest to four places below the first digit", function()
		check(0.65 / 3, "21.667", true)
		check(0.2 / 3, "6.6667", true)
		check(1 / 61, "1.6393", true)
		check(0.25 / 3, "8.3333", true)
		check(1 / 3, "33.333", true)
		check(0.00001 / 3, "0.00033333", true)
	end)

	it("refuses a chance out of range", function()
		expect(function()
			HatchOdds.percentText(0)
		end).toThrow("chance")
	end)
end)
