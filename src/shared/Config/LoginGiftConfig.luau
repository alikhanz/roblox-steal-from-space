--!strict
-- The login gift (Domain/LoginGift): how long the streak is and what each day gives. A day's gift
-- is minutes of the player's own play (Domain/PlayReward), growing to the last day, which also
-- puts an egg in the incubator. With the quests it stays a small boost to the pace (stage 7: at
-- most 10-15 %); `lune run balance` checks it.

local BigNum = require("../Domain/BigNum")
local EggConfig = require("./EggConfig")

-- Minutes of play each streak day is worth, day 1 first.
local MINUTES = { 3, 4, 5, 6, 8, 10, 15 }

return table.freeze({
	LENGTH = #MINUTES,
	MINUTES = table.freeze(MINUTES),
	-- The least a gift pays in coins, for a player with no income yet.
	MIN_REWARD_COINS = BigNum.fromNumber(200),
	-- The last day's egg: useful, not the best there is (epic since the hatch ladder, decision 113:
	-- an egg mostly hatches into its own tier). It comes from the farthest guardian the player has
	-- delivered from (the first one for a newbie).
	EGG_DAY = #MINUTES,
	EGG_RARITY = "Epic" :: EggConfig.RarityId,
	EGG_SIZE = "Medium" :: EggConfig.SizeId,
	-- Online players get the new day's gift within this many seconds of UTC midnight.
	DAY_CHECK_SECONDS = 5,
})
