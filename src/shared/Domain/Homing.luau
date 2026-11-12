--!strict
-- How a thrown projectile moves (the gravity bomb, decision 103): it leaves with its thrower's
-- velocity, steers for its target with a limited push, and meets whoever it passes close to.
-- Pure: works only with the vectors it is given (no Vector3 global, so tests run it in Lune).

local Homing = {}

-- A projectile thrown from a mover: the mover's own velocity plus `speed` along `aim` (a unit
-- vector). However fast the thrower flies, it leaves ahead of them along the aim.
function Homing.launchVelocity(throwerVelocity: Vector3, aim: Vector3, speed: number): Vector3
	return throwerVelocity + aim * speed
end

-- The projectile's velocity after `deltaTime` of steering for a target at `targetPosition`
-- moving at `targetVelocity`. Seen from the target, it wants to come straight at it, at least
-- at `closingSpeed` (never slower than it already closes), so it sheds the drift that would
-- carry it past. The velocity changes by at most `acceleration * deltaTime`: a target that
-- turns sharply enough gets away.
function Homing.steer(
	position: Vector3,
	velocity: Vector3,
	targetPosition: Vector3,
	targetVelocity: Vector3,
	closingSpeed: number,
	acceleration: number,
	deltaTime: number
): Vector3
	local offset = targetPosition - position
	if offset.Magnitude < 1e-4 or deltaTime <= 0 then
		return velocity
	end
	local toward = offset.Unit
	local closing = math.max((velocity - targetVelocity):Dot(toward), closingSpeed)
	local change = targetVelocity + toward * closing - velocity
	local most = acceleration * deltaTime
	if change.Magnitude > most then
		change = change.Unit * most
	end
	return velocity + change
end

-- How near two movers came during a step in which one went straight from `fromA` to `toA` and
-- the other from `fromB` to `toB`, and how far through the step (0 to 1) that was. Checking
-- only the ends of a step lets a fast projectile pass through someone between two frames.
function Homing.closestApproach(fromA: Vector3, toA: Vector3, fromB: Vector3, toB: Vector3): (number, number)
	local start = fromA - fromB
	local motion = (toA - toB) - start
	local lengthSquared = motion:Dot(motion)
	local share = if lengthSquared > 1e-9 then math.clamp(-start:Dot(motion) / lengthSquared, 0, 1) else 0
	return (start + motion * share).Magnitude, share
end

return table.freeze(Homing)
