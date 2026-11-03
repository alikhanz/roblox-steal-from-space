--!strict
-- Grabbing an egg: hold the grab input next to the nest until the progress fills.
-- Letting go or drifting out of reach resets it.

local Grab = {}

-- Progress 0..1 after one step.
function Grab.step(progress: number, holding: boolean, inReach: boolean, grabSeconds: number, deltaTime: number): number
	if not holding or not inReach then
		return 0
	end
	if grabSeconds <= 0 then
		return 1
	end
	return math.min(progress + deltaTime / grabSeconds, 1)
end

function Grab.isComplete(progress: number): boolean
	return progress >= 1
end

export type MagnetTuning = {
	-- Top speed of the pull toward the egg, studs per second.
	read speed: number,
	-- The flyer settles this far from the egg's center, studs.
	read holdDistance: number,
	-- How fast the drift dies and the pull settles (higher = snappier), per second.
	read response: number,
}

-- While the grab is held in reach, the jetpack locks on: it kills the drift and eases the flyer
-- to a spot `holdDistance` from the egg, so the egg stops slipping away mid-grab.
function Grab.magnetVelocity(
	current: Vector3,
	position: Vector3,
	eggPosition: Vector3,
	deltaTime: number,
	tuning: MagnetTuning
): Vector3
	-- A zero vector without touching the Vector3 global (unavailable in Lune).
	local target = current * 0
	local offset = position - eggPosition
	if offset.Magnitude > 1e-4 then
		-- The hold spot lies on the sphere around the egg, in the flyer's direction: from too far
		-- the pull goes in, from too close it pushes back out.
		local toGoal = eggPosition + offset.Unit * tuning.holdDistance - position
		if toGoal.Magnitude > 1e-4 then
			-- Slows down near the hold spot so it settles instead of overshooting back and forth.
			target = toGoal.Unit * math.min(tuning.speed, toGoal.Magnitude * tuning.response)
		end
	end
	local blend = 1 - math.exp(-tuning.response * deltaTime)
	return current:Lerp(target, blend)
end

return table.freeze(Grab)
