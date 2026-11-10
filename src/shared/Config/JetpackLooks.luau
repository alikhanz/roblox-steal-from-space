--!strict
-- How each jetpack looks (decision 089): its body is a model of its own (assets/blender/jetpacks,
-- ServerStorage.Jetpacks in the place; the colours are baked in its meshes), its flame a jet of
-- beams from each nozzle. The flame changes in four steps of three jetpacks — fire, plasma, shock
-- diamonds, exotic — and grows longer and brighter with every jetpack, in its own colour, so a
-- better jetpack is visible from across the station. Both marks of a jetpack
-- (Upgrades.jetpackModel) look alike. The names live in UpgradeConfig.JETPACK_NAME_KEYS.

local UpgradeConfig = require("./UpgradeConfig")
local Upgrades = require("../Domain/Upgrades")

export type Looks = {
	-- The greybox's colours, for a place without the models (JetpackModel).
	read bodyColor: Color3,
	read accentColor: Color3,
	-- The flame: pale at the nozzle, its colour further out (also the shop's swatch).
	read flameStart: Color3,
	read flameEnd: Color3,
	read lightColor: Color3,
	-- Which of STEPS the flame is.
	read step: number,
	-- The jet at full thrust on a model of scale 1: length and width at the nozzle, studs.
	read length: number,
	read width: number,
	-- Beam.Brightness at full thrust: over 1 keeps it bright in daylight under Realistic light.
	read brightness: number,
}

-- One kind of flame: the jet's texture and scroll (studs of texture a second), the core's, and how
-- long and wide the core is next to the jet.
export type Step = {
	read jet: string,
	read jetScroll: number,
	read core: string,
	read coreScroll: number,
	read coreLength: number,
	read coreWidth: number,
}

-- Beam textures (assets/fx, white on transparency; `lune run icons` renders them). Until a texture
-- is uploaded its id is empty and FALLBACK_TEXTURE stands in.
local TEXTURES = table.freeze({
	core = "rbxassetid://130565237636281", -- assets/fx/jet-core.svg
	fire = "rbxassetid://131491955518269", -- assets/fx/jet-fire.svg
	plasma = "rbxassetid://74020183030100", -- assets/fx/jet-plasma.svg
	diamonds = "rbxassetid://81011633768379", -- assets/fx/jet-diamonds.svg
	exotic = "rbxassetid://87198272606940", -- assets/fx/jet-exotic.svg
})
-- The pets' jetpack flame (assets/fx/jet.svg, AlienLooks).
local FALLBACK_TEXTURE = "rbxassetid://105800856225099"

local function texture(name: string): string
	local id = (TEXTURES :: any)[name]
	return if id ~= "" then id else FALLBACK_TEXTURE
end

local STEPS: { Step } = {
	-- Fire (Starter, Spark, Comet): tongues of flame round a short white core.
	{
		jet = texture("fire"),
		jetScroll = 3,
		core = texture("core"),
		coreScroll = 4,
		coreLength = 0.45,
		coreWidth = 0.35,
	},
	-- Plasma (Plasma, Ion, Pulsar): an even jet, bright rings running out of the nozzle.
	{
		jet = texture("plasma"),
		jetScroll = 2.2,
		core = texture("core"),
		coreScroll = 5,
		coreLength = 0.6,
		coreWidth = 0.35,
	},
	-- Shock diamonds (Quasar, Antimatter, Singularity): a soft jet, bright beads along the core
	-- that barely move.
	{
		jet = texture("core"),
		jetScroll = 4,
		core = texture("diamonds"),
		coreScroll = 0.3,
		coreLength = 0.75,
		coreWidth = 0.5,
	},
	-- Exotic (Hyperdrive, Wormhole, Infinity): strands winding round the jet.
	{
		jet = texture("exotic"),
		jetScroll = 2.6,
		core = texture("core"),
		coreScroll = 5,
		coreLength = 0.6,
		coreWidth = 0.35,
	},
}
for _, step in STEPS do
	table.freeze(step)
end

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
		step = 1,
		length = 2.2,
		width = 0.55,
		brightness = 2,
	},
	-- Spark: warmer and a touch brighter.
	{
		bodyColor = rgb(220, 214, 196),
		accentColor = rgb(255, 170, 60),
		flameStart = rgb(255, 250, 200),
		flameEnd = rgb(255, 140, 40),
		lightColor = rgb(255, 170, 80),
		step = 1,
		length = 2.5,
		width = 0.6,
		brightness = 2.3,
	},
	-- Comet: blue.
	{
		bodyColor = rgb(120, 160, 230),
		accentColor = rgb(160, 230, 255),
		flameStart = rgb(220, 245, 255),
		flameEnd = rgb(80, 160, 255),
		lightColor = rgb(120, 180, 255),
		step = 1,
		length = 2.8,
		width = 0.62,
		brightness = 2.6,
	},
	-- Plasma: violet.
	{
		bodyColor = rgb(170, 120, 230),
		accentColor = rgb(240, 160, 255),
		flameStart = rgb(255, 220, 255),
		flameEnd = rgb(200, 60, 255),
		lightColor = rgb(210, 100, 255),
		step = 2,
		length = 3,
		width = 0.62,
		brightness = 2.8,
	},
	-- Ion: teal.
	{
		bodyColor = rgb(80, 220, 200),
		accentColor = rgb(160, 255, 230),
		flameStart = rgb(230, 255, 250),
		flameEnd = rgb(0, 220, 180),
		lightColor = rgb(60, 240, 200),
		step = 2,
		length = 3.3,
		width = 0.66,
		brightness = 3.1,
	},
	-- Pulsar: white-blue.
	{
		bodyColor = rgb(240, 240, 255),
		accentColor = rgb(255, 255, 255),
		flameStart = rgb(255, 255, 255),
		flameEnd = rgb(120, 180, 255),
		lightColor = rgb(200, 220, 255),
		step = 2,
		length = 3.6,
		width = 0.7,
		brightness = 3.4,
	},
	-- Quasar: gold and red.
	{
		bodyColor = rgb(255, 140, 60),
		accentColor = rgb(255, 240, 120),
		flameStart = rgb(255, 255, 200),
		flameEnd = rgb(255, 60, 0),
		lightColor = rgb(255, 120, 40),
		step = 3,
		length = 3.9,
		width = 0.74,
		brightness = 3.7,
	},
	-- Antimatter: black tanks, magenta fire.
	{
		bodyColor = rgb(40, 30, 60),
		accentColor = rgb(255, 40, 120),
		flameStart = rgb(255, 150, 220),
		flameEnd = rgb(120, 0, 255),
		lightColor = rgb(200, 40, 255),
		step = 3,
		length = 4.2,
		width = 0.78,
		brightness = 4,
	},
	-- Singularity: dark grey, a deep blue flame pulled thin.
	{
		bodyColor = rgb(60, 64, 80),
		accentColor = rgb(80, 120, 255),
		flameStart = rgb(200, 220, 255),
		flameEnd = rgb(30, 40, 200),
		lightColor = rgb(70, 100, 255),
		step = 3,
		length = 4.5,
		width = 0.82,
		brightness = 4.3,
	},
	-- Hyperdrive: bright cyan streaks.
	{
		bodyColor = rgb(210, 235, 245),
		accentColor = rgb(0, 255, 255),
		flameStart = rgb(240, 255, 255),
		flameEnd = rgb(0, 200, 255),
		lightColor = rgb(80, 255, 255),
		step = 4,
		length = 4.4,
		width = 0.55,
		brightness = 4.6,
	},
	-- Wormhole: green and violet swirling.
	{
		bodyColor = rgb(50, 30, 70),
		accentColor = rgb(120, 255, 140),
		flameStart = rgb(200, 255, 210),
		flameEnd = rgb(150, 40, 255),
		lightColor = rgb(120, 255, 160),
		step = 4,
		length = 4.7,
		width = 0.58,
		brightness = 4.9,
	},
	-- Infinity: white-gold, the brightest of all.
	{
		bodyColor = rgb(255, 245, 220),
		accentColor = rgb(255, 215, 80),
		flameStart = rgb(255, 255, 255),
		flameEnd = rgb(255, 190, 40),
		lightColor = rgb(255, 230, 140),
		step = 4,
		length = 5,
		width = 0.62,
		brightness = 5.2,
	},
}
assert(#LEVELS == #UpgradeConfig.JETPACK_NAME_KEYS, "JetpackLooks.LEVELS and UpgradeConfig.JETPACK_NAME_KEYS differ")
for _, level in LEVELS do
	table.freeze(level)
end

local JetpackLooks = {}

JetpackLooks.LEVELS = table.freeze(LEVELS)
JetpackLooks.STEPS = table.freeze(STEPS)

-- How the model's parts are painted (export_jetpacks.py joins each jetpack into these four; their
-- colours ride in the vertices, so the parts are white). Metal wears the pets' metal variant
-- (MaterialService.PetMetal, decision 076) where the place has it.
export type PartLook = {
	read material: Enum.Material,
	read reflectance: number,
	read transparency: number,
	read metal: boolean,
	read shadow: boolean,
}
JetpackLooks.PARTS = table.freeze({
	Shell = table.freeze({
		material = Enum.Material.SmoothPlastic,
		reflectance = 0.08,
		transparency = 0,
		metal = false,
		shadow = true,
	}),
	Metal = table.freeze({
		material = Enum.Material.SmoothPlastic,
		reflectance = 0,
		transparency = 0,
		metal = true,
		shadow = true,
	}),
	Glow = table.freeze({
		material = Enum.Material.Neon,
		reflectance = 0,
		transparency = 0,
		metal = false,
		shadow = false,
	}),
	Glass = table.freeze({
		material = Enum.Material.Glass,
		reflectance = 0.1,
		transparency = 0.55,
		metal = false,
		shadow = false,
	}),
}) :: { [string]: PartLook }
JetpackLooks.METAL_VARIANT = "PetMetal"

-- Which jetpack a level wears, 0 (Starter) to the last: both marks of a jetpack look the same.
function JetpackLooks.jetpackOf(level: number): number
	local top = Upgrades.jetpackMaxLevel(UpgradeConfig.TUNING)
	local jetpack = Upgrades.jetpackModel(math.clamp(math.floor(level), 0, top), UpgradeConfig.TUNING)
	return math.clamp(jetpack, 0, #LEVELS - 1)
end

-- The look of a jetpack level: its jetpack's.
function JetpackLooks.forLevel(level: number): Looks
	return LEVELS[JetpackLooks.jetpackOf(level) + 1]
end

function JetpackLooks.stepOf(looks: Looks): Step
	return STEPS[math.clamp(looks.step, 1, #STEPS)]
end

return table.freeze(JetpackLooks)
