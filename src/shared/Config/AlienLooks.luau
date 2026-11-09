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

return table.freeze({
	TIERS = table.freeze(TIERS),
	BODY_SIZE = BODY_SIZE,
	widthOf = widthOf,
	MODELS = MODELS,
	EYE_SIZE = Vector3.new(0.35, 0.5, 0.2),
	EYE_COLOR = Color3.fromRGB(20, 20, 30),
})
