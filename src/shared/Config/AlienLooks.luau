--!strict
-- How aliens look: a blob in its tier's color; the top tiers glow so they are worth showing off.
-- Kept apart from AlienConfig so the numbers there load in Lune.

local AlienConfig = require("./AlienConfig")

export type TierLook = {
	read color: Color3,
	-- Glow around the alien: 0 for none.
	read glow: number,
}

local TIERS: { [AlienConfig.TierId]: TierLook } = {
	Common = { color = Color3.fromRGB(190, 196, 210), glow = 0 },
	Uncommon = { color = Color3.fromRGB(110, 225, 130), glow = 0 },
	Rare = { color = Color3.fromRGB(80, 160, 255), glow = 0.9 },
	Epic = { color = Color3.fromRGB(190, 90, 255), glow = 1.3 },
	Legendary = { color = Color3.fromRGB(255, 190, 60), glow = 1.8 },
}

-- Body size, studs (a squat sphere), at scale 1.
local BODY_SIZE = Vector3.new(1.8, 2.1, 1.8)

-- How wide an alien of `scale` (AlienConfig's alien.scale) stands on the floor, studs: what its
-- place on the island makes room for.
local function widthOf(scale: number): number
	return math.max(BODY_SIZE.X, BODY_SIZE.Z) * scale
end

-- The pets' models (assets/aliens, World/AlienModel). A model's size in studs at scale 1 is its
-- size in Blender, where a pet is about as big as the greybox blob above.
local MODELS = table.freeze({
	-- An alien of `alien.scale` 1 stands this big against its Blender model (tier growth taken
	-- out, see TIER_GROWTH).
	SCALE = 1,
	-- Blender grows a pet with its tier (GROWTH in assets/blender/aliens/robo.py, a test keeps
	-- them in step); the game's own growth is alien.scale (decision 068), so this is divided out.
	TIER_GROWTH = table.freeze({ 0.74, 0.86, 1.0, 1.14, 1.3 }),
	-- The scale the dressing is made at (the gallery's, where it was tuned): particles, comets
	-- and the rune are sized for it and grow or shrink with the pet from there.
	DRESS_SCALE = 3.3,
	-- The glow under a pet does not grow with it (a giant's would flood the island): its range,
	-- studs, at most and at least.
	LIGHT_RANGE_MAX = 16,
	LIGHT_RANGE_MIN = 5,
	-- The rune circle on the floor lies this high over the pet's feet, studs, whatever its size: a
	-- small pet's rune scaled with it sank into its place's pad (only its rim showed round the pad,
	-- a plain ring; user, 2026-11-10).
	RUNE_LIFT = 0.08,
	-- Particle and picture textures (assets/fx).
	TEXTURES = table.freeze({
		star = "rbxassetid://113891832030197",
		spark = "rbxassetid://97606944575232",
		bolt = "rbxassetid://108158096824089",
		drop = "rbxassetid://72681449255345",
		bubble = "rbxassetid://86123911810039",
		ember = "rbxassetid://82123783399839",
		flame = "rbxassetid://120732950893778",
		halo = "rbxassetid://100306136441986",
		-- The rune circle under a pet, crisp at 1024 px (assets/fx/rune.svg).
		rune = "rbxassetid://88644383353062",
		-- A jetpack's flame along a beam, tongues of fire that tile and scroll (assets/fx/jet.svg).
		jet = "rbxassetid://105800856225099",
		-- Flipbooks of a cluster of twinkling specks or stars, 4x4 frames that loop
		-- (assets/fx/dustsheet.svg, starsheet.svg).
		dustsheet = "rbxassetid://88657258922832",
		starsheet = "rbxassetid://133175593190677",
		rays = "rbxassetid://75268695809192",
		crest = "rbxassetid://73996927875354",
		smoke = "rbxasset://textures/particles/smoke_main.dds",
	}),
	-- Polished metal for gold and chrome (a material variant of flat maps, assets/fx/pbr-*.svg) and
	-- a meteor's molten shell (the crack texture and its glow mask,
	-- assets/blender/aliens/lava_texture.py). A game server cannot set their texture maps, so
	-- they are made in default.project.json: MaterialService.<METAL_VARIANT> and
	-- ServerStorage.<SKINS_FOLDER>.<LAVA_SKIN>.
	METAL_VARIANT = "PetMetal",
	SKINS_FOLDER = "AlienSkins",
	LAVA_SKIN = "Lava",
})

-- The fine dust round a pet as twinkling clusters (AlienDress): each particle of these layers
-- carries a flipbook of a little cluster of specks or stars (`sheet`, MODELS.TEXTURES), so they
-- emit `rate` as often with each particle `size` times as big, the grains the same size as before.
-- These layers were the most particles a pet had after its wings (2026-11-10).
local FX = table.freeze({
	CLUSTERS = table.freeze({
		Motes = "dustsheet",
		Stardust = "dustsheet",
		Embers = "dustsheet",
		Frost = "starsheet",
		Twinkle = "starsheet",
	} :: { [string]: string }),
	-- 1/4, not 1/6: at a sixth the dust was too thin to see (user, 2026-11-10).
	CLUSTER_RATE = 1 / 4,
	-- The shell the clusters are born on, a share of the pet's box (AlienDress.clusters).
	CLUSTER_SHELL = 0.95,
	CLUSTER_SIZE = 4,
	-- Frames a second of a cluster's twinkle, at least and at most.
	CLUSTER_FRAMERATE = table.freeze({ 10, 14 }),
})

-- The pets' living motion on the client (AlienMotionController), as the gallery had it. Lengths
-- in studs are at the dressing scale and grow with the pet.
local MOTION = table.freeze({
	-- Detail by distance from the camera, studs past the pet's own half width (PetMotion.detail):
	-- within NEAR all of it; within FAR the main effects (MAIN_EFFECTS), no light, motion every
	-- other frame; beyond, the pet stands still with no particles, light or pictures. Leaving a
	-- detail takes DETAIL_MARGIN more, so nothing flickers at the edge. A phone warmed up at once
	-- with thirty pets in full (2026-11-10).
	NEAR = 70,
	-- Within this (past the pet's half width) a pet moves every frame; farther, every other one:
	-- moving the parts is most of the motion's cost, and from there half the steps look the same.
	SMOOTH = 35,
	FAR = 160,
	DETAIL_MARGIN = 10,
	-- The particle layers kept in the middle distance: each pet's main cue (roblox-brain: cut the
	-- secondary layers first). Everything else (sparkles, motes, smoke, sparks) goes.
	MAIN_EFFECTS = table.freeze({
		SoftGlow = true,
		JetFlame = true,
		JetCore = true,
		Flames = true,
		FlameCore = true,
		FireTail = true,
		StarTail = true,
		Radiance = true,
		RadianceHeart = true,
		Bolts = true,
	} :: { [string]: boolean }),
	-- The whole pet bobs this high, studs.
	BOB = 0.45,
	-- A little drone bobs on its loop this high, studs.
	DRONE_BOB = 0.35,
	-- A slime's jelly at rest squashes and stretches this much (a share of its height); a hop lifts
	-- it this high (a share of its height) every few seconds.
	JELLY_REST = 0.035,
	HOP_HEIGHT = 0.12,
	-- Seconds between a slime's hops, between blinks, between a jaw's snaps.
	HOP_EVERY = table.freeze({ 5, 10 }),
	BLINK_EVERY = table.freeze({ 2, 6 }),
	JAW_EVERY = table.freeze({ 1.8, 4.5 }),
	-- Fairy wings (AlienDress.wings): the outer edge draws a glowing stroke as the wing beats,
	-- ribbons between the Dust points along it (~8 a wing), fading over `seconds`, this see-through
	-- where the edge just was. It was a shower of dust from those points and sparkles at the tip:
	-- ~400 particles a winged pet (user, 2026-11-10: the stroke looks better).
	WING_STROKE = table.freeze({
		seconds = 0.3,
		transparency = 0.45,
		brightness = 1.2,
	}),
	-- A jetpack's flame (AlienDress.jets): two camera-facing beams down from each nozzle, the flame
	-- in its colour and a white core, `length` and `width` times the hidden Blender cone's length,
	-- the fire scrolling along them `scroll` times a second. It was two streams of particles (~30
	-- a pet, 2026-11-10).
	JET_FLAME = table.freeze({ length = 1.7, width = 0.5, transparency = 0.15, scroll = 2.5 }),
	JET_CORE = table.freeze({ length = 0.9, width = 0.22, transparency = 0.05, scroll = 3.5 }),
	-- A comet's tail (AlienDress.cometTail): a ribbon `width` times its head's size at the head,
	-- living `seconds` (its length, as the comet flies), this see-through at the head. A meteor's
	-- fireball has a fire tail. They were streams of particles: ~65 a comet (2026-11-10).
	COMET_TAIL = table.freeze({ width = 1.6, seconds = 0.55, transparency = 0.2, brightness = 1.5 }),
	FIRE_TAIL = table.freeze({ width = 1.5, seconds = 0.45, transparency = 0.1, brightness = 1.8 }),
	-- A crab's jaws open this far before they snap shut, radians.
	JAW_OPEN = 0.45,
	-- A pet turns to a player this close (studs past its own size), at most this far (degrees).
	LOOK_RADIUS = 40,
	LOOK_LIMIT_DEGREES = 70,
})

return table.freeze({
	TIERS = table.freeze(TIERS),
	BODY_SIZE = BODY_SIZE,
	widthOf = widthOf,
	MODELS = MODELS,
	FX = FX,
	MOTION = MOTION,
	EYE_SIZE = Vector3.new(0.35, 0.5, 0.2),
	EYE_COLOR = Color3.fromRGB(20, 20, 30),
})
