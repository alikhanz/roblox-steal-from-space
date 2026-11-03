--!strict
-- How guardians look. Kept apart from GuardianConfig so the numbers there load in Lune (the
-- balance calculator and tests), where Roblox datatypes do not exist. Greybox: a body kind
-- gives the shape, the post gives the color and size.

local GuardianBrain = require("../Domain/GuardianBrain")
local GuardianConfig = require("./GuardianConfig")

export type KindLook = {
	read bodyShape: Enum.PartType,
	read bodySize: Vector3,
}

export type PostLook = {
	read color: Color3,
	-- Multiplies the kind's body size.
	read scale: number,
}

local KINDS: { [GuardianConfig.KindId]: KindLook } = {
	SlimeWarden = { bodyShape = Enum.PartType.Ball, bodySize = Vector3.new(6, 5, 6) },
	CrabDrone = { bodyShape = Enum.PartType.Block, bodySize = Vector3.new(7, 3, 5) },
	-- Long along its facing axis.
	IceWorm = { bodyShape = Enum.PartType.Block, bodySize = Vector3.new(3.5, 3, 13) },
	DevourerSwarm = { bodyShape = Enum.PartType.Ball, bodySize = Vector3.new(7.5, 7.5, 7.5) },
	-- Flat and wide.
	StarRay = { bodyShape = Enum.PartType.Block, bodySize = Vector3.new(11, 1.4, 8) },
	SpaceWhale = { bodyShape = Enum.PartType.Block, bodySize = Vector3.new(12, 8, 24) },
}

local rgb = Color3.fromRGB

local POSTS: { [GuardianConfig.PostId]: PostLook } = {
	-- Debris Belt
	SlimeWarden = { color = rgb(120, 220, 90), scale = 1 },
	CrabDrone = { color = rgb(230, 90, 70), scale = 1 },
	VioletCrab = { color = rgb(150, 60, 200), scale = 1.1 },
	AcidSlime = { color = rgb(190, 240, 40), scale = 1.15 },
	RustyCrab = { color = rgb(160, 90, 40), scale = 1.25 },
	SlimeKing = { color = rgb(60, 160, 60), scale = 1.5 },
	-- Ice Rings
	IceWorm = { color = rgb(150, 220, 255), scale = 1 },
	SnowCrab = { color = rgb(235, 245, 255), scale = 1.2 },
	FrostSlime = { color = rgb(120, 200, 240), scale = 1.3 },
	CrystalWorm = { color = rgb(200, 240, 255), scale = 1.2 },
	IceRay = { color = rgb(120, 180, 230), scale = 1 },
	WormMother = { color = rgb(90, 150, 210), scale = 1.6 },
	-- Red Nebula
	DevourerSwarm = { color = rgb(170, 30, 40), scale = 1 },
	StarRay = { color = rgb(230, 120, 200), scale = 1.2 },
	FireSlime = { color = rgb(255, 120, 30), scale = 1.5 },
	RedSwarm = { color = rgb(230, 50, 50), scale = 1.3 },
	LightningRay = { color = rgb(255, 230, 90), scale = 1.4 },
	DevourerQueen = { color = rgb(120, 10, 40), scale = 1.8 },
	-- Event Horizon
	ShadowWorm = { color = rgb(40, 30, 60), scale = 1.5 },
	BlackRay = { color = rgb(20, 20, 30), scale = 1.6 },
	VoidSwarm = { color = rgb(60, 20, 90), scale = 1.7 },
	GravityCrab = { color = rgb(90, 60, 140), scale = 1.9 },
	WhaleCalf = { color = rgb(120, 140, 190), scale = 0.6 },
	SpaceWhale = { color = rgb(70, 90, 150), scale = 1 },
}
for id in GuardianConfig.POSTS_BY_ID do
	assert(POSTS[id], `GuardianLooks has no look for post {id}`)
end

local EYE_COLORS: { [GuardianBrain.State]: Color3 } = {
	Sleep = Color3.fromRGB(70, 70, 90),
	Chase = Color3.fromRGB(255, 40, 40),
	Return = Color3.fromRGB(255, 170, 40),
}

return table.freeze({
	KINDS = table.freeze(KINDS),
	POSTS = table.freeze(POSTS),
	EYE_COLORS = table.freeze(EYE_COLORS),
})
