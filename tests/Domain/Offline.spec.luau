--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Offline = require("../../src/shared/Domain/Offline")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local CAP = 4 * 60 * 60

describe("Offline.seconds", function()
	it("pays for the time away", function()
		expect(Offline.seconds(1000, 1600, CAP)).toBe(600)
	end)

	it("caps long absences", function()
		expect(Offline.seconds(0 + 1, 1 + CAP * 3, CAP)).toBe(CAP)
	end)

	it("owes nothing to a player never seen or seen in the future", function()
		expect(Offline.seconds(0, 5000, CAP)).toBe(0)
		expect(Offline.seconds(6000, 5000, CAP)).toBe(0)
	end)

	it("rejects a negative cap", function()
		expect(function()
			Offline.seconds(1, 2, -1)
		end).toThrow("cap")
	end)
end)

describe("Offline.income", function()
	it("multiplies the rate by the seconds", function()
		local earned = Offline.income(BigNum.fromNumber(2.5), 600)
		expect(earned.mantissa).toBe(1500)
		expect(BigNum.isZero(Offline.income(BigNum.fromNumber(9), 0))).toBe(true)
	end)

	it("stays exact for huge rates", function()
		local earned = Offline.income(BigNum.new(1, 400), CAP)
		expect(earned.exponent).toBe(404)
		expect(earned.mantissa).toBeCloseTo(1.44, 1e-9)
	end)
end)
