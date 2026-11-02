--!strict
-- Jetpack flight math. Pure: works only with the vectors it is given (no Vector3 global),
-- so the same code runs in the simulation and in Lune tests.

local Flight = {}

export type Tuning = {
	-- Top speed with full input, studs per second.
	read maxSpeed: number,
	-- How fast velocity approaches the input target (higher = snappier), per second.
	read response: number,
	-- Share of speed kept after one second without input: the space glide.
	read driftRetentionPerSecond: number,
}

local MIN_AIM_MAGNITUDE = 0.5
local MIN_FLAT_MAGNITUDE = 1e-3

local function isFiniteVector(vector: Vector3): boolean
	local x, y, z = vector.X, vector.Y, vector.Z
	return x == x
		and y == y
		and z == z
		and math.abs(x) < math.huge
		and math.abs(y) < math.huge
		and math.abs(z) < math.huge
end

-- The client reports where its camera looks. Treat it as untrusted: a usable unit vector or nil.
function Flight.sanitizeAim(aim: Vector3): Vector3?
	if not isFiniteVector(aim) or aim.Magnitude < MIN_AIM_MAGNITUDE then
		return nil
	end
	return aim.Unit
end

-- Turns the default controls' move direction (horizontal, relative to camera yaw) into a 3D
-- flight direction along the camera aim, plus explicit vertical input in [-1, 1].
-- Without a usable aim, flight stays horizontal. The result has magnitude <= 1.
function Flight.direction(moveDirection: Vector3, aim: Vector3?, up: Vector3, vertical: number): Vector3
	local direction = moveDirection
	if aim then
		local flatAim = aim - up * aim:Dot(up)
		if flatAim.Magnitude > MIN_FLAT_MAGNITUDE then
			local forward = flatAim.Unit
			local right = forward:Cross(up)
			direction = aim * moveDirection:Dot(forward) + right * moveDirection:Dot(right)
		end
	end
	direction += up * math.clamp(vertical, -1, 1)
	if direction.Magnitude > 1 then
		return direction.Unit
	end
	return direction
end

-- Velocity for the next simulation step. With input, approaches the target exponentially
-- (frame-rate independent); without input, keeps gliding and slowly loses speed.
function Flight.nextVelocity(current: Vector3, direction: Vector3, deltaTime: number, tuning: Tuning): Vector3
	if direction.Magnitude > 0 then
		local blend = 1 - math.exp(-tuning.response * deltaTime)
		return current:Lerp(direction * tuning.maxSpeed, blend)
	end
	return current * tuning.driftRetentionPerSecond ^ deltaTime
end

return table.freeze(Flight)
