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

-- `current` eased towards `desired`: how far it gets in `deltaTime` seconds at `response` (per
-- second; the share left shrinks as exp(-response * deltaTime)). A mover steered this way turns
-- and speeds up smoothly instead of snapping to each tick's new aim.
function Pursuit.ease(current: Vector3, desired: Vector3, response: number, deltaTime: number): Vector3
	return current + (desired - current) * (1 - math.exp(-response * deltaTime))
end

return table.freeze(Pursuit)
