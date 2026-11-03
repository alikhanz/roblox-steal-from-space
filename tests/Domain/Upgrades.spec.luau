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
	jetpackMultiplier = BigNum.fromNumber(2),
	jetpackCostBase = BigNum.fromNumber(2000),
	jetpackCostGrowth = BigNum.fromNumber(8),
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

describe("Upgrades prices", function()
	it("cost the base for the first level and the growth times more for each next", function()
		expect(number(Upgrades.trainerPrice(0, TUNING))).toBe(300)
		expect(number(Upgrades.trainerPrice(2, TUNING))).toBe(7500)
		expect(number(Upgrades.jetpackPrice(0, TUNING))).toBe(2000)
		expect(number(Upgrades.jetpackPrice(1, TUNING))).toBe(16000)
	end)
end)

describe("Upgrades.speed", function()
	it("doubles the trained speed per jetpack level", function()
		local trained = BigNum.fromNumber(10)
		expect(number(Upgrades.jetpackMultiplier(0, TUNING))).toBe(1)
		expect(number(Upgrades.speed(trained, 0, TUNING))).toBe(10)
		expect(number(Upgrades.speed(trained, 3, TUNING))).toBe(80)
	end)

	it("stays exact for huge stats", function()
		local trained = BigNum.new(1, 11)
		local speed = Upgrades.speed(trained, 10, TUNING)
		expect(number(speed) / 1e11).toBeCloseTo(1024, 1e-6)
		expect(BigNum.format(speed)).toBe("102T")
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
