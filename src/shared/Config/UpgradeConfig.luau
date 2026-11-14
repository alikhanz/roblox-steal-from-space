--!strict
-- The trainer and jetpack upgrades (see Domain/Upgrades for the formulas). The speed stat is
-- trained speed x jetpack multiplier. The balance calculator reads the same numbers.

local BigNum = require("../Domain/BigNum")
local Upgrades = require("../Domain/Upgrades")

local TUNING: Upgrades.Tuning = {
	-- Speed points per second on a level-0 trainer, and the gain per trainer level. Fast from
	-- the start: a new player sees their 10 double within seconds.
	trainerBaseRate = BigNum.fromNumber(3),
	trainerRateGrowth = BigNum.fromNumber(1.5),
	-- Trainer level n costs 300 * 6^(n-1) coins.
	trainerCostBase = BigNum.fromNumber(300),
	trainerCostGrowth = BigNum.fromNumber(6),

	-- Jetpacks in two marks each: I doubles the previous jetpack's I, II is x1.5 on top, so the
	-- multipliers read x2, x3, x4, x6, x8, x12... up to the last jetpack, Infinity (11), which
	-- has its first mark only: x2048 is the top (decision 056).
	jetpackGrowth = 2,
	jetpackMarks = table.freeze({ 1, 1.5 }),
	jetpackLast = 11,
	-- The first level (x2) costs 2000 coins; every doubling of the multiplier costs 10 times
	-- more (x4 20K, x8 200K), the marks between in proportion (x3 7.7K).
	jetpackCostBase = BigNum.fromNumber(2000),
	jetpackCostPerDoubling = 10,
}

return table.freeze({
	TUNING = table.freeze(TUNING),

	-- Training pays out this often while its owner flies or stands on the stand: quick numbers
	-- feel alive.
	TRAINING_TICK_SECONDS = 0.25,
	-- Shares of the trainer's rate (decision 131): flying in space trains at the full rate, so the
	-- way to grow is to go out after eggs; the stand, safe at home, at half of it.
	TRAINING_FACTORS = table.freeze({ Flight = 1, Stand = 0.5 } :: { [Upgrades.TrainingSource]: number }),

	-- Names of the jetpacks (the starting one first; Upgrades.jetpackModel gives a level's
	-- jetpack), each with its mark (Names.jetpack). JetpackLooks describes the same jetpacks.
	JETPACK_NAME_KEYS = table.freeze({
		"jetpack.level0.title",
		"jetpack.level1.title",
		"jetpack.level2.title",
		"jetpack.level3.title",
		"jetpack.level4.title",
		"jetpack.level5.title",
		"jetpack.level6.title",
		"jetpack.level7.title",
		"jetpack.level8.title",
		"jetpack.level9.title",
		"jetpack.level10.title",
		"jetpack.level11.title",
	}),
	-- Player attribute: the jetpack level, so every client can draw the right flames.
	JETPACK_LEVEL_ATTRIBUTE = "JetpackLevel",

	-- Training keeps going while the player is away: at this share of the rate, up to this long
	-- (decision 131; the Night shift subscription raises the share, MonetizationConfig).
	OFFLINE_TRAINING_FACTOR = 0.2,
	OFFLINE_TRAINING_CAP_SECONDS = 8 * 60 * 60,
})
