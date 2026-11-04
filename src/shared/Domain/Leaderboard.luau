--!strict
-- The coin board's numbers. Ranked stores hold only integers, while coins are BigNums that grow
-- far past what an integer holds, so a score is the decimal logarithm of the coins earned, in
-- millionths: it keeps the order and comes back to about six significant digits.

local BigNum = require("./BigNum")

-- One row: a player and their score.
export type Entry = {
	read userId: number,
	read score: number,
}

-- Millionths of a decade: 1 000 000 per tenfold.
local SCALE = 1e6
-- Scores at or below this are not ranked (one coin or less).
local MIN_SCORE = 0

local Leaderboard = {}

Leaderboard.SCALE = SCALE

-- The score for `earned` coins; 0 (not ranked) for one coin or less.
function Leaderboard.score(earned: BigNum.BigNum): number
	if BigNum.lessThan(earned, BigNum.ONE) then
		return 0
	end
	return math.floor(BigNum.log10(earned) * SCALE + 0.5)
end

-- About how many coins a score stands for. Rounded to whole coins, so small amounts come back
-- exactly.
function Leaderboard.coinsOf(score: number): BigNum.BigNum
	if score <= MIN_SCORE then
		return BigNum.ZERO
	end
	local decades = score / SCALE
	local exponent = math.floor(decades)
	local coins = BigNum.new(10 ^ (decades - exponent), exponent)
	-- Whole coins: the rounding error of the score is far below one coin for small amounts.
	return BigNum.floor(BigNum.add(coins, BigNum.fromNumber(0.5)))
end

-- Rows from a page of a ranked store: items with a user id as `key` and the score as `value`.
-- Anything else (a foreign key, a broken value) is skipped.
function Leaderboard.fromPage(items: { any }): { Entry }
	local entries: { Entry } = {}
	for _, item in items do
		if type(item) ~= "table" then
			continue
		end
		local userId = tonumber(item.key)
		local score = item.value
		if
			userId
			and userId > 0
			and userId % 1 == 0
			and type(score) == "number"
			and score == score
			and score > MIN_SCORE
		then
			table.insert(entries, table.freeze({ userId = userId, score = score }))
		end
	end
	return entries
end

local function ranksHigher(left: Entry, right: Entry): boolean
	if left.score ~= right.score then
		return left.score > right.score
	end
	-- Equal scores keep a stable order: whoever got the id first.
	return left.userId < right.userId
end

-- The top `limit` rows. `stored` comes from the ranked store and may be minutes old; `live` are
-- the players on this server with their current scores, which replace their stored rows.
function Leaderboard.top(stored: { Entry }, live: { Entry }, limit: number): { Entry }
	local byUser: { [number]: Entry } = {}
	for _, entry in stored do
		local existing = byUser[entry.userId]
		if not existing or entry.score > existing.score then
			byUser[entry.userId] = entry
		end
	end
	for _, entry in live do
		byUser[entry.userId] = entry
	end
	local rows: { Entry } = {}
	for _, entry in byUser do
		if entry.score > MIN_SCORE then
			table.insert(rows, entry)
		end
	end
	table.sort(rows, ranksHigher)
	while #rows > limit do
		table.remove(rows)
	end
	return rows
end

return table.freeze(Leaderboard)
