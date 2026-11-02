--!strict
-- The state machine every guardian shares; only how it moves while chasing differs per guardian.
--
--   Sleep ──(alert full and a thief nearby)──> Chase
--   Chase ──(thief lost, safe at the station, out of leash range or chased too long)──> Return
--   Return ──(back at the nest)──> Sleep

local GuardianBrain = {}

export type State = "Sleep" | "Chase" | "Return"

export type Tuning = {
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
	alertAwake: boolean,
	hasTarget: boolean,
	targetInStation: boolean,
	targetDistanceFromNest: number,
	distanceToNest: number,
	chaseSeconds: number,
}

function GuardianBrain.next(state: State, situation: Situation, tuning: Tuning): State
	if state == "Sleep" then
		return if situation.alertAwake and situation.hasTarget then "Chase" else "Sleep"
	elseif state == "Chase" then
		local lost = not situation.hasTarget
			or situation.targetInStation
			or situation.targetDistanceFromNest > tuning.leashRadius
			or situation.chaseSeconds > tuning.maxChaseSeconds
		return if lost then "Return" else "Chase"
	end
	return if situation.distanceToNest <= tuning.homeRadius then "Sleep" else "Return"
end

function GuardianBrain.canCatch(state: State, distanceToTarget: number, tuning: Tuning): boolean
	return state == "Chase" and distanceToTarget <= tuning.catchRadius
end

return table.freeze(GuardianBrain)
