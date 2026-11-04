--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local PlayReward = require("../../src/shared/Domain/PlayReward")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("PlayReward.worth", function()
	it("pays minutes of income and trainer rate", function()
		local coins, trained = PlayReward.worth(10, BigNum.fromNumber(5), BigNum.fromNumber(2), BigNum.fromNumber(200))
		expect(coins).toEqual(BigNum.fromNumber(3000))
		expect(trained).toEqual(BigNum.fromNumber(1200))
	end)

	it("pays at least the minimum coins", function()
		local coins = PlayReward.worth(3, BigNum.ZERO, BigNum.ONE, BigNum.fromNumber(200))
		expect(coins).toEqual(BigNum.fromNumber(200))
	end)

	it("scales past the plain number range", function()
		local coins = PlayReward.worth(10, BigNum.new(1, 400), BigNum.ONE, BigNum.fromNumber(200))
		expect(coins).toEqual(BigNum.new(6, 402))
	end)
end)
