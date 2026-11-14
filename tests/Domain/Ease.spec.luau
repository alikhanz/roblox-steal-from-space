--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Ease = require("../../src/shared/Domain/Ease")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function n(value: number): BigNum.BigNum
	return BigNum.fromNumber(value)
end

describe("Ease.towards", function()
	it("walks evenly from the old value to the new one over the time", function()
		expect(BigNum.toNumber(Ease.towards(n(100), n(200), 0, 1))).toBe(100)
		expect(BigNum.toNumber(Ease.towards(n(100), n(200), 0.25, 1))).toBeCloseTo(125, 1e-9)
		expect(BigNum.toNumber(Ease.towards(n(100), n(200), 0.5, 1))).toBeCloseTo(150, 1e-9)
		expect(BigNum.toNumber(Ease.towards(n(100), n(200), 1, 1))).toBe(200)
		expect(BigNum.toNumber(Ease.towards(n(100), n(200), 3, 1))).toBe(200)
	end)

	it("shows a drop at once", function()
		expect(BigNum.toNumber(Ease.towards(n(200), n(100), 0.5, 1))).toBe(100)
	end)

	it("works on numbers far past a double's digits", function()
		local from, to = BigNum.new(1, 30), BigNum.new(3, 30)
		expect(BigNum.log10(Ease.towards(from, to, 0.5, 1))).toBeCloseTo(BigNum.log10(BigNum.new(2, 30)), 1e-9)
	end)
end)
