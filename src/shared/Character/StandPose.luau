--!strict
-- Training on the jetpack stand as pose data (axes: see PoseAnimation): the stand holds the player
-- hovering over its platform (StandConfig.HOVER_HEIGHT), as if the jetpack held them up — hands
-- on the jetpack's grips as in flight, legs hanging loose, the body trembling with the roar
-- (docs/design/screens/jetpack-stand.md). Loops quickly.
--
-- The tremble only turns joints: the body never jolts up and down. Standing on the platform with
-- bent knees and jolting, the rider read as twitching on the floor (user, 2026-11-13).
--
-- Uploading: build the sequence into ServerStorage (PoseAnimation.build(StandPose.SPEC)),
-- right-click it → Save to Roblox → Animation, and put the id into StandConfig.ANIMATION_ID
-- (overwriting the same asset keeps the id).

local PoseAnimation = require("./PoseAnimation")

local rotation = PoseAnimation.rotation
local with = PoseAnimation.with

local BASE: PoseAnimation.Joints = {
	-- Upright, leaning a little into the thrust, eyes ahead.
	UpperTorso = rotation(-6, 0, 0),
	Head = rotation(8, 0, 0),
	-- Hands on the jetpack's grips in front of the hips, as in flight (FlightPose).
	RightUpperArm = rotation(22, 0, 10),
	LeftUpperArm = rotation(22, 0, -10),
	RightLowerArm = rotation(58, 0, 0),
	LeftLowerArm = rotation(58, 0, 0),
	-- Legs hanging, one knee bent more than the other, toes down.
	RightUpperLeg = rotation(-4, 0, 3),
	LeftUpperLeg = rotation(2, 0, -3),
	RightLowerLeg = rotation(-16, 0, 0),
	LeftLowerLeg = rotation(-26, 0, 0),
	RightFoot = rotation(-30, 0, 0),
	LeftFoot = rotation(-34, 0, 0),
}

-- The tremble: the body and the hanging legs quiver one way, then the other.
local QUIVER_A = with(BASE, {
	UpperTorso = rotation(-7, 1, 0.8),
	Head = rotation(9, -1, 0),
	RightLowerLeg = rotation(-19, 0, 0),
	LeftLowerLeg = rotation(-23, 0, 0),
})
local QUIVER_B = with(BASE, {
	UpperTorso = rotation(-5, -1, -0.8),
	Head = rotation(7, 1, 0),
	RightLowerLeg = rotation(-13, 0, 0),
	LeftLowerLeg = rotation(-29, 0, 0),
})

local LOOP_SECONDS = 0.2

local StandPose = {}

StandPose.SPEC = table.freeze({
	name = "StandTraining",
	loop = true,
	-- Over Roblox's idle animation (Core) and the walk (Movement).
	priority = Enum.AnimationPriority.Action,
	keyframes = {
		{ time = 0, pose = BASE, rootOffsetY = 0 },
		{ time = LOOP_SECONDS / 4, pose = QUIVER_A, rootOffsetY = 0 },
		{ time = LOOP_SECONDS / 2, pose = BASE, rootOffsetY = 0 },
		{ time = LOOP_SECONDS * 3 / 4, pose = QUIVER_B, rootOffsetY = 0 },
		{ time = LOOP_SECONDS, pose = BASE, rootOffsetY = 0 },
	},
} :: PoseAnimation.Spec)

return table.freeze(StandPose)
