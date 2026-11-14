--!strict
-- What an owned alien earns (decision 130): the income of its kind, grade, tier and variant
-- (AlienConfig) times its own roll, a whole percent drawn once when it comes to be and saved with
-- it (PlayerData.AlienRecord.incomePercent). Everything that counts an alien's coins (places,
-- time away, selling, the best to places, the shelf's trios, the windows) asks here. Pure Luau: the
-- randomness comes in as `NextInteger` (the server's Random; a fixed sequence in tests).

local AlienConfig = require("../Config/AlienConfig")
local BayConfig = require("../Config/BayConfig")
local BigNum = require("./BigNum")

-- A random whole number from `min` to `max`, both included (Random:NextInteger).
export type NextInteger = (min: number, max: number) -> number

-- How rolls are drawn: the sum of `dice` even throws, `min` to `max` in all.
export type Roll = {
	read min: number,
	read max: number,
	read dice: number,
}

-- What decides an alien's income: a record of the profile fits.
export type Owned = {
	read id: string,
	-- nil: an alien that never rolled (only data the game has not loaded yet); counts as 100.
	read incomePercent: number?,
}

local AlienIncome = {}

-- The roll of an alien with no roll of its own.
AlienIncome.NEUTRAL = 100

local function checkRoll(roll: Roll)
	assert(roll.dice >= 1 and roll.dice % 1 == 0, "income roll needs a whole number of dice")
	assert(roll.max > roll.min, "income roll needs max above min")
	assert((roll.max - roll.min) % roll.dice == 0, "the income roll's span must split evenly between its dice")
end

-- A new roll: `roll.dice` throws of 0..(span / dice) added to `roll.min`, so the middle comes up
-- most often and both ends seldom.
function AlienIncome.roll(roll: Roll, nextInteger: NextInteger): number
	checkRoll(roll)
	local face = (roll.max - roll.min) // roll.dice
	local total = roll.min
	for _ = 1, roll.dice do
		total += nextInteger(0, face)
	end
	return total
end

-- A roll for a new alien, by the game's tuning (AlienConfig.INCOME_ROLL).
function AlienIncome.draw(nextInteger: NextInteger): number
	return AlienIncome.roll(AlienConfig.INCOME_ROLL, nextInteger)
end

-- A saved roll fitted to the game's tuning: one from a wider tuning keeps its nearest end (a
-- tuning that narrows must not make old aliens earn more or less than any new one can).
function AlienIncome.fit(percent: number): number
	local roll = AlienConfig.INCOME_ROLL
	return math.clamp(math.round(percent), roll.min, roll.max)
end

-- The alien's roll in percent.
function AlienIncome.percentOf(alien: Owned): number
	return alien.incomePercent or AlienIncome.NEUTRAL
end

-- How far its roll is from 100, in percent: +23 or -8 (what the windows show beside its income).
function AlienIncome.bonusOf(alien: Owned): number
	return AlienIncome.percentOf(alien) - AlienIncome.NEUTRAL
end

-- `base` scaled by a roll in percent.
function AlienIncome.scaled(base: BigNum.BigNum, percent: number): BigNum.BigNum
	return BigNum.mul(base, BigNum.fromNumber(percent / 100))
end

-- Coins per second the alien earns in a place; zero for an id the game doesn't know.
function AlienIncome.of(alien: Owned): BigNum.BigNum
	local configured = AlienConfig.ALIENS[alien.id]
	if not configured then
		return BigNum.ZERO
	end
	return AlienIncome.scaled(configured.income, AlienIncome.percentOf(alien))
end

-- Coins the alien sells for: its own income for BayConfig.SELL_INCOME_SECONDS (a lucky roll sells
-- for more).
function AlienIncome.saleOf(alien: Owned): BigNum.BigNum
	return BigNum.mul(AlienIncome.of(alien), BigNum.fromNumber(BayConfig.SELL_INCOME_SECONDS))
end

-- The same as a plain number, for sorting and comparing (incomes stay far below double range).
function AlienIncome.numberOf(alien: Owned): number
	return BigNum.toNumber(AlienIncome.of(alien))
end

return table.freeze(AlienIncome)
