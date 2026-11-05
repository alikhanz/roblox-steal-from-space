--!strict
-- Steering math for guardians. Pure: works only with the vectors it is given.

local Pursuit = {}

-- Where to aim to meet a target moving at constant velocity, leading it by the time the pursuer
-- needs to cover the current distance (capped, so far targets are not over-led).
function Pursuit.interceptPoint(
	from: Vector3,
	targetPosition: Vector3,
	targetVelocity: Vector3,
	speed: number,
	maxLeadSeconds: number
): Vector3
	local distance = (targetPosition - from).Magnitude
	local lead = if speed > 0 then math.min(distance / speed, maxLeadSeconds) else 0
	return targetPosition + targetVelocity * lead
end

-- Velocity that heads for `goal` at `maxSpeed`, easing off inside `arriveRadius` so it does not
-- overshoot. Zero at the goal.
function Pursuit.seekVelocity(from: Vector3, goal: Vector3, maxSpeed: number, arriveRadius: number): Vector3
	local offset = goal - from
	local distance = offset.Magnitude
	if distance < 1e-4 then
		-- A zero vector without touching the Vector3 global (unavailable in Lune).
		return offset * 0
	end
	local speed = if arriveRadius > 0 and distance < arriveRadius then maxSpeed * distance / arriveRadius else maxSpeed
	return offset.Unit * speed
end

-- Velocity straight away from `threat` at `speed` (the star serpent fleeing a player). Zero
-- when the threat is right on top: there is no "away" to pick.
function Pursuit.fleeVelocity(from: Vector3, threat: Vector3, speed: number): Vector3
	local offset = from - threat
	if offset.Magnitude < 1e-4 then
		return offset * 0
	end
	return offset.Unit * speed
end

return table.freeze(Pursuit)
