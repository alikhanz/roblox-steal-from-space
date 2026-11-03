--!strict
-- How guardians look. Kept apart from GuardianConfig so the numbers there load in Lune (the
-- balance calculator and tests), where Roblox datatypes do not exist.

local GuardianBrain = require("../Domain/GuardianBrain")
local GuardianConfig = require("./GuardianConfig")

export type KindLook = {
	read bodyShape: Enum.PartType,
	read bodySize: Vector3,
	read color: Color3,
}

local KINDS: { [GuardianConfig.KindId]: KindLook } = {
	SlimeWarden = {
		bodyShape = Enum.PartType.Ball,
		bodySize = Vector3.new(6, 5, 6),
		color = Color3.fromRGB(120, 220, 90),
	},
	CrabDrone = {
		bodyShape = Enum.PartType.Block,
		bodySize = Vector3.new(7, 3, 5),
		color = Color3.fromRGB(230, 90, 70),
	},
}

-- Colors that override the kind's for some posts, so same-kind guardians of different speeds
-- are told apart. Keyed by post index in GuardianConfig.DEBRIS_BELT_POSTS.
local DEBRIS_BELT_POST_COLORS: { [number]: Color3 } = {
	[3] = Color3.fromRGB(150, 60, 200),
}

local EYE_COLORS: { [GuardianBrain.State]: Color3 } = {
	Sleep = Color3.fromRGB(70, 70, 90),
	Chase = Color3.fromRGB(255, 40, 40),
	Return = Color3.fromRGB(255, 170, 40),
}

return table.freeze({
	KINDS = table.freeze(KINDS),
	DEBRIS_BELT_POST_COLORS = table.freeze(DEBRIS_BELT_POST_COLORS),
	EYE_COLORS = table.freeze(EYE_COLORS),
})
