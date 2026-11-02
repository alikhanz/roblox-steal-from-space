--!strict
-- Arbitrary-magnitude number for the game economy: coins, income, prices, multipliers.
--
-- Values below 1e300 are stored as an ordinary double (exponent = 0), so everyday
-- amounts stay exact and "can the player afford it" never fails by a rounding error.
-- Larger values use scientific form: a signed mantissa with magnitude in [1, 10) and
-- an integer exponent >= 300. Precision is that of a double (~15 significant digits).
--
-- Values are immutable, and their table shape is also their save format.

export type BigNum = {
	read mantissa: number,
	read exponent: number,
}

local PLAIN_EXPONENT = 300
local PLAIN_LIMIT = 10 ^ PLAIN_EXPONENT
-- Past this exponent gap the smaller operand cannot change the larger one at double precision.
local MAX_SIGNIFICANT_GAP = 17
-- Guards formatting against values like 1.2299999999 being truncated to 1.22.
local FORMAT_EPSILON = 1e-6

local SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
}

local BigNum = {}

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function make(mantissa: number, exponent: number): BigNum
	return table.freeze({ mantissa = mantissa, exponent = exponent })
end

local ZERO = make(0, 0)
local ONE = make(1, 0)

-- Splits a non-zero finite double into a mantissa with magnitude in [1, 10) and an exponent.
local function splitDouble(value: number): (number, number)
	local exponent = math.floor(math.log10(math.abs(value)))
	local mantissa = value / 10 ^ exponent
	-- log10 can be off by one ulp near powers of ten.
	local magnitude = math.abs(mantissa)
	if magnitude >= 10 then
		return mantissa / 10, exponent + 1
	elseif magnitude < 1 then
		return mantissa * 10, exponent - 1
	end
	return mantissa, exponent
end

-- Builds the canonical value for mantissa * 10^exponent.
local function fromScientific(mantissa: number, exponent: number): BigNum
	if mantissa == 0 then
		return ZERO
	end
	local normalizedMantissa, shift = splitDouble(mantissa)
	local normalizedExponent = exponent + shift
	if normalizedExponent < PLAIN_EXPONENT then
		local plain = normalizedMantissa * 10 ^ normalizedExponent
		return if plain == 0 then ZERO else make(plain, 0)
	end
	return make(normalizedMantissa, normalizedExponent)
end

-- Scientific parts of any value; (0, 0) for zero.
local function toScientific(value: BigNum): (number, number)
	if value.exponent ~= 0 or value.mantissa == 0 then
		return value.mantissa, value.exponent
	end
	return splitDouble(value.mantissa)
end

local function sign(value: number): number
	return if value > 0 then 1 elseif value < 0 then -1 else 0
end

-- Compares magnitudes. Plain values (exponent 0) are always below scientific ones (exponent >= 300).
local function compareMagnitude(left: BigNum, right: BigNum): number
	if left.exponent ~= right.exponent then
		return if left.exponent < right.exponent then -1 else 1
	end
	return sign(math.abs(left.mantissa) - math.abs(right.mantissa))
end

BigNum.ZERO = ZERO
BigNum.ONE = ONE

function BigNum.fromNumber(value: number): BigNum
	assert(isFinite(value), `BigNum.fromNumber expects a finite number, got {value}`)
	if math.abs(value) < PLAIN_LIMIT then
		return if value == 0 then ZERO else make(value, 0)
	end
	return fromScientific(value, 0)
end

-- Creates mantissa * 10^exponent, e.g. BigNum.new(1.5, 400).
function BigNum.new(mantissa: number, exponent: number): BigNum
	assert(isFinite(mantissa), `BigNum.new expects a finite mantissa, got {mantissa}`)
	assert(isFinite(exponent) and exponent % 1 == 0, `BigNum.new expects an integer exponent, got {exponent}`)
	return fromScientific(mantissa, exponent)
end

