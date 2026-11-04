--!strict
-- The strike as pose data (axes: see PoseAnimation): from the flight pose the right arm draws
-- back, then punches straight ahead with the torso turning into it, holds for the lunge and
-- eases back. Played once over the flight pose, timed to the lunge (PvpConfig.STRIKE).
--
-- Uploading: build the sequence into ServerStorage (PoseAnimation.build(StrikePose.SPEC)),
-- right-click it → Save to Roblox → Animation, and put the id into PvpConfig.STRIKE_ANIMATION_ID.

local FlightPose = require("./FlightPose")
local PoseAnimation = require("./PoseAnimation")

local rotation = PoseAnimation.rotation
local with = PoseAnimation.with

local DRAW_BACK = with(FlightPose.BASE, {
	UpperTorso = rotation(-8, -20, 0),
	Head = rotation(12, 18, 0),
	RightUpperArm = rotation(-20, 0, 25),
	RightLowerArm = rotation(110, 0, 0),
})

local PUNCH = with(FlightPose.BASE, {
	UpperTorso = rotation(-12, 25, 0),
	Head = rotation(10, -22, 0),
	-- The right arm straight out ahead, a little across the body.
	RightUpperArm = rotation(92, 0, -8),
	RightLowerArm = rotation(4, 0, 0),
	-- The left arm pulls back for balance.
	LeftUpperArm = rotation(5, 0, -25),
	LeftLowerArm = rotation(85, 0, 0),
})

local StrikePose = {}

StrikePose.SPEC = table.freeze({
	name = "Strike",
	loop = false,
	-- Above the flight pose (Action), so the punch plays over it.
	priority = Enum.AnimationPriority.Action2,
	keyframes = {
		{ time = 0, pose = FlightPose.BASE, rootOffsetY = 0 },
		{ time = 0.06, pose = DRAW_BACK, rootOffsetY = 0 },
		{ time = 0.14, pose = PUNCH, rootOffsetY = 0 },
		{ time = 0.3, pose = PUNCH, rootOffsetY = 0 },
		{ time = 0.45, pose = FlightPose.BASE, rootOffsetY = 0 },
	},
} :: PoseAnimation.Spec)

return table.freeze(StrikePose)
