--!strict
-- Progress while the player is away: paid for server time since the saved mark, with a cap.

local BigNum = require("./BigNum")

local Offline = {}

-- Seconds to pay for. A mark of zero means "never seen": nothing is owed.
function Offline.seconds(lastSeenAt: number, now: number, capSeconds: number): number
	assert(capSeconds >= 0, "offline cap must not be negative")
	if lastSeenAt <= 0 then
		return 0
	end
	return math.clamp(now - lastSeenAt, 0, capSeconds)
end

function Offline.income(ratePerSecond: BigNum.BigNum, seconds: number): BigNum.BigNum
	assert(seconds >= 0, "offline seconds must not be negative")
	return BigNum.mul(ratePerSecond, BigNum.fromNumber(seconds))
end

return table.freeze(Offline)
