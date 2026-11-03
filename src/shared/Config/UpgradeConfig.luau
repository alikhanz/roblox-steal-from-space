--!strict
-- The trainer and jetpack upgrades (see Domain/Upgrades for the formulas). The speed stat is
-- trained speed x jetpack multiplier. The balance calculator reads the same numbers.

local BigNum = require("../Domain/BigNum")
local Upgrades = require("../Domain/Upgrades")

local TUNING: Upgrades.Tuning = {
	-- Speed points per second on a level-0 trainer, and the gain per trainer level.
	trainerBaseRate = BigNum.fromNumber(0.3),
	trainerRateGrowth = BigNum.fromNumber(1.6),
	-- Trainer level n costs 300 * 5^(n-1) coins.
	trainerCostBase = BigNum.fromNumber(300),
	trainerCostGrowth = BigNum.fromNumber(5),

	-- Each jetpack level multiplies the whole speed stat by this.
	jetpackMultiplier = BigNum.fromNumber(2),
	-- Jetpack level n costs 2000 * 8^(n-1) coins.
	jetpackCostBase = BigNum.fromNumber(2000),
	jetpackCostGrowth = BigNum.fromNumber(8),
}

return table.freeze({
	TUNING = table.freeze(TUNING),

	-- Training keeps going while the player is away: at this share of the rate, up to this long.
	OFFLINE_TRAINING_FACTOR = 0.5,
	OFFLINE_TRAINING_CAP_SECONDS = 8 * 60 * 60,
})
