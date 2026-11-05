--!strict
-- How a body that died out in space lies (axes: see PoseAnimation): limp, slumped, the head
-- fallen onto one shoulder, the arms hanging down, the knees bent; it tumbles slowly as it
-- drifts, so nobody takes it for a player flying. Not an animation: the server sets it on the
-- frozen body (server Character/RigPose; SpaceService). Previewed on an R15 dummy in Studio.

local PoseAnimation = require("./PoseAnimation")

local rotation = PoseAnimation.rotation

local JOINTS: PoseAnimation.Joints = {
	-- Slumped, the head fallen onto one shoulder.
	UpperTorso = rotation(-18, 6, 6),
	Head = rotation(42, 16, 26),
	-- Arms hang down along the body, a little out, the elbows barely bent.
	RightUpperArm = rotation(6, 0, 12),
	LeftUpperArm = rotation(4, 0, -15),
	RightLowerArm = rotation(14, 0, 0),
	LeftLowerArm = rotation(8, 0, 0),
	RightHand = rotation(16, 0, 0),
	LeftHand = rotation(20, 0, 0),
	-- Legs a little apart, the knees bent, one more than the other.
	RightUpperLeg = rotation(22, 0, 14),
	LeftUpperLeg = rotation(8, 0, -12),
	RightLowerLeg = rotation(-52, 0, 0),
	LeftLowerLeg = rotation(-30, 0, 0),
	RightFoot = rotation(-24, 0, 0),
	LeftFoot = rotation(-18, 0, 0),
}

return table.freeze({
	JOINTS = table.freeze(JOINTS),
	-- The body turns over this fast while it drifts, degrees per second, about an axis picked
	-- at random.
	TUMBLE_DEGREES_PER_SECOND = 25,
})
