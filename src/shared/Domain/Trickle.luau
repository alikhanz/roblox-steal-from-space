--!strict
-- A gain told once in a while, shown as several even pieces in between (decision 134: training
-- arrives once a second, and the "+N ⚡" over the character pops four times a second). The pieces
-- add up to every gain told; what a new gain finds still unshown joins it. Pure Luau.

local BigNum = require("./BigNum")

export type Trickle = {
	-- Told and not shown yet.
	owed: BigNum.BigNum,
	-- Pieces left to show it in.
	left: number,
}

local Trickle = {}

function Trickle.new(): Trickle
	return { owed = BigNum.ZERO, left = 0 }
end

-- Tells a new gain, to be shown in `pieces` pieces with whatever is still unshown.
function Trickle.add(trickle: Trickle, gain: BigNum.BigNum, pieces: number)
	trickle.owed = BigNum.add(trickle.owed, gain)
	trickle.left = math.max(math.floor(pieces), 1)
end

-- The next piece to show, nil when there is none; the last one takes what the even split left.
function Trickle.take(trickle: Trickle): BigNum.BigNum?
	if trickle.left <= 0 then
		return nil
	end
	local piece = if trickle.left == 1 then trickle.owed else BigNum.div(trickle.owed, BigNum.fromNumber(trickle.left))
	trickle.owed = BigNum.sub(trickle.owed, piece)
	trickle.left -= 1
	if trickle.left == 0 then
		trickle.owed = BigNum.ZERO
	end
	return piece
end

return table.freeze(Trickle)
