--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local PlayReward = require("../../src/shared/Domain/PlayReward")
local Test = require("../../lune/lib/Test")
local UpgradeConfig = require("../../src/shared/Config/UpgradeConfig")
local Upgrades = require("../../src/shared/Domain/Upgrades")
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

describe("PlayReward limit", function()
	local function limit(share: number, trained: number, coinsEarned: number): PlayReward.Limit
		return { share = share, trained = BigNum.fromNumber(trained), coinsEarned = BigNum.fromNumber(coinsEarned) }
	end

	it("pays no more than the share of what the player has trained and earned", function()
		-- 10 minutes: 3000 coins and 1200 points uncapped; 15 % of 10 000 and of 4 000.
		local coins, trained = PlayReward.worth(
			10,
			BigNum.fromNumber(5),
			BigNum.fromNumber(2),
			BigNum.fromNumber(200),
			limit(0.15, 4000, 10000)
		)
		expect(coins).toEqual(BigNum.fromNumber(1500))
		expect(trained).toEqual(BigNum.fromNumber(600))
	end)

	it("leaves a reward under the share as it is", function()
		local coins, trained = PlayReward.worth(
			10,
			BigNum.fromNumber(5),
			BigNum.fromNumber(2),
			BigNum.fromNumber(200),
			limit(0.15, 1e9, 1e9)
		)
		expect(coins).toEqual(BigNum.fromNumber(3000))
		expect(trained).toEqual(BigNum.fromNumber(1200))
	end)

	it("keeps the coin floor for a player who has earned nothing yet", function()
		local coins, trained =
			PlayReward.worth(10, BigNum.fromNumber(5), BigNum.fromNumber(2), BigNum.fromNumber(200), limit(0.15, 10, 0))
		expect(coins).toEqual(BigNum.fromNumber(200))
		expect(trained).toEqual(BigNum.fromNumber(1.5))
	end)

	it("caps what `of` pays and keeps the jetpack on the capped points", function()
		local pace = { income = BigNum.fromNumber(5), trainerLevel = 3, jetpackLevel = 2 }
		local tuning = UpgradeConfig.TUNING
		local free = PlayReward.of(10, pace, BigNum.fromNumber(200), true, tuning)
		local capped = PlayReward.of(10, pace, BigNum.fromNumber(200), true, tuning, limit(0.15, 100, 1000))
		expect(capped.trained).toEqual(BigNum.fromNumber(15))
		expect(capped.coins).toEqual(BigNum.fromNumber(200))
		expect(capped.speed).toEqual(BigNum.mul(capped.trained, Upgrades.jetpackMultiplier(2, tuning)))
		expect(BigNum.lessThan(capped.trained, free.trained)).toBe(true)
	end)

	it("lets claims in a row grow on each other", function()
		-- Three quests one after another, each capped by what the ones before paid: x1.15^3.
		local payee = { coins = BigNum.ZERO, coinsEarned = BigNum.fromNumber(1000), trained = BigNum.fromNumber(100) }
		local pace = { income = BigNum.fromNumber(1000), trainerLevel = 10, jetpackLevel = 0 }
		for _ = 1, 3 do
			local paid = PlayReward.of(
				10,
				pace,
				BigNum.ZERO,
				true,
				UpgradeConfig.TUNING,
				limit(0.15, BigNum.toNumber(payee.trained), BigNum.toNumber(payee.coinsEarned))
			)
			PlayReward.pay(payee, paid)
		end
		expect(BigNum.toNumber(payee.trained)).toBeCloseTo(100 * 1.15 ^ 3, 1e-6)
		expect(BigNum.toNumber(payee.coinsEarned)).toBeCloseTo(1000 * 1.15 ^ 3, 1e-6)
	end)

	it("rejects a negative share", function()
		expect(function()
			PlayReward.worth(1, BigNum.ONE, BigNum.ONE, BigNum.ZERO, limit(-0.1, 1, 1))
		end).toThrow("negative")
	end)
end)
