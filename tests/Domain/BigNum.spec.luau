--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local n = BigNum.fromNumber

local function expectScientific(value: BigNum.BigNum, mantissa: number, exponent: number)
	expect(value.exponent).toBe(exponent)
	expect(value.mantissa).toBeCloseTo(mantissa, 1e-12)
end

describe("BigNum construction", function()
	it("keeps everyday values as exact plain doubles", function()
		local value = n(1234)
		expect(value.mantissa).toBe(1234)
		expect(value.exponent).toBe(0)
	end)

	it("switches to scientific form at 1e300", function()
		expectScientific(n(5e305), 5, 305)
		expectScientific(BigNum.new(2.5, 400), 2.5, 400)
	end)

	it("normalizes the mantissa", function()
		expectScientific(BigNum.new(250, 400), 2.5, 402)
		expectScientific(BigNum.new(0.25, 400), 2.5, 399)
	end)

	it("collapses small scientific input into a plain value", function()
		local value = BigNum.new(1.5, 3)
		expect(value.exponent).toBe(0)
		expect(value.mantissa).toBe(1500)
	end)

	it("rejects non-finite input", function()
		expect(function()
			n(0 / 0)
		end).toThrow("finite")
		expect(function()
			n(math.huge)
		end).toThrow("finite")
		expect(function()
			BigNum.new(1, 1.5)
		end).toThrow("integer exponent")
	end)

	it("produces immutable values", function()
		local value = n(10) :: any
		expect(function()
			value.mantissa = 20
		end).toThrow()
	end)
end)

describe("BigNum arithmetic", function()
	it("adds plain values exactly", function()
		local sum = BigNum.add(n(30), n(70))
		expect(sum.mantissa).toBe(100)
		expect(BigNum.equals(sum, n(100))).toBe(true)
	end)

	it("adds scientific values", function()
		expectScientific(BigNum.add(BigNum.new(5, 400), BigNum.new(5, 400)), 1, 401)
	end)

	it("ignores operands too small to matter", function()
		local big = BigNum.new(5, 500)
		expect(BigNum.add(big, n(1))).toBe(big)
		expect(BigNum.add(n(1), big)).toBe(big)
	end)

	it("subtracts down to zero", function()
		local value = BigNum.new(5, 400)
		expect(BigNum.isZero(BigNum.sub(value, value))).toBe(true)
		expect(BigNum.sub(n(7), n(7))).toBe(BigNum.ZERO)
	end)

	it("goes negative on subtraction", function()
		local result = BigNum.sub(n(3), n(10))
		expect(BigNum.isNegative(result)).toBe(true)
		expect(result.mantissa).toBe(-7)
	end)

	it("multiplies across the plain limit", function()
		expectScientific(BigNum.mul(n(1e200), n(1e200)), 1, 400)
	end)

	it("multiplies plain values exactly", function()
		expect(BigNum.mul(n(12), n(25)).mantissa).toBe(300)
		expect(BigNum.mul(n(5), BigNum.ZERO)).toBe(BigNum.ZERO)
	end)

	it("divides back into the plain range", function()
		local result = BigNum.div(BigNum.new(1, 400), BigNum.new(1, 300))
		expect(result.exponent).toBe(0)
		expect(result.mantissa / 1e100).toBeCloseTo(1, 1e-12)
	end)

	it("refuses division by zero", function()
		expect(function()
			BigNum.div(n(1), BigNum.ZERO)
		end).toThrow("division by zero")
	end)

	it("raises to a power", function()
		expect(BigNum.pow(n(2), 10).mantissa).toBe(1024)
		expectScientific(BigNum.pow(n(10), 400), 1, 400)
		expectScientific(BigNum.pow(BigNum.new(1, 300), 2), 1, 600)
		expect(BigNum.pow(n(5), 0)).toBe(BigNum.ONE)
		expect(BigNum.pow(BigNum.ZERO, 3)).toBe(BigNum.ZERO)
	end)

	it("keeps the sign of odd powers of negative numbers", function()
		expect(BigNum.pow(n(-2), 3).mantissa).toBe(-8)
		expect(BigNum.pow(n(-2), 2).mantissa).toBe(4)
		expect(function()
			BigNum.pow(n(-2), 0.5)
		end).toThrow("integer power")
	end)

	it("floors plain values only", function()
		expect(BigNum.floor(n(9.99)).mantissa).toBe(9)
		local big = BigNum.new(1.5, 400)
		expect(BigNum.floor(big)).toBe(big)
	end)
end)

