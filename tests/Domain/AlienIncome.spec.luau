--!strict

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local AlienIncome = require("../../src/shared/Domain/AlienIncome")
local AlienOutfit = require("../../src/shared/Domain/AlienOutfit")
local BayConfig = require("../../src/shared/Config/BayConfig")
local BigNum = require("../../src/shared/Domain/BigNum")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local COMMON = AlienConfig.GRADES[1].aliens.Common
local BASE = BigNum.toNumber(AlienConfig.ALIENS[COMMON].income)

describe("AlienIncome.roll", function()
	it("adds up its dice from min, so both ends come out", function()
		local roll = { min = 70, max = 130, dice = 2 }
		local lowest = AlienIncome.roll(roll, function(min: number, _max: number): number
			return min
		end)
		local highest = AlienIncome.roll(roll, function(_min: number, max: number): number
			return max
		end)
		expect(lowest).toBe(70)
		expect(highest).toBe(130)
	end)

	it("comes out evenly across the tuning (decision 133)", function()
		local nextInteger = AlienOutfit.sequence(11)
		local low, high, lucky, total = 0, 0, 0, 0
		local draws = 6100
		for _ = 1, draws do
			local percent = AlienIncome.draw(nextInteger)
			expect(percent >= 70 and percent <= 130 and percent % 1 == 0).toBe(true)
			total += percent
			if percent < 100 then
				low += 1
			elseif percent > 100 then
				high += 1
			end
			if percent >= 125 then
				lucky += 1
			end
		end
		-- One die over 61 values: 30 of them below 100 and 30 above, 6 at 125 or more; mean 100.
		expect(math.abs(low - high) < draws * 0.05).toBe(true)
		expect(math.abs(lucky / draws - 6 / 61) < 0.03).toBe(true)
		expect(math.abs(total / draws - 100) < 1.5).toBe(true)
	end)

	it("comes out near the middle with two dice", function()
		local nextInteger = AlienOutfit.sequence(11)
		local middle = 0
		for _ = 1, 4000 do
			local percent = AlienIncome.roll({ min = 70, max = 130, dice = 2 }, nextInteger)
			if percent >= 90 and percent <= 110 then
				middle += 1
			end
		end
		expect(middle > 4000 * 0.5).toBe(true)
	end)

	it("refuses a span its dice cannot split evenly", function()
		expect(function()
			AlienIncome.roll({ min = 70, max = 131, dice = 2 }, AlienOutfit.sequence(1))
		end).toThrow()
	end)
end)

describe("AlienIncome.of", function()
	it("scales its kind's income by its roll", function()
		expect(BigNum.toNumber(AlienIncome.of({ id = COMMON, incomePercent = 100 }))).toBe(BASE)
		expect(BigNum.toNumber(AlienIncome.of({ id = COMMON, incomePercent = 130 }))).toBeCloseTo(BASE * 1.3, 1e-6)
		expect(BigNum.toNumber(AlienIncome.of({ id = COMMON, incomePercent = 70 }))).toBeCloseTo(BASE * 0.7, 1e-6)
		expect(AlienIncome.numberOf({ id = COMMON, incomePercent = 125 })).toBeCloseTo(BASE * 1.25, 1e-6)
	end)

	it("counts an alien with no roll as 100 and an unknown one as nothing", function()
		expect(BigNum.toNumber(AlienIncome.of({ id = COMMON }))).toBe(BASE)
		expect(BigNum.isZero(AlienIncome.of({ id = "Gone.alien.Common", incomePercent = 120 }))).toBe(true)
	end)

	it("sells for its own income's minutes", function()
		local price = AlienIncome.saleOf({ id = COMMON, incomePercent = 120 })
		expect(BigNum.toNumber(price)).toBeCloseTo(BASE * 1.2 * BayConfig.SELL_INCOME_SECONDS, 1e-6)
	end)
end)

describe("AlienIncome.bonusOf and fit", function()
	it("reads the roll as its distance from 100", function()
		expect(AlienIncome.bonusOf({ id = COMMON, incomePercent = 123 })).toBe(23)
		expect(AlienIncome.bonusOf({ id = COMMON, incomePercent = 92 })).toBe(-8)
		expect(AlienIncome.bonusOf({ id = COMMON })).toBe(0)
	end)

	it("fits a roll into the tuning", function()
		local roll = AlienConfig.INCOME_ROLL
		expect(AlienIncome.fit(roll.max + 40)).toBe(roll.max)
		expect(AlienIncome.fit(roll.min - 40)).toBe(roll.min)
		expect(AlienIncome.fit(101.4)).toBe(101)
	end)
end)
