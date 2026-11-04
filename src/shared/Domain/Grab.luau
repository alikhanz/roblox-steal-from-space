--!strict
-- Grabbing an egg: hold the grab input near an egg until the progress fills. The grab locks
-- onto an egg from farther away the faster the flyer is (lockRange), and the jetpack then pulls
-- them in (magnetVelocity); the progress fills only within reach. Letting go, or losing the
-- lock, resets it.

local Grab = {}

-- Progress 0..1 after one step. `locked`: the grab is held on an egg within the lock range;
-- `inReach`: that egg is within the plain grab reach. Locked but not yet in reach (the magnet
-- is still pulling the flyer in) keeps the progress where it is.
function Grab.step(
	progress: number,
	holding: boolean,
	locked: boolean,
	inReach: boolean,
	grabSeconds: number,
	deltaTime: number
): number
	if not holding or not locked then
		return 0
	end
	if not inReach then
		return progress
	end
	if grabSeconds <= 0 then
		return 1
	end
	return math.min(progress + deltaTime / grabSeconds, 1)
end

function Grab.isComplete(progress: number): boolean
	return progress >= 1
end

-- How far away the grab locks onto an egg: the plain reach, or `leadSeconds` of flight at top
-- speed for a fast flyer, so an egg passed at full speed is caught rather than flown past.
function Grab.lockRange(flightSpeed: number, reach: number, leadSeconds: number): number
	return math.max(reach, flightSpeed * leadSeconds)
end

export type MagnetTuning = {
	-- Top speed of the pull toward the egg, studs per second.
	read speed: number,
	-- The flyer settles this far from the egg's center, studs.
	read holdDistance: number,
	-- How fast the drift dies and the pull settles (higher = snappier), per second.
	read response: number,
}

-- While the grab is locked on, the jetpack pulls: it kills the drift and eases the flyer to a
-- spot `holdDistance` from the egg, so the egg stops slipping away mid-grab. `topSpeed` (the
-- flyer's own top speed) lets a fast flyer be pulled in from the lock range as fast as they fly.
function Grab.magnetVelocity(
	current: Vector3,
	position: Vector3,
	eggPosition: Vector3,
	deltaTime: number,
	tuning: MagnetTuning,
	topSpeed: number?
): Vector3
	local pullSpeed = math.max(tuning.speed, topSpeed or 0)
	-- A zero vector without touching the Vector3 global (unavailable in Lune).
	local target = current * 0
	local offset = position - eggPosition
	if offset.Magnitude > 1e-4 then
		-- The hold spot lies on the sphere around the egg, in the flyer's direction: from too far
		-- the pull goes in, from too close it pushes back out.
		local toGoal = eggPosition + offset.Unit * tuning.holdDistance - position
		if toGoal.Magnitude > 1e-4 then
			-- Slows down near the hold spot so it settles instead of overshooting back and forth.
			target = toGoal.Unit * math.min(pullSpeed, toGoal.Magnitude * tuning.response)
		end
	end
	local blend = 1 - math.exp(-tuning.response * deltaTime)
	return current:Lerp(target, blend)
end

return table.freeze(Grab)
