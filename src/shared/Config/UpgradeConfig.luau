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

	-- The trainer pays out this often while its owner stands on it (CONVENTIONS, performance).
	TRAINING_TICK_SECONDS = 1,

	-- Names of the jetpacks by level (level 0 first); levels past the list keep the last name
	-- with a "+n" (Names.jetpack). JetpackLooks describes the same levels.
	JETPACK_NAME_KEYS = table.freeze({
		"jetpack.level0.title",
		"jetpack.level1.title",
		"jetpack.level2.title",
		"jetpack.level3.title",
		"jetpack.level4.title",
		"jetpack.level5.title",
		"jetpack.level6.title",
		"jetpack.level7.title",
	}),
	-- Player attribute: the jetpack level, so every client can draw the right flames.
	JETPACK_LEVEL_ATTRIBUTE = "JetpackLevel",

	-- Training keeps going while the player is away: at this share of the rate, up to this long.
	OFFLINE_TRAINING_FACTOR = 0.5,
	OFFLINE_TRAINING_CAP_SECONDS = 8 * 60 * 60,
})
