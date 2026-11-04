--!strict
-- The state machine every guardian shares; only how it moves while chasing differs per guardian.
-- A guardian ignores players until one takes its egg; it wakes up a moment later and chases the thief.
--
--   Sleep ──(its egg is carried by a thief out in space for aggroDelaySeconds)──> Chase
--   Chase ──(thief lost or safe inside the station border)──> Return
--   Return ──(back home)──> Sleep
--   Return ──(someone out in space carries the egg again)──> Chase, from wherever it is
--
-- The station border is the one line a chase ends at: however far a thief flies the other
-- way, the guardian keeps after them, so only speed or reaching the station saves the egg.
-- "Home" is where the guardian keeps watch: over its egg, wherever that lies.

local GuardianBrain = {}

export type State = "Sleep" | "Chase" | "Return"

export type Tuning = {
	-- Wakes up this long after its egg is taken, seconds: the thief gets a head start.
	read aggroDelaySeconds: number,
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
	-- The thief is inside the station border, where guardians never go.
	targetSafe: boolean,
	distanceToHome: number,
}

-- Whether the thief can be chased at all.
local function isReachable(situation: Situation): boolean
	return situation.hasTarget and not situation.targetSafe
end

function GuardianBrain.next(state: State, situation: Situation, tuning: Tuning): State
	local awake = situation.stolenSeconds >= tuning.aggroDelaySeconds and isReachable(situation)
	if state == "Sleep" then
		return if awake then "Chase" else "Sleep"
	elseif state == "Chase" then
		return if isReachable(situation) then "Chase" else "Return"
	end
	-- Returning: a thief who takes the egg out again is chased from right here, no trip home.
	if awake then
		return "Chase"
	end
	return if situation.distanceToHome <= tuning.homeRadius then "Sleep" else "Return"
end

function GuardianBrain.canCatch(state: State, distanceToTarget: number, tuning: Tuning): boolean
	return state == "Chase" and distanceToTarget <= tuning.catchRadius
end

return table.freeze(GuardianBrain)
