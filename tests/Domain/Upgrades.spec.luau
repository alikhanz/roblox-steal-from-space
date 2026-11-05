--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Test = require("../../lune/lib/Test")
local Upgrades = require("../../src/shared/Domain/Upgrades")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: Upgrades.Tuning = {
	trainerBaseRate = BigNum.fromNumber(0.3),
	trainerRateGrowth = BigNum.fromNumber(1.6),
	trainerCostBase = BigNum.fromNumber(300),
	trainerCostGrowth = BigNum.fromNumber(5),
	jetpackGrowth = 2,
	jetpackMarks = { 1, 1.5 },
	jetpackCostBase = BigNum.fromNumber(2000),
	jetpackCostPerDoubling = 10,
	jetpackLast = 7,
}

local function number(value: BigNum.BigNum): number
	return BigNum.toNumber(value)
end

describe("Upgrades.trainerRate", function()
	it("starts at the base rate and grows by the factor per level", function()
		expect(number(Upgrades.trainerRate(0, TUNING))).toBeCloseTo(0.3, 1e-9)
		expect(number(Upgrades.trainerRate(1, TUNING))).toBeCloseTo(0.48, 1e-9)
		expect(number(Upgrades.trainerRate(3, TUNING))).toBeCloseTo(0.3 * 1.6 ^ 3, 1e-9)
	end)

	it("rejects levels that are not whole numbers", function()
		expect(function()
			Upgrades.trainerRate(-1, TUNING)
		end).toThrow("whole number")
		expect(function()
			Upgrades.trainerRate(1.5, TUNING)
		end).toThrow("whole number")
	end)
end)

describe("Upgrades jetpack models", function()
	it("puts levels into jetpacks of two marks after the starting one", function()
		local jetpack, mark = Upgrades.jetpackModel(0, TUNING)
		expect(jetpack).toBe(0)
		expect(mark).toBe(1)
		jetpack, mark = Upgrades.jetpackModel(1, TUNING)
		expect(jetpack).toBe(1)
		expect(mark).toBe(1)
		jetpack, mark = Upgrades.jetpackModel(4, TUNING)
		expect(jetpack).toBe(2)
		expect(mark).toBe(2)
	end)

	it("tops out at the last jetpack's first mark", function()
		expect(Upgrades.jetpackMaxLevel(TUNING)).toBe(13)
		local jetpack, mark = Upgrades.jetpackModel(13, TUNING)
		expect(jetpack).toBe(7)
		expect(mark).toBe(1)
	end)

	it("multiplies x2, x3, x4, x6, x8, x12... up to x128", function()
		local expected = { 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128 }
		for level, multiplier in expected do
			expect(number(Upgrades.jetpackMultiplier(level - 1, TUNING))).toBeCloseTo(multiplier, 1e-9)
		end
		-- A saved level past the top counts as the top.
		expect(number(Upgrades.jetpackMultiplier(20, TUNING))).toBeCloseTo(128, 1e-9)
	end)
end)

describe("Upgrades prices", function()
	it("cost the base for the first level and the growth times more for each next", function()
		expect(number(Upgrades.trainerPrice(0, TUNING))).toBe(300)
		expect(number(Upgrades.trainerPrice(2, TUNING))).toBe(7500)
	end)

	it("price a jetpack level by its multiplier: ten times more per doubling", function()
		-- x2 2000, x4 20K, x8 200K: as many coins per doubling as one level used to cost.
		expect(number(Upgrades.jetpackPrice(0, TUNING))).toBe(2000)
		expect(number(Upgrades.jetpackPrice(2, TUNING))).toBeCloseTo(20000, 1e-6)
		expect(number(Upgrades.jetpackPrice(4, TUNING))).toBeCloseTo(200000, 1e-3)
		-- x3 in between, rounded to two digits: 2000 * 10^log2(1.5) = 7692.
		expect(number(Upgrades.jetpackPrice(1, TUNING))).toBeCloseTo(7700, 1e-6)
	end)

	it("has nothing to sell at the top", function()
		expect(function()
			Upgrades.jetpackPrice(13, TUNING)
		end).toThrow("top")
	end)
end)

describe("Upgrades.speed", function()
	it("multiplies the trained speed by the jetpack", function()
		local trained = BigNum.fromNumber(10)
		expect(number(Upgrades.speed(trained, 0, TUNING))).toBe(10)
		expect(number(Upgrades.speed(trained, 4, TUNING))).toBeCloseTo(60, 1e-9)
	end)

	it("stays exact for huge stats", function()
		local trained = BigNum.new(1, 11)
		local speed = Upgrades.speed(trained, 13, TUNING)
		expect(number(speed) / 1e11).toBeCloseTo(128, 1e-6)
		expect(BigNum.format(speed)).toBe("12.8T")
	end)
end)

describe("Upgrades.trainingGain", function()
	it("pays the rate for the time, scaled by the factor", function()
		local rate = BigNum.fromNumber(0.5)
		expect(number(Upgrades.trainingGain(rate, 10, 1))).toBeCloseTo(5, 1e-9)
		expect(number(Upgrades.trainingGain(rate, 3600, 0.5))).toBeCloseTo(900, 1e-9)
		expect(BigNum.isZero(Upgrades.trainingGain(rate, 0, 1))).toBe(true)
	end)

	it("rejects negative time or factor", function()
		expect(function()
			Upgrades.trainingGain(BigNum.ONE, -1, 1)
		end).toThrow("seconds")
		expect(function()
			Upgrades.trainingGain(BigNum.ONE, 1, -1)
		end).toThrow("factor")
	end)
end)
