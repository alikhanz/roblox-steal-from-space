--!strict
-- The two ways the speed stat grows: the trainer (points per second, levelled up with coins)
-- and the jetpack (a multiplier on the whole stat, levelled up with coins). Every rate and
-- price is an exponential of its level; the numbers come in as tuning. Pure Luau.

local BigNum = require("./BigNum")

local Upgrades = {}

export type Tuning = {
	-- Speed points per second on a level-0 trainer, and the gain per trainer level.
	read trainerBaseRate: BigNum.BigNum,
	read trainerRateGrowth: BigNum.BigNum,
	-- The first trainer level costs trainerCostBase; each next one costs trainerCostGrowth times more.
	read trainerCostBase: BigNum.BigNum,
	read trainerCostGrowth: BigNum.BigNum,
	-- Each jetpack level multiplies the whole stat by this.
	read jetpackMultiplier: BigNum.BigNum,
	-- The first jetpack level costs jetpackCostBase; each next one costs jetpackCostGrowth times more.
	read jetpackCostBase: BigNum.BigNum,
	read jetpackCostGrowth: BigNum.BigNum,
}

local function checkLevel(level: number)
	assert(level >= 0 and level % 1 == 0, `level must be a whole number, got {level}`)
end

-- Speed points per second of a trainer at `level`.
function Upgrades.trainerRate(level: number, tuning: Tuning): BigNum.BigNum
	checkLevel(level)
	return BigNum.mul(tuning.trainerBaseRate, BigNum.pow(tuning.trainerRateGrowth, level))
end

-- Coins for the next trainer level, for a trainer at `level`.
function Upgrades.trainerPrice(level: number, tuning: Tuning): BigNum.BigNum
	checkLevel(level)
	return BigNum.mul(tuning.trainerCostBase, BigNum.pow(tuning.trainerCostGrowth, level))
end

-- What a jetpack at `level` multiplies the trained speed by.
function Upgrades.jetpackMultiplier(level: number, tuning: Tuning): BigNum.BigNum
	checkLevel(level)
	return BigNum.pow(tuning.jetpackMultiplier, level)
end

-- Coins for the next jetpack level, for a jetpack at `level`.
function Upgrades.jetpackPrice(level: number, tuning: Tuning): BigNum.BigNum
	checkLevel(level)
	return BigNum.mul(tuning.jetpackCostBase, BigNum.pow(tuning.jetpackCostGrowth, level))
end

-- The speed stat the player sees: what they trained times the jetpack.
function Upgrades.speed(trained: BigNum.BigNum, jetpackLevel: number, tuning: Tuning): BigNum.BigNum
	return BigNum.mul(trained, Upgrades.jetpackMultiplier(jetpackLevel, tuning))
end

-- Trained speed gained in `seconds` at `rate`, scaled by `factor` (1 online, less offline).
function Upgrades.trainingGain(rate: BigNum.BigNum, seconds: number, factor: number): BigNum.BigNum
	assert(seconds >= 0, "training seconds must not be negative")
	assert(factor >= 0, "training factor must not be negative")
	return BigNum.mul(rate, BigNum.fromNumber(seconds * factor))
end

return table.freeze(Upgrades)
