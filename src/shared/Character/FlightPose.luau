--!strict
-- The jetpack flight pose as data: joint rotations in degrees for an R15 rig.
-- Rotation axes follow the R15 joint frames: +X tips a limb forward (arms up in front, torso
-- back), -X tips it backward; +Z swings a limb towards the character's right.
--
-- The animation loops through the keyframes: a calm hover with the hands on the jetpack grips.

export type Rotation = { x: number, y: number, z: number }
-- Part name -> rotation of the joint that drives that part. Missing parts keep their rest pose.
export type Pose = { [string]: Rotation }
export type Keyframe = { time: number, pose: Pose, rootOffsetY: number }

local function rotation(x: number, y: number, z: number): Rotation
	return { x = x, y = y, z = z }
end

local BASE: Pose = {
	UpperTorso = rotation(-8, 0, 0),
	Head = rotation(12, 0, 0),
	-- Arms bent forward, hands holding the grips in front of the hips.
	RightUpperArm = rotation(22, 0, 10),
	LeftUpperArm = rotation(22, 0, -10),
	RightLowerArm = rotation(58, 0, 0),
	LeftLowerArm = rotation(58, 0, 0),
	RightHand = rotation(0, 0, 0),
	LeftHand = rotation(0, 0, 0),
	-- Legs trail behind, one knee bent more than the other so the pose does not look stiff.
	RightUpperLeg = rotation(-14, 0, 4),
	LeftUpperLeg = rotation(-4, 0, -4),
	RightLowerLeg = rotation(-28, 0, 0),
	LeftLowerLeg = rotation(-46, 0, 0),
	RightFoot = rotation(-24, 0, 0),
	LeftFoot = rotation(-30, 0, 0),
}

-- Mid-loop variation: the body drifts up slightly, arms and legs sway.
local SWAY: Pose = {
	UpperTorso = rotation(-6, 0, 0),
	Head = rotation(10, 0, 0),
	RightUpperArm = rotation(26, 0, 10),
	LeftUpperArm = rotation(26, 0, -10),
	RightLowerArm = rotation(54, 0, 0),
	LeftLowerArm = rotation(54, 0, 0),
	RightHand = rotation(0, 0, 0),
	LeftHand = rotation(0, 0, 0),
	RightUpperLeg = rotation(-8, 0, 4),
	LeftUpperLeg = rotation(-10, 0, -4),
	RightLowerLeg = rotation(-36, 0, 0),
	LeftLowerLeg = rotation(-38, 0, 0),
	RightFoot = rotation(-28, 0, 0),
	LeftFoot = rotation(-26, 0, 0),
}

local LOOP_SECONDS = 2.4
local SWAY_LIFT = 0.15

local FlightPose = {}

FlightPose.NAME = "JetpackFlight"

FlightPose.KEYFRAMES = {
	{ time = 0, pose = BASE, rootOffsetY = 0 },
	{ time = LOOP_SECONDS / 2, pose = SWAY, rootOffsetY = SWAY_LIFT },
	{ time = LOOP_SECONDS, pose = BASE, rootOffsetY = 0 },
} :: { Keyframe }

-- R15 hierarchy: each part's pose is nested under its parent part's pose.
FlightPose.HIERARCHY = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
} :: { [string]: string }

return table.freeze(FlightPose)
