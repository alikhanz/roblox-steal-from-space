--!strict
-- A number shown on screen walking to a new value instead of jumping (decision 134: the speed stat
-- arrives once a batch, about a second, and the plaque counts up to it over that time). Pure Luau.

local BigNum = require("./BigNum")

local Ease = {}

-- The value `elapsed` seconds into a walk from `from` to `to` that takes `duration`: evenly in
-- between, `to` once the time is up. A drop is shown at once (a purchase never lowers the stat;
-- a lower one is a correction, not progress).
function Ease.towards(from: BigNum.BigNum, to: BigNum.BigNum, elapsed: number, duration: number): BigNum.BigNum
	if duration <= 0 or elapsed >= duration or not BigNum.lessThan(from, to) then
		return to
	end
	local share = math.max(elapsed, 0) / duration
	return BigNum.add(from, BigNum.mul(BigNum.sub(to, from), BigNum.fromNumber(share)))
end

return table.freeze(Ease)
