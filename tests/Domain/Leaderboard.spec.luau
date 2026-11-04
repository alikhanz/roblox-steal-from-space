--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Leaderboard = require("../../src/shared/Domain/Leaderboard")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function entry(userId: number, score: number): Leaderboard.Entry
	return { userId = userId, score = score }
end

local function ids(entries: { Leaderboard.Entry }): { number }
	local result = {}
	for _, item in entries do
		table.insert(result, item.userId)
	end
	return result
end

describe("Leaderboard.score", function()
	it("is zero for one coin or less", function()
		expect(Leaderboard.score(BigNum.ZERO)).toBe(0)
		expect(Leaderboard.score(BigNum.fromNumber(0.5))).toBe(0)
		expect(Leaderboard.score(BigNum.ONE)).toBe(0)
	end)

	it("is an integer that keeps the order of amounts", function()
		local amounts = {
			BigNum.fromNumber(2),
			BigNum.fromNumber(57),
			BigNum.fromNumber(58),
			BigNum.fromNumber(1e6),
			BigNum.fromNumber(1.000002e6),
			BigNum.fromNumber(3e15),
			BigNum.new(1, 300),
			BigNum.new(2.5, 900),
		}
		local previous = -1
		for _, amount in amounts do
			local score = Leaderboard.score(amount)
			expect(score % 1).toBe(0)
			expect(score > previous).toBe(true)
			previous = score
		end
	end)

	it("stays a safe integer for the largest amounts", function()
		expect(Leaderboard.score(BigNum.new(9.9, 9000)) < 2 ^ 53).toBe(true)
	end)
end)

describe("Leaderboard.coinsOf", function()
	it("is zero for no score", function()
		expect(Leaderboard.coinsOf(0)).toEqual(BigNum.ZERO)
		expect(Leaderboard.coinsOf(-5)).toEqual(BigNum.ZERO)
	end)

	it("gives small amounts back exactly", function()
		for _, amount in { 2, 7, 57, 999, 12345, 400000 } do
			local back = Leaderboard.coinsOf(Leaderboard.score(BigNum.fromNumber(amount)))
			expect(back).toEqual(BigNum.fromNumber(amount))
		end
	end)

	it("gives large amounts back to about six digits", function()
		for _, amount in { BigNum.fromNumber(1.23456e12), BigNum.new(4.56789, 450) } do
			local back = Leaderboard.coinsOf(Leaderboard.score(amount))
			expect(back.exponent == 0 or back.exponent == amount.exponent).toBe(true)
			expect(BigNum.log10(back)).toBeCloseTo(BigNum.log10(amount), 1e-6)
		end
	end)
end)

describe("Leaderboard.fromPage", function()
	it("reads user ids and scores", function()
		local entries = Leaderboard.fromPage({ { key = "42", value = 1000 }, { key = "7", value = 10 } })
		expect(entries).toEqual({ entry(42, 1000), entry(7, 10) })
	end)

	it("skips foreign keys and broken values", function()
		local entries = Leaderboard.fromPage({
			{ key = "abc", value = 5 },
			{ key = "-3", value = 5 },
			{ key = "1.5", value = 5 },
			{ key = "9", value = "lots" },
			{ key = "10", value = 0 },
			"junk",
			{ key = "11", value = 5 },
		})
		expect(entries).toEqual({ entry(11, 5) })
	end)
end)

describe("Leaderboard.top", function()
	it("orders by score, best first, and cuts to the limit", function()
		local top = Leaderboard.top({ entry(1, 10), entry(2, 30), entry(3, 20) }, {}, 2)
		expect(ids(top)).toEqual({ 2, 3 })
	end)

	it("takes the live score over the stored one for a player here", function()
		local top = Leaderboard.top({ entry(1, 10), entry(2, 30) }, { entry(1, 50) }, 10)
		expect(top).toEqual({ entry(1, 50), entry(2, 30) })
	end)

	it("adds players here who are not stored yet", function()
		local top = Leaderboard.top({ entry(1, 10) }, { entry(5, 20) }, 10)
		expect(ids(top)).toEqual({ 5, 1 })
	end)

	it("leaves out players with no coins", function()
		local top = Leaderboard.top({ entry(1, 10) }, { entry(5, 0) }, 10)
		expect(ids(top)).toEqual({ 1 })
	end)

	it("breaks ties by user id", function()
		local top = Leaderboard.top({ entry(9, 10), entry(3, 10) }, {}, 10)
		expect(ids(top)).toEqual({ 3, 9 })
	end)
end)
