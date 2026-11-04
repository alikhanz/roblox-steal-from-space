--!strict
-- The one way coins come into a profile. Every source (alien income, offline income, sales,
-- later quests and gifts) earns through here, so the lifetime counter the coin board ranks by
-- can never miss one. Spending lowers only the balance.

local BigNum = require("./BigNum")

-- The part of the player's data that holds coins (PlayerData has both fields).
export type Purse = {
	coins: BigNum.BigNum,
	coinsEarned: BigNum.BigNum,
}

local Wallet = {}

-- Adds `amount` to the balance and to the coins earned all time.
function Wallet.earn(purse: Purse, amount: BigNum.BigNum)
	assert(not BigNum.isNegative(amount), "Wallet.earn expects a non-negative amount")
	purse.coins = BigNum.add(purse.coins, amount)
	purse.coinsEarned = BigNum.add(purse.coinsEarned, amount)
end

return table.freeze(Wallet)
