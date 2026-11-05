--!strict
-- The two ways the speed stat grows: the trainer (points per second, levelled up with coins)
-- and the jetpack (a multiplier on the whole stat, levelled up with coins). The trainer's rate
-- and price are exponentials of its level. Jetpack levels come in models: each jetpack has a
-- few marks (I, II), the first mark of a jetpack doubles the one before, the later marks step
-- part of the way to the next (x2, x3, x4, x6, x8, x12...), so the numbers read well. A jetpack
-- level is priced by the multiplier it gives: every doubling costs the same factor more. The
-- numbers come in as tuning. Pure Luau.

local BigNum = require("./BigNum")

local Upgrades = {}

export type Tuning = {
	-- Speed points per second on a level-0 trainer, and the gain per trainer level.
	read trainerBaseRate: BigNum.BigNum,
	read trainerRateGrowth: BigNum.BigNum,
	-- The first trainer level costs trainerCostBase; each next one costs trainerCostGrowth times more.
	read trainerCostBase: BigNum.BigNum,
	read trainerCostGrowth: BigNum.BigNum,
	-- Each jetpack's first mark multiplies the whole stat by this much more than the previous
	-- jetpack's first mark (the level-0 jetpack multiplies by 1).
	read jetpackGrowth: number,
	-- Each mark of a jetpack, as a share of that jetpack's first mark: { 1, 1.5 } is "I" x1
	-- and "II" x1.5. Their count is the marks per jetpack.
	read jetpackMarks: { number },
	-- The first jetpack level costs jetpackCostBase; a level with twice the multiplier costs
	-- jetpackCostPerDoubling times more.
	read jetpackCostBase: BigNum.BigNum,
	read jetpackCostPerDoubling: number,
	-- The number of the last jetpack (the starting one is 0): its first mark is the top level,
	-- and there is nothing past it.
	read jetpackLast: number,
}

-- The top jetpack level: the last jetpack's first mark.
function Upgrades.jetpackMaxLevel(tuning: Tuning): number
	return (tuning.jetpackLast - 1) * #tuning.jetpackMarks + 1
end

-- Which jetpack a level belongs to (0 for the starting one, 1 for the first bought) and its
-- mark within it (1-based; 1 for the starting one).
function Upgrades.jetpackModel(level: number, tuning: Tuning): (number, number)
	assert(level >= 0 and level % 1 == 0, `level must be a whole number, got {level}`)
	if level == 0 then
		return 0, 1
	end
	local marks = #tuning.jetpackMarks
	return (level - 1) // marks + 1, (level - 1) % marks + 1
end

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

-- What a jetpack at `level` multiplies the trained speed by (a level past the top counts as
-- the top: saved data from before the top existed).
function Upgrades.jetpackMultiplier(level: number, tuning: Tuning): BigNum.BigNum
	checkLevel(level)
	local jetpack, mark = Upgrades.jetpackModel(math.min(level, Upgrades.jetpackMaxLevel(tuning)), tuning)
	if jetpack == 0 then
		return BigNum.fromNumber(1)
	end
	return BigNum.mul(
		BigNum.pow(BigNum.fromNumber(tuning.jetpackGrowth), jetpack),
		BigNum.fromNumber(tuning.jetpackMarks[mark])
	)
end

-- A price to two significant digits (7.7K, not 7,692): prices are read at a glance.
local function roundPrice(price: BigNum.BigNum): BigNum.BigNum
	if BigNum.isZero(price) then
		return price
	end
	local exponent = math.floor(BigNum.log10(price))
	local mantissa = 10 ^ (BigNum.log10(price) - exponent)
	return BigNum.new(math.round(mantissa * 10) / 10, exponent)
end

-- Coins for the next jetpack level, for a jetpack at `level` below the top
-- (Upgrades.jetpackMaxLevel): the base for the first one, jetpackCostPerDoubling times more for
-- every doubling of the multiplier since.
function Upgrades.jetpackPrice(level: number, tuning: Tuning): BigNum.BigNum
	checkLevel(level)
	assert(level < Upgrades.jetpackMaxLevel(tuning), `jetpack level {level} is the top; nothing to buy`)
	local first = Upgrades.jetpackMultiplier(1, tuning)
	local nextOne = Upgrades.jetpackMultiplier(level + 1, tuning)
	local doublings = (BigNum.log10(nextOne) - BigNum.log10(first)) / math.log10(2)
	return roundPrice(
		BigNum.mul(tuning.jetpackCostBase, BigNum.pow(BigNum.fromNumber(tuning.jetpackCostPerDoubling), doublings))
	)
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
