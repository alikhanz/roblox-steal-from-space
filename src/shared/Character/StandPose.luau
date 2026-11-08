--!strict
-- Training on the jetpack stand as pose data (axes: see PoseAnimation): the player stands with
-- knees a little bent, leaning into the thrust, both hands on the rail in front, and shakes with
-- the roaring jetpack (docs/design/screens/jetpack-stand.md). Loops quickly.
--
-- Uploading: build the sequence into ServerStorage (PoseAnimation.build(StandPose.SPEC)),
-- right-click it → Save to Roblox → Animation, and put the id into StandConfig.ANIMATION_ID.

local PoseAnimation = require("./PoseAnimation")

local rotation = PoseAnimation.rotation
local with = PoseAnimation.with

local BASE: PoseAnimation.Joints = {
	-- Leaning into the thrust, eyes ahead.
	UpperTorso = rotation(-8, 0, 0),
	Head = rotation(8, 0, 0),
	-- Arms forward and down, hands together on the rail at the waist.
	RightUpperArm = rotation(34, 0, -8),
	LeftUpperArm = rotation(34, 0, 8),
	RightLowerArm = rotation(36, 0, 0),
	LeftLowerArm = rotation(36, 0, 0),
	-- Knees a little bent, feet flat.
	RightUpperLeg = rotation(14, 0, 2),
	LeftUpperLeg = rotation(14, 0, -2),
	RightLowerLeg = rotation(-24, 0, 0),
	LeftLowerLeg = rotation(-24, 0, 0),
	RightFoot = rotation(10, 0, 0),
	LeftFoot = rotation(10, 0, 0),
}

-- The shake: the body jolts up and to one side, then down and to the other.
local JOLT_UP = with(BASE, {
	UpperTorso = rotation(-10, 2, 1.5),
	Head = rotation(10, -2, 0),
})
local JOLT_DOWN = with(BASE, {
	UpperTorso = rotation(-6, -2, -1.5),
	Head = rotation(6, 2, 0),
})

-- The knees bend this far down, studs; the jolts move the body this much.
local CROUCH = -0.15
local JOLT = 0.05
local LOOP_SECONDS = 0.24

local StandPose = {}

StandPose.SPEC = table.freeze({
	name = "StandTraining",
	loop = true,
	-- Over Roblox's idle animation (Core) and the walk (Movement).
	priority = Enum.AnimationPriority.Action,
	keyframes = {
		{ time = 0, pose = BASE, rootOffsetY = CROUCH },
		{ time = LOOP_SECONDS / 4, pose = JOLT_UP, rootOffsetY = CROUCH + JOLT },
		{ time = LOOP_SECONDS / 2, pose = BASE, rootOffsetY = CROUCH },
		{ time = LOOP_SECONDS * 3 / 4, pose = JOLT_DOWN, rootOffsetY = CROUCH - JOLT },
		{ time = LOOP_SECONDS, pose = BASE, rootOffsetY = CROUCH },
	},
} :: PoseAnimation.Spec)

return table.freeze(StandPose)
