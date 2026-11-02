--!strict
-- How much a carried egg slows the jetpack. Strength (trained in stage 4) offsets the weight.

local Carry = {}

-- Never slower than this share of top speed, however heavy the egg.
local MIN_SPEED_MULTIPLIER = 0.3

-- `weight` is the share of top speed the egg takes away (0..1); `strength` cancels that share
-- of the weight (0..1). Returns the multiplier for top flight speed.
function Carry.speedMultiplier(weight: number, strength: number): number
	local effective = math.clamp(weight, 0, 1) * (1 - math.clamp(strength, 0, 1))
	return math.max(1 - effective, MIN_SPEED_MULTIPLIER)
end

return table.freeze(Carry)
