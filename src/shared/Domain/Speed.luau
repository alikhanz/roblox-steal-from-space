--!strict
-- Speed, the player's only stat, and everything derived from it: how fast the jetpack flies,
-- how much an egg slows the thief, how fast a guardian chases, and what a guardian recommends.
-- The stat itself is a BigNum (it grows to hundreds of billions); flight is physical and grows
-- slowly, so the world never breaks. Pure Luau.

local BigNum = require("./BigNum")

local Speed = {}

export type FlightTuning = {
	-- The stat value at which the jetpack flies at `referenceFlightSpeed`.
	read referenceSpeed: number,
	-- Studs per second at the reference stat.
	read referenceFlightSpeed: number,
	-- Studs per second gained for every tenfold increase of the stat.
	read flightSpeedPerDecade: number,
	-- Studs per second, never slower than this.
	read minFlightSpeed: number,
}

export type ChaseTuning = {
	-- How strongly the stat ratio shows in the chase: 1 is proportional, 0.5 softens it.
	read ratioExponent: number,
	-- A guardian never flies slower than this share of the thief's flight speed...
	read minRatio: number,
	-- ...nor faster than this share.
	read maxRatio: number,
}

-- An egg takes at most this share of the stat away.
local MAX_EGG_WEIGHT = 0.7

-- Physical flight speed for a stat value, studs per second. Logarithmic: every tenfold increase
-- of the stat adds the same amount.
function Speed.flightSpeed(speed: BigNum.BigNum, tuning: FlightTuning): number
	if BigNum.isZero(speed) or BigNum.isNegative(speed) then
		return tuning.minFlightSpeed
	end
	local decades = BigNum.log10(speed) - math.log10(tuning.referenceSpeed)
	return math.max(tuning.referenceFlightSpeed + decades * tuning.flightSpeedPerDecade, tuning.minFlightSpeed)
end

-- The share of the stat an egg takes away, from its rarity and size.
function Speed.eggWeight(rarityWeight: number, sizeFactor: number): number
	return math.clamp(rarityWeight * sizeFactor, 0, MAX_EGG_WEIGHT)
end

-- Multiplier the thief keeps while carrying an egg of `weight`.
function Speed.carryMultiplier(weight: number): number
	return 1 - math.clamp(weight, 0, MAX_EGG_WEIGHT)
end

-- The thief's stat while carrying an egg of `weight`.
function Speed.withEgg(speed: BigNum.BigNum, weight: number): BigNum.BigNum
	return BigNum.mul(speed, BigNum.fromNumber(Speed.carryMultiplier(weight)))
end

-- How fast a guardian flies after a thief, studs per second: the thief's flight speed scaled by
-- the ratio of the guardian's stat to the thief's stat with the egg. Equal stats fly equally,
-- so the head start decides; a thief twice as fast leaves the guardian far behind.
function Speed.chaseSpeed(
	thiefFlightSpeed: number,
	guardianSpeed: BigNum.BigNum,
	thiefSpeedWithEgg: BigNum.BigNum,
	tuning: ChaseTuning
): number
	local ratio = tuning.maxRatio
	if not BigNum.isZero(thiefSpeedWithEgg) and not BigNum.isNegative(thiefSpeedWithEgg) then
		-- Compared on the log scale so huge stats never overflow a double.
		local logRatio = BigNum.log10(guardianSpeed) - BigNum.log10(thiefSpeedWithEgg)
		ratio = math.clamp(10 ^ (logRatio * tuning.ratioExponent), tuning.minRatio, tuning.maxRatio)
	end
	return thiefFlightSpeed * ratio
end

-- The stat shown over a guardian: with it a thief flies level with the guardian while carrying
-- an egg of `typicalWeight`. Lighter eggs need less, heavier ones more.
function Speed.recommended(guardianSpeed: BigNum.BigNum, typicalWeight: number): BigNum.BigNum
	return BigNum.div(guardianSpeed, BigNum.fromNumber(Speed.carryMultiplier(typicalWeight)))
end

return table.freeze(Speed)
