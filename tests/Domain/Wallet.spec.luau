--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Test = require("../../lune/lib/Test")
local Wallet = require("../../src/shared/Domain/Wallet")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Wallet.earn", function()
	it("adds to the balance and to the coins earned all time", function()
		local purse = { coins = BigNum.fromNumber(50), coinsEarned = BigNum.fromNumber(200) }
		Wallet.earn(purse, BigNum.fromNumber(30))
		expect(purse.coins).toEqual(BigNum.fromNumber(80))
		expect(purse.coinsEarned).toEqual(BigNum.fromNumber(230))
	end)

	it("works past the plain number range", function()
		local purse = { coins = BigNum.ZERO, coinsEarned = BigNum.new(5, 400) }
		Wallet.earn(purse, BigNum.new(5, 400))
		expect(purse.coins).toEqual(BigNum.new(5, 400))
		expect(purse.coinsEarned).toEqual(BigNum.new(1, 401))
	end)

	it("refuses a negative amount", function()
		local purse = { coins = BigNum.ZERO, coinsEarned = BigNum.ZERO }
		expect(function()
			Wallet.earn(purse, BigNum.fromNumber(-1))
		end).toThrow("non-negative")
	end)
end)