-- True when `value` has the exact shape and invariants of a BigNum (used to validate saved data).
function BigNum.isValid(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local mantissa = (value :: any).mantissa
	local exponent = (value :: any).exponent
	if type(mantissa) ~= "number" or type(exponent) ~= "number" then
		return false
	end
	if not isFinite(mantissa) or not isFinite(exponent) or exponent % 1 ~= 0 then
		return false
	end
	if exponent == 0 then
		return math.abs(mantissa) < PLAIN_LIMIT
	end
	local magnitude = math.abs(mantissa)
	return exponent >= PLAIN_EXPONENT and magnitude >= 1 and magnitude < 10
end

-- Returns an immutable copy of saved data, or nil if the data is not a valid BigNum.
function BigNum.fromSaved(value: unknown): BigNum?
	if not BigNum.isValid(value) then
		return nil
	end
	local saved = value :: BigNum
	return if saved.mantissa == 0 then ZERO else make(saved.mantissa, saved.exponent)
end

function BigNum.add(left: BigNum, right: BigNum): BigNum
	if left.exponent == 0 and right.exponent == 0 then
		local sum = left.mantissa + right.mantissa
		if math.abs(sum) < PLAIN_LIMIT then
			return if sum == 0 then ZERO else make(sum, 0)
		end
		return fromScientific(sum, 0)
	end

	local leftMantissa, leftExponent = toScientific(left)
	local rightMantissa, rightExponent = toScientific(right)
	if leftMantissa == 0 then
		return right
	elseif rightMantissa == 0 then
		return left
	end

	if leftExponent < rightExponent then
		left, right = right, left
		leftMantissa, rightMantissa = rightMantissa, leftMantissa
		leftExponent, rightExponent = rightExponent, leftExponent
	end
	local gap = leftExponent - rightExponent
	if gap > MAX_SIGNIFICANT_GAP then
		return left
	end
	return fromScientific(leftMantissa + rightMantissa / 10 ^ gap, leftExponent)
end

function BigNum.negate(value: BigNum): BigNum
	return if value.mantissa == 0 then ZERO else make(-value.mantissa, value.exponent)
end

function BigNum.sub(left: BigNum, right: BigNum): BigNum
	return BigNum.add(left, BigNum.negate(right))
end

function BigNum.mul(left: BigNum, right: BigNum): BigNum
	if left.exponent == 0 and right.exponent == 0 then
		local product = left.mantissa * right.mantissa
		-- An overflowing product becomes inf and falls through to the scientific path.
		if math.abs(product) < PLAIN_LIMIT then
			return if product == 0 then ZERO else make(product, 0)
		end
	end

	local leftMantissa, leftExponent = toScientific(left)
	local rightMantissa, rightExponent = toScientific(right)
	if leftMantissa == 0 or rightMantissa == 0 then
		return ZERO
	end
	return fromScientific(leftMantissa * rightMantissa, leftExponent + rightExponent)
end

function BigNum.div(left: BigNum, right: BigNum): BigNum
	assert(right.mantissa ~= 0, "BigNum.div: division by zero")
	if left.exponent == 0 and right.exponent == 0 then
		local quotient = left.mantissa / right.mantissa
		if math.abs(quotient) < PLAIN_LIMIT then
			return if quotient == 0 then ZERO else make(quotient, 0)
		end
	end

	local leftMantissa, leftExponent = toScientific(left)
	local rightMantissa, rightExponent = toScientific(right)
	if leftMantissa == 0 then
		return ZERO
	end
	return fromScientific(leftMantissa / rightMantissa, leftExponent - rightExponent)
end

-- Raises to a plain power, e.g. a price multiplier: BigNum.pow(BigNum.fromNumber(1.15), level).
function BigNum.pow(base: BigNum, power: number): BigNum
	assert(isFinite(power), `BigNum.pow expects a finite power, got {power}`)
	if power == 0 then
		return ONE
	end
	if base.mantissa == 0 then
		assert(power > 0, "BigNum.pow: zero to a negative power")
		return ZERO
	end
	local isNegativeBase = base.mantissa < 0
	assert(not isNegativeBase or power % 1 == 0, "BigNum.pow: negative base needs an integer power")

	if base.exponent == 0 then
		local plain = base.mantissa ^ power
		if isFinite(plain) and math.abs(plain) < PLAIN_LIMIT then
			return if plain == 0 then ZERO else make(plain, 0)
		end
	end

	local mantissa, exponent = toScientific(base)
	local log = power * (math.log10(math.abs(mantissa)) + exponent)
	local resultExponent = math.floor(log)
	local resultMantissa = 10 ^ (log - resultExponent)
	if isNegativeBase and power % 2 == 1 then
		resultMantissa = -resultMantissa
	end
	return fromScientific(resultMantissa, resultExponent)
end

-- Returns -1, 0 or 1.
function BigNum.compare(left: BigNum, right: BigNum): number
	local leftSign = sign(left.mantissa)
	local rightSign = sign(right.mantissa)
	if leftSign ~= rightSign then
		return if leftSign < rightSign then -1 else 1
	end
	if leftSign == 0 then
		return 0
	end
	return leftSign * compareMagnitude(left, right)
end

function BigNum.equals(left: BigNum, right: BigNum): boolean
	return BigNum.compare(left, right) == 0
end

function BigNum.lessThan(left: BigNum, right: BigNum): boolean
	return BigNum.compare(left, right) < 0
end

function BigNum.lessOrEqual(left: BigNum, right: BigNum): boolean
	return BigNum.compare(left, right) <= 0
end

function BigNum.max(left: BigNum, right: BigNum): BigNum
	return if BigNum.compare(left, right) >= 0 then left else right
end

function BigNum.min(left: BigNum, right: BigNum): BigNum
	return if BigNum.compare(left, right) <= 0 then left else right
end

function BigNum.isZero(value: BigNum): boolean
	return value.mantissa == 0
end

function BigNum.isNegative(value: BigNum): boolean
	return value.mantissa < 0
end

-- Rounds down. Scientific values are already whole at their magnitude.
function BigNum.floor(value: BigNum): BigNum
	if value.exponent ~= 0 then
		return value
	end
	local floored = math.floor(value.mantissa)
	return if floored == 0 then ZERO else make(floored, 0)
end

-- Converts to a double; scientific values may become math.huge.
function BigNum.toNumber(value: BigNum): number
	if value.exponent == 0 then
		return value.mantissa
	end
	return value.mantissa * 10 ^ value.exponent
end

local function truncate(value: number, decimals: number): number
	local scale = 10 ^ decimals
	return math.floor(value * scale + FORMAT_EPSILON) / scale
end

local function trimZeros(text: string): string
	if not string.find(text, ".", 1, true) then
		return text
	end
	return (string.gsub(string.gsub(text, "0+$", ""), "%.$", ""))
end

-- Short display form: "999", "1.5K", "12.3M", "1.23e66". Truncates, so it never overstates the value.
-- Display only: a formatted string must never be parsed back into a value.
function BigNum.format(value: BigNum): string
	local prefix = if value.mantissa < 0 then "-" else ""
	local magnitude = make(math.abs(value.mantissa), value.exponent)

	if magnitude.exponent == 0 and magnitude.mantissa < 1000 then
		return prefix .. trimZeros(string.format("%.1f", truncate(magnitude.mantissa, 1)))
	end

	local mantissa, exponent = toScientific(magnitude)
	local tier = exponent // 3
	if tier < #SUFFIXES then
		local scaled = mantissa * 10 ^ (exponent - tier * 3)
		local decimals = if scaled < 10 then 2 elseif scaled < 100 then 1 else 0
		local digits = trimZeros(string.format(`%.{decimals}f`, truncate(scaled, decimals)))
		return prefix .. digits .. SUFFIXES[tier + 1]
	end
	return `{prefix}{trimZeros(string.format("%.2f", truncate(mantissa, 2)))}e{exponent}`
end

return table.freeze(BigNum)
