--!strict
-- How much the flying body tilts: forward when speeding ahead, sideways when strafing.
-- Pure Luau: speeds in, angles (radians) out.

local FlightLean = {}

export type Tuning = {
	-- Tilt at full forward speed, radians. Flying backwards tilts back by the same rule.
	read maxPitch: number,
	-- Tilt at full sideways speed, radians.
	read maxRoll: number,
}

-- `forwardSpeed` and `rightSpeed` are velocity components in the character's facing frame.
-- Returns (pitch, roll) for CFrame.Angles(pitch, 0, roll) in that frame: the body leans into
-- the direction of travel (forward speed tips the head forward, strafing right dips the right side).
function FlightLean.angles(forwardSpeed: number, rightSpeed: number, maxSpeed: number, tuning: Tuning): (number, number)
	if maxSpeed <= 0 then
		return 0, 0
	end
	local forward = math.clamp(forwardSpeed / maxSpeed, -1, 1)
	local right = math.clamp(rightSpeed / maxSpeed, -1, 1)
	return -forward * tuning.maxPitch, -right * tuning.maxRoll
end

return table.freeze(FlightLean)
