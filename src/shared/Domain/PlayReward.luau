--!strict
-- Rewards worth some minutes of the player's own play: coins at their income and speed points at
-- their trainer rate. Quests, the login gift and the alien index all pay this way, so a reward
-- means as much to a newbie as to a veteran, and the balance calculator uses the same formula.

local BigNum = require("./BigNum")

local PlayReward = {}

-- What `minutes` of play are worth now: coins at `incomePerSecond` (never below
-- `minimumCoins`, so a player with no income yet still gets something) and speed points at
-- `trainerRate` per second.
function PlayReward.worth(
	minutes: number,
	incomePerSecond: BigNum.BigNum,
	trainerRate: BigNum.BigNum,
	minimumCoins: BigNum.BigNum
): (BigNum.BigNum, BigNum.BigNum)
	local seconds = BigNum.fromNumber(minutes * 60)
	local coins = BigNum.max(BigNum.mul(incomePerSecond, seconds), minimumCoins)
	return coins, BigNum.mul(trainerRate, seconds)
end

return table.freeze(PlayReward)
