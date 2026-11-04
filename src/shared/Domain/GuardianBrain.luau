--!strict
-- The state machine every guardian shares; only how it moves while chasing differs per guardian.
-- A guardian ignores players until one takes its egg; it wakes up a moment later and chases the thief.
--
--   Sleep ──(its egg is carried by a thief in range for aggroDelaySeconds)──> Chase
--   Chase ──(thief lost, safe at the station, out of leash range or chased too long)──> Return
--   Return ──(back home)──> Sleep
--   Return ──(someone picked the egg up again)──> Chase, from wherever it is
--
-- "Home" is where the guardian keeps watch: over its egg, wherever that lies. The leash is
-- measured from there, so an egg knocked out far from the nest is guarded where it fell.

local GuardianBrain = {}

export type State = "Sleep" | "Chase" | "Return"

export type Tuning = {
	-- Wakes up this long after its egg is taken, seconds: the thief gets a head start.
	read aggroDelaySeconds: number,
	-- Gives up once the thief is this far from home, studs.
	read leashRadius: number,
	-- Gives up after chasing this long, seconds.
	read maxChaseSeconds: number,
	-- Counts as home within this distance of it, studs.
	read homeRadius: number,
	-- Catches a thief within this distance, studs.
	read catchRadius: number,
}

export type Situation = {
	-- Someone carries this guardian's egg.
	hasTarget: boolean,
	-- How long the egg has been carried, seconds (0 without a target).
	stolenSeconds: number,
	targetInStation: boolean,
	targetDistanceFromHome: number,
	distanceToHome: number,
	chaseSeconds: number,
}

-- Whether the thief can still be chased at all.
local function isReachable(situation: Situation, tuning: Tuning): boolean
	return situation.hasTarget
		and not situation.targetInStation
		and situation.targetDistanceFromHome <= tuning.leashRadius
end

function GuardianBrain.next(state: State, situation: Situation, tuning: Tuning): State
	local awake = situation.stolenSeconds >= tuning.aggroDelaySeconds and isReachable(situation, tuning)
	if state == "Sleep" then
		return if awake then "Chase" else "Sleep"
	elseif state == "Chase" then
		local keepChasing = isReachable(situation, tuning) and situation.chaseSeconds <= tuning.maxChaseSeconds
		return if keepChasing then "Chase" else "Return"
	end
	-- Returning: a thief who picks the egg up again is chased from right here, no trip home.
	if awake then
		return "Chase"
	end
	return if situation.distanceToHome <= tuning.homeRadius then "Sleep" else "Return"
end

function GuardianBrain.canCatch(state: State, distanceToTarget: number, tuning: Tuning): boolean
	return state == "Chase" and distanceToTarget <= tuning.catchRadius
end

return table.freeze(GuardianBrain)
