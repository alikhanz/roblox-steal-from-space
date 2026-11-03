--!strict
-- The state machine every guardian shares; only how it moves while chasing differs per guardian.
-- A guardian ignores players until one takes its egg; it wakes up a moment later and chases the thief.
--
--   Sleep ──(its egg is carried by a thief in range for aggroDelaySeconds)──> Chase
--   Chase ──(thief lost, safe at the station, out of leash range or chased too long)──> Return
--   Return ──(back at the nest)──> Sleep

local GuardianBrain = {}

export type State = "Sleep" | "Chase" | "Return"

export type Tuning = {
	-- Wakes up this long after its egg is taken, seconds: the thief gets a head start.
	read aggroDelaySeconds: number,
	-- Gives up once the thief is this far from the nest, studs.
	read leashRadius: number,
	-- Gives up after chasing this long, seconds.
	read maxChaseSeconds: number,
	-- Counts as home within this distance of the nest, studs.
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
	targetDistanceFromNest: number,
	distanceToNest: number,
	chaseSeconds: number,
}

-- Whether the thief can still be chased at all.
local function isReachable(situation: Situation, tuning: Tuning): boolean
	return situation.hasTarget
		and not situation.targetInStation
		and situation.targetDistanceFromNest <= tuning.leashRadius
end

function GuardianBrain.next(state: State, situation: Situation, tuning: Tuning): State
	if state == "Sleep" then
		local awake = situation.stolenSeconds >= tuning.aggroDelaySeconds
		return if awake and isReachable(situation, tuning) then "Chase" else "Sleep"
	elseif state == "Chase" then
		local keepChasing = isReachable(situation, tuning) and situation.chaseSeconds <= tuning.maxChaseSeconds
		return if keepChasing then "Chase" else "Return"
	end
	return if situation.distanceToNest <= tuning.homeRadius then "Sleep" else "Return"
end

function GuardianBrain.canCatch(state: State, distanceToTarget: number, tuning: Tuning): boolean
	return state == "Chase" and distanceToTarget <= tuning.catchRadius
end

return table.freeze(GuardianBrain)
