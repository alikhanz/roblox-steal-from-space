--!strict
-- Rewards worth some minutes of the player's own play: coins at their income and speed points at
-- their trainer rate. Quests, the login gift and the alien index all pay this way, so a reward
-- means as much to a newbie as to a veteran. The server pays with `of` + `pay`, the client shows
-- `of`, and the balance calculator uses `worth`: one formula everywhere. Quests and the login gift
-- pay at most a share of what the player has (decision 114): a newbie who trained for two minutes
-- does not get ten minutes of speed at once.

local BigNum = require("./BigNum")
local Upgrades = require("./Upgrades")
local Wallet = require("./Wallet")

-- How fast the player goes: what a reward is measured against.
export type Pace = {
	read income: BigNum.BigNum,
	read trainerLevel: number,
	read jetpackLevel: number,
}

-- What a reward pays.
export type Paid = {
	read coins: BigNum.BigNum,
	-- Speed points as trained, and the stat they add (times the jetpack).
	read trained: BigNum.BigNum,
	read speed: BigNum.BigNum,
}

-- A reward's ceiling (decision 114): at most `share` of the speed points trained and of the coins
-- earned all time, before this reward. The coin floor still holds.
export type Limit = {
	read share: number,
	read trained: BigNum.BigNum,
	read coinsEarned: BigNum.BigNum,
}

-- The part of the profile a reward goes into (PlayerData has all of it).
export type Payee = Wallet.Purse & { trained: BigNum.BigNum }

local PlayReward = {}

-- What `minutes` of play are worth: coins at `incomePerSecond` (never below `minimumCoins`, so a
-- player with no income yet still gets something) and speed points at `trainerRate` per second,
-- each no more than `limit` allows when given.
function PlayReward.worth(
	minutes: number,
	incomePerSecond: BigNum.BigNum,
	trainerRate: BigNum.BigNum,
	minimumCoins: BigNum.BigNum,
	limit: Limit?
): (BigNum.BigNum, BigNum.BigNum)
	local seconds = BigNum.fromNumber(minutes * 60)
	local coins = BigNum.mul(incomePerSecond, seconds)
	local trained = BigNum.mul(trainerRate, seconds)
	if limit then
		assert(limit.share >= 0, "a reward's share must not be negative")
		local share = BigNum.fromNumber(limit.share)
		coins = BigNum.min(coins, BigNum.mul(limit.coinsEarned, share))
		trained = BigNum.min(trained, BigNum.mul(limit.trained, share))
	end
	return BigNum.max(coins, minimumCoins), trained
end

-- What a reward of `minutes` pays a player going at `pace`; speed only when `withSpeed` (the
-- index pays coins alone); no more than `limit` allows when given.
function PlayReward.of(
	minutes: number,
	pace: Pace,
	minimumCoins: BigNum.BigNum,
	withSpeed: boolean,
	tuning: Upgrades.Tuning,
	limit: Limit?
): Paid
	local rate = if withSpeed then Upgrades.trainerRate(pace.trainerLevel, tuning) else BigNum.ZERO
	local coins, trained = PlayReward.worth(minutes, pace.income, rate, minimumCoins, limit)
	return {
		coins = coins,
		trained = trained,
		speed = BigNum.mul(trained, Upgrades.jetpackMultiplier(pace.jetpackLevel, tuning)),
	}
end

-- Puts a reward into the profile: coins through the wallet (they count as earned), speed points
-- into the trained stat.
function PlayReward.pay(payee: Payee, paid: Paid)
	Wallet.earn(payee, paid.coins)
	payee.trained = BigNum.add(payee.trained, paid.trained)
end

return table.freeze(PlayReward)
