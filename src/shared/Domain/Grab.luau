--!strict
-- Grabbing an egg (docs/design/screens/grab-button.md): one press of the grab input near an egg
-- locks the grab on it (nextEngaged), the jetpack then pulls the flyer in (magnetVelocity) and
-- the progress fills within reach (step). Pressing again, steering away, losing the egg or being
-- hit lets go and resets the progress.

local Grab = {}

export type EngageInput = {
	-- The egg the grab is locked on now (its id), if any.
	engaged: string?,
	-- The grab input is down on this step, and was down on the last one.
	pressed: boolean,
	wasPressed: boolean,
	-- The nearest egg the grab button offers, if any.
	candidate: string?,
	-- The locked-on egg is still there and near enough to hold on to.
	engagedPresent: boolean,
	-- The flyer steers away from the locked-on egg (isMovingAway).
	movingAway: boolean,
	-- Grabbing is impossible now: not in space, stunned, or hands full.
	blocked: boolean,
}

-- The egg the grab is locked on after this step. A press (the input going down) locks on the
-- offered egg, or lets go if already locked on; the lock also ends when the egg is gone or out
-- of hold range, when the flyer steers away, or when grabbing becomes impossible.
function Grab.nextEngaged(input: EngageInput): string?
	if input.blocked then
		return nil
	end
	local engaged = input.engaged
	if engaged and (not input.engagedPresent or input.movingAway) then
		engaged = nil
	end
	if input.pressed and not input.wasPressed then
		-- A second press lets go; a press after the lock was lost locks on afresh.
		if engaged then
			return nil
		end
		return input.candidate
	end
	return engaged
end

-- Whether move input steers away from the egg: strong enough (`minMove` of a full push) and
-- pointing away from it (its direction's dot with the way to the egg at most `maxDot`). Only
-- the level part counts: flying up or down never lets go.
function Grab.isMovingAway(moveDirection: Vector3, toEgg: Vector3, minMove: number, maxDot: number): boolean
	-- Plain numbers, not the Vector3 global (unavailable in Lune).
	local moveLength = math.sqrt(moveDirection.X ^ 2 + moveDirection.Z ^ 2)
	local eggLength = math.sqrt(toEgg.X ^ 2 + toEgg.Z ^ 2)
	if moveLength < minMove or eggLength < 1e-4 then
		return false
	end
	local dot = (moveDirection.X * toEgg.X + moveDirection.Z * toEgg.Z) / (moveLength * eggLength)
	return dot <= maxDot
end

-- How far the grab button offers an egg: its own range, or the lock range of a fast flyer.
function Grab.buttonRange(lockRange: number, buttonRange: number): number
	return math.max(lockRange, buttonRange)
end

-- Progress 0..1 after one step. `holding`: the grab is locked on (nextEngaged); `locked`: its
-- egg is found;
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
