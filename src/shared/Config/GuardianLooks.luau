--!strict
-- How guardians look. Kept apart from GuardianConfig so the numbers there load in Lune (the
-- balance calculator and tests), where Roblox datatypes do not exist. The greybox body: a body
-- kind gives the shape, the post the color and size; the real model (MODELS, decision 090) is
-- fitted to that size and moves by the guardian's state (STATE_MOTION).

local GuardianBrain = require("../Domain/GuardianBrain")
local GuardianConfig = require("./GuardianConfig")
local Speed = require("../Domain/Speed")
-- selene: allow(unused_variable) -- only its type is used, to keep text keys checked.
local Strings = require("../Locale/Strings")

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

-- The real models (docs/plans/GUARDIANS.md): a post's adult, assets/guardians/<post>.rbxm, put
-- into the place by hand as ReplicatedStorage.<FOLDER_NAME> (lune/guardians.luau). The server's
-- guardian stays the greybox body that moves and catches; each client dresses it in its post's
-- model (World/GuardianVisual), which never crosses the network. A post with no model in the
-- place shows the greybox.
local MODELS = table.freeze({
	FOLDER_NAME = "Guardians",
	-- The fingerprint lune/guardians.luau gives each model; GuardianModels.json lists the repo's.
	HASH_ATTRIBUTE = "ModelHash",
	-- Where each client keeps its guardians' models.
	CLIENT_FOLDER = "GuardianLooks",
	-- Paint sources the game colours itself: the eyes by state, the throat by how fierce.
	EYE_SOURCE = "GuardianEye",
	MAW_SOURCE = "Maw",
	-- A guardian's glowing core (a slime's jelly) is darkened by this share of its pet's colour: a
	-- big Neon part in the pet's bright colour burns to white under Bloom (seen in Studio, 2026-11-10).
	CORE_DIM = 0.5,
	-- A guardian wears its model only near the camera (decision 101; GuardianPose.wearReach):
	-- within ATTACH_DISTANCE studs past its half length, or ATTACH_LENGTHS of its own lengths if
	-- that is farther. Farther it shows the server's greybox in its post's colour; where the look
	-- changes it is at most 1 / ATTACH_LENGTHS radians (under 1°) of the view, a few pixels. 132
	-- models over the whole map were two thirds of the scene's draw calls. Taking it off waits
	-- ATTACH_MARGIN studs more. The distances are checked every ATTACH_CHECK_SECONDS, and at most
	-- one model is put on a frame (a copy is ~25 MeshParts).
	ATTACH_DISTANCE = 700,
	ATTACH_LENGTHS = 60,
	ATTACH_MARGIN = 100,
	ATTACH_CHECK_SECONDS = 0.25,
	-- The parts move only this close to the camera, studs past the model's half length; farther it
	-- stands still and is carried whole with its body. Leaving takes MOTION_MARGIN more.
	MOTION_DISTANCE = 300,
	MOTION_MARGIN = 30,
	-- A model near the camera follows its body smoothly (GuardianPose.follow): a jump of the
	-- body's position is made up over this many seconds, a turn over this many (the star
	-- serpent's head turns as quickly, SerpentLooks.MODEL.TURN_SECONDS). Farther from its body
	-- than this, studs (streamed in, a teleport), it is put straight on it.
	FOLLOW_SECONDS = 0.25,
	TURN_SECONDS = 0.36,
	SNAP_DISTANCE = 20,
	-- It hovers, bobbing this much of its height.
	BOB = 0.03,
	-- Its pace eases to a new state's over this many seconds.
	TEMPO_EASE_SECONDS = 0.6,
	-- A catch: it lunges ahead this share of its length and its jaws snap, over this many seconds.
	STRIKE_LUNGE = 0.2,
	STRIKE_SECONDS = 0.35,
	-- A jaw snapping at a catch opens this much wider, radians.
	STRIKE_MOUTH = 0.35,
})

-- The sign over a guardian (UI/GuardianLabel), and over the star serpent: full size within
-- NEAR_DISTANCE studs of the camera, FAR_SCALE of it from FAR_DISTANCE on (GuardianPose.labelScale);
-- its bottom STUDS_ABOVE over the body's middle.
local LABEL = table.freeze({
	NEAR_DISTANCE = 40,
	FAR_DISTANCE = 500,
	FAR_SCALE = 0.6,
	STUDS_ABOVE = 4,
	-- A sign is resized only when its size changes by more than this share.
	SCALE_STEP = 0.01,
})

-- How a guardian moves in each state: its parts' pace (1: a pet's), how far its lower jaw hangs
-- open (radians) and how brightly its throat glows (a share of full).
export type StateMotion = {
	read tempo: number,
	read mouth: number,
	read maw: number,
}

local STATE_MOTION: { [GuardianBrain.State]: StateMotion } = {
	Sleep = table.freeze({ tempo = 0.45, mouth = 0.04, maw = 0.3 }),
	Chase = table.freeze({ tempo = 1.8, mouth = 0.4, maw = 1 }),
	Return = table.freeze({ tempo = 1, mouth = 0.12, maw = 0.6 }),
}

local EYE_COLORS: { [GuardianBrain.State]: Color3 } = {
	Sleep = Color3.fromRGB(70, 70, 90),
	Chase = Color3.fromRGB(255, 40, 40),
	Return = Color3.fromRGB(255, 170, 40),
}

-- The pill under a guardian's name (and over the star serpent): how it stands against the
-- player's own ⚡ (Speed.challenge), as an icon (UI/Icons name) and a word, both in the tier's
-- colour (docs/design/screens/guardian-labels.md). Green is the prey to go for now; grey, not
-- worth the trip; orange, risky; red, no getting away.
export type ChallengeLook = {
	read color: Color3,
	read icon: string,
	read textKey: keyof<typeof(Strings)>,
}

local CHALLENGES: { [Speed.Challenge]: ChallengeLook } = {
	Weak = { color = rgb(157, 182, 210), icon = "Down", textKey = "guardian.challengeWeak.title" },
	Fair = { color = rgb(67, 204, 95), icon = "Check", textKey = "guardian.challengeFair.title" },
	Strong = { color = rgb(255, 154, 46), icon = "Alert", textKey = "guardian.challengeStrong.title" },
	TooStrong = { color = rgb(255, 90, 100), icon = "Skull", textKey = "guardian.challengeTooStrong.title" },
}
for _, look in CHALLENGES do
	table.freeze(look)
end

return table.freeze({
	KINDS = table.freeze(KINDS),
	POSTS = table.freeze(POSTS),
	EYE_COLORS = table.freeze(EYE_COLORS),
	MODELS = MODELS,
	STATE_MOTION = table.freeze(STATE_MOTION),
	CHALLENGES = table.freeze(CHALLENGES),
	LABEL = LABEL,
})
