--!strict
-- How each jetpack looks: tank colors and the flame. Every jetpack burns a different color and
-- brighter than the last, so a better jetpack is visible from across the station; its marks
-- (Upgrades.jetpackModel) look alike. The names live in UpgradeConfig.JETPACK_NAME_KEYS.

local UpgradeConfig = require("./UpgradeConfig")
local Upgrades = require("../Domain/Upgrades")

export type Looks = {
	read bodyColor: Color3,
	read accentColor: Color3,
	read flameStart: Color3,
	read flameEnd: Color3,
	read lightColor: Color3,
	-- Multiplies the flame's particle rate and the light's brightness.
	read flameScale: number,
	-- Multiplies the flame's particle size.
	read sizeScale: number,
}

local rgb = Color3.fromRGB

-- Level 0 first.
local LEVELS: { Looks } = {
	-- Starter: steel tanks, a plain orange flame.
	{
		bodyColor = rgb(196, 202, 214),
		accentColor = rgb(90, 200, 255),
		flameStart = rgb(255, 236, 160),
		flameEnd = rgb(255, 96, 30),
		lightColor = rgb(255, 150, 70),
		flameScale = 1,
		sizeScale = 1,
	},
	-- Spark: warmer and a touch brighter.
	{
		bodyColor = rgb(220, 214, 196),
		accentColor = rgb(255, 170, 60),
		flameStart = rgb(255, 250, 200),
		flameEnd = rgb(255, 140, 40),
		lightColor = rgb(255, 170, 80),
		flameScale = 1.15,
		sizeScale = 1.08,
	},
	-- Comet: blue.
	{
		bodyColor = rgb(120, 160, 230),
		accentColor = rgb(160, 230, 255),
		flameStart = rgb(220, 245, 255),
		flameEnd = rgb(80, 160, 255),
		lightColor = rgb(120, 180, 255),
		flameScale = 1.3,
		sizeScale = 1.16,
	},
	-- Plasma: violet.
	{
		bodyColor = rgb(170, 120, 230),
		accentColor = rgb(240, 160, 255),
		flameStart = rgb(255, 220, 255),
		flameEnd = rgb(200, 60, 255),
		lightColor = rgb(210, 100, 255),
		flameScale = 1.45,
		sizeScale = 1.24,
	},
	-- Ion: teal.
	{
		bodyColor = rgb(80, 220, 200),
		accentColor = rgb(160, 255, 230),
		flameStart = rgb(230, 255, 250),
		flameEnd = rgb(0, 220, 180),
		lightColor = rgb(60, 240, 200),
		flameScale = 1.6,
		sizeScale = 1.32,
	},
	-- Pulsar: white-blue.
	{
		bodyColor = rgb(240, 240, 255),
		accentColor = rgb(255, 255, 255),
		flameStart = rgb(255, 255, 255),
		flameEnd = rgb(120, 180, 255),
		lightColor = rgb(200, 220, 255),
		flameScale = 1.8,
		sizeScale = 1.42,
	},
	-- Quasar: gold and red.
	{
		bodyColor = rgb(255, 140, 60),
		accentColor = rgb(255, 240, 120),
		flameStart = rgb(255, 255, 200),
		flameEnd = rgb(255, 60, 0),
		lightColor = rgb(255, 120, 40),
		flameScale = 2,
		sizeScale = 1.52,
	},
	-- Antimatter: black tanks, magenta fire.
	{
		bodyColor = rgb(40, 30, 60),
		accentColor = rgb(255, 40, 120),
		flameStart = rgb(255, 150, 220),
		flameEnd = rgb(120, 0, 255),
		lightColor = rgb(200, 40, 255),
		flameScale = 2.3,
		sizeScale = 1.65,
	},
}
assert(#LEVELS == #UpgradeConfig.JETPACK_NAME_KEYS, "JetpackLooks.LEVELS and UpgradeConfig.JETPACK_NAME_KEYS differ")
for _, level in LEVELS do
	table.freeze(level)
end

local JetpackLooks = {}

JetpackLooks.LEVELS = table.freeze(LEVELS)

-- Flame particle size over its life at scale 1: wide at the nozzle, tapering out.
JetpackLooks.FLAME_SIZE_KEYPOINTS = table.freeze({
	{ time = 0, size = 0.9 },
	{ time = 0.4, size = 0.6 },
	{ time = 1, size = 0.1 },
})

-- The look of a jetpack level: its jetpack's (both marks of a jetpack look the same).
function JetpackLooks.forLevel(level: number): Looks
	local top = Upgrades.jetpackMaxLevel(UpgradeConfig.TUNING)
	local jetpack = Upgrades.jetpackModel(math.clamp(math.floor(level), 0, top), UpgradeConfig.TUNING)
	return LEVELS[math.clamp(jetpack + 1, 1, #LEVELS)]
end

function JetpackLooks.flameSize(scale: number): NumberSequence
	local keypoints = {}
	for _, keypoint in JetpackLooks.FLAME_SIZE_KEYPOINTS do
		table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.time, keypoint.size * scale))
	end
	return NumberSequence.new(keypoints)
end

return table.freeze(JetpackLooks)
