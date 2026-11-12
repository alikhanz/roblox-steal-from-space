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

-- How a thief with `stat` stands against a guardian whose recommended stat is `recommended`, on a
-- scale from -1 to 1, for the colour of its name: 0 is level (the recommended stat: with the
-- head start the thief gets away), -1 is a guardian the thief cannot get away from at all (it
-- flies its fastest relative to the thief, Speed.chaseSpeed's maxRatio), 1 is a guardian
-- `greenDecades` tenfolds weaker (an easy egg, but a poor one). Measured on the log scale.
function Speed.standing(
	stat: BigNum.BigNum,
	recommended: BigNum.BigNum,
	chase: ChaseTuning,
	greenDecades: number
): number
	if BigNum.isZero(stat) or BigNum.isNegative(stat) or BigNum.isZero(recommended) then
		return -1
	end
	local decades = BigNum.log10(stat) - BigNum.log10(recommended)
	if decades >= 0 then
		return math.min(decades / greenDecades, 1)
	end
	-- The guardian reaches its top speed against the thief when the stats are this far apart.
	local redDecades = math.log10(chase.maxRatio) / chase.ratioExponent
	return math.max(decades / redDecades, -1)
end

-- How a guardian stands against a thief, in so many words (the pill under its name, and over
-- the star serpent): "Weak" — `weakDecades` tenfolds or more below the thief, an easy egg but a
-- poor one; "Fair" — the thief's stat is at least the recommended one, so with a typical egg
-- and the head start they get away (the best prey now); "Strong" — faster than the thief, who
-- gets away only with a light egg or a long head start; "TooStrong" — it flies its fastest
-- against the thief (Speed.chaseSpeed's maxRatio), no getting away. The tiers of `standing`.
export type Challenge = "Weak" | "Fair" | "Strong" | "TooStrong"

-- A thief right on a tier's edge counts in the tier above it (the log of equal stats is not
-- always exactly 0).
local CHALLENGE_EDGE = 1e-9

function Speed.challenge(
	stat: BigNum.BigNum,
	recommended: BigNum.BigNum,
	chase: ChaseTuning,
	weakDecades: number
): Challenge
	local standing = Speed.standing(stat, recommended, chase, weakDecades)
	if standing >= 1 - CHALLENGE_EDGE then
		return "Weak"
	elseif standing >= -CHALLENGE_EDGE then
		return "Fair"
	elseif standing > -1 + CHALLENGE_EDGE then
		return "Strong"
	end
	return "TooStrong"
end

-- The stat shown over a guardian: with it a thief flies level with the guardian while carrying
-- an egg of `typicalWeight`. Lighter eggs need less, heavier ones more.
function Speed.recommended(guardianSpeed: BigNum.BigNum, typicalWeight: number): BigNum.BigNum
	return BigNum.div(guardianSpeed, BigNum.fromNumber(Speed.carryMultiplier(typicalWeight)))
end

return table.freeze(Speed)