describe("BigNum comparison", function()
	it("orders plain values", function()
		expect(BigNum.compare(n(1), n(2))).toBe(-1)
		expect(BigNum.compare(n(2), n(2))).toBe(0)
		expect(BigNum.compare(n(3), n(2))).toBe(1)
	end)

	it("puts scientific values above plain ones", function()
		expect(BigNum.lessThan(n(9e299), BigNum.new(1, 300))).toBe(true)
		expect(BigNum.lessThan(BigNum.new(-1, 300), n(-9e299))).toBe(true)
	end)

	it("orders by sign first", function()
		expect(BigNum.lessThan(BigNum.new(-5, 900), n(0))).toBe(true)
		expect(BigNum.lessThan(n(0), n(0.001))).toBe(true)
	end)

	it("orders scientific values by exponent, then mantissa", function()
		expect(BigNum.lessThan(BigNum.new(9, 400), BigNum.new(1, 401))).toBe(true)
		expect(BigNum.lessThan(BigNum.new(1, 400), BigNum.new(2, 400))).toBe(true)
	end)

	it("picks max and min", function()
		expect(BigNum.max(n(1), n(2)).mantissa).toBe(2)
		expect(BigNum.min(n(1), n(2)).mantissa).toBe(1)
		expect(BigNum.lessOrEqual(n(2), n(2))).toBe(true)
	end)
end)

describe("BigNum saved data", function()
	it("accepts valid saved shapes and returns a frozen copy", function()
		local saved = { mantissa = 1.5, exponent = 400 }
		local restored = BigNum.fromSaved(saved)
		expect(restored).toEqual(saved)
		expect(table.isfrozen(restored :: any)).toBe(true)
		expect(BigNum.fromSaved({ mantissa = 0, exponent = 0 })).toBe(BigNum.ZERO)
	end)

	it("rejects broken saved data", function()
		expect(BigNum.fromSaved(nil)).toBeNil()
		local broken: { any } = {
			42,
			"100",
			{},
			{ mantissa = "1", exponent = 0 },
			{ mantissa = 0 / 0, exponent = 0 },
			{ mantissa = 1, exponent = math.huge },
			{ mantissa = 1, exponent = 0.5 },
			{ mantissa = 1e301, exponent = 0 },
			{ mantissa = 15, exponent = 400 },
			{ mantissa = 0.5, exponent = 400 },
			{ mantissa = 5, exponent = 10 },
		}
		for _, value in broken do
			expect(BigNum.fromSaved(value)).toBeNil()
		end
	end)
end)

describe("BigNum format", function()
	local cases: { { value: BigNum.BigNum, text: string } } = {
		{ value = n(0), text = "0" },
		{ value = n(7), text = "7" },
		{ value = n(1.5), text = "1.5" },
		{ value = n(1.25), text = "1.2" },
		{ value = n(999), text = "999" },
		{ value = n(1000), text = "1K" },
		{ value = n(1500), text = "1.5K" },
		{ value = n(12345), text = "12.3K" },
		{ value = n(123456), text = "123K" },
		{ value = n(999999), text = "999K" },
		{ value = n(1e6), text = "1M" },
		{ value = n(2.5e9), text = "2.5B" },
		{ value = n(1e63), text = "1Vg" },
		{ value = n(1e66), text = "1e66" },
		{ value = BigNum.new(1.239, 400), text = "1.23e400" },
		{ value = n(-1500), text = "-1.5K" },
	}

	for _, case in cases do
		it(`formats {case.text}`, function()
			expect(BigNum.format(case.value)).toBe(case.text)
		end)
	end
end)
