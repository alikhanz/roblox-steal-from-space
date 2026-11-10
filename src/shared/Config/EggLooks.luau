--!strict
-- How eggs look. Kept apart from EggConfig so the numbers there load in Lune (the balance
-- calculator and tests), where Roblox datatypes do not exist.

local EggConfig = require("./EggConfig")

export type RarityLook = {
	-- The rarity's colour wherever it is shown: the trail, sparks, the interface.
	read color: Color3,
	-- Glow around the egg: 0 for none. Rarer eggs shine brighter and are easier to spot.
	read glow: number,
	-- The starry shell (decision 087): its tint (the nebula baked in the mesh is grey, so the
	-- shell takes this colour, deep in its dark swirls) and what it wears. A rarer egg wears more:
	-- stars, then a ring in orbit, then glowing cracks, then a halo.
	read shell: Color3,
	read stars: boolean,
	read orbit: boolean,
	read cracks: boolean,
	read halo: boolean,
}

local RARITIES: { [EggConfig.RarityId]: RarityLook } = {
	Common = {
		color = Color3.fromRGB(226, 230, 240),
		glow = 0,
		shell = Color3.fromRGB(158, 168, 199),
		stars = false,
		orbit = false,
		cracks = false,
		halo = false,
	},
	Uncommon = {
		color = Color3.fromRGB(120, 235, 130),
		glow = 0.6,
		shell = Color3.fromRGB(71, 217, 107),
		stars = true,
		orbit = false,
		cracks = false,
		halo = false,
	},
	Rare = {
		color = Color3.fromRGB(90, 170, 255),
		glow = 1,
		shell = Color3.fromRGB(64, 140, 255),
		stars = true,
		orbit = true,
		cracks = false,
		halo = false,
	},
	Epic = {
		color = Color3.fromRGB(200, 90, 255),
		glow = 1.4,
		shell = Color3.fromRGB(173, 77, 255),
		stars = true,
		orbit = true,
		cracks = true,
		halo = false,
	},
	Legendary = {
		color = Color3.fromRGB(255, 200, 60),
		glow = 2,
		shell = Color3.fromRGB(255, 189, 56),
		stars = true,
		orbit = true,
		cracks = true,
		halo = true,
	},
}

-- Egg size, studs (an elongated sphere), before the size's scale.
local EGG_SIZE = Vector3.new(1.6, 2.1, 1.6)

-- How much higher an egg of `size` sits than a medium one where it rests on something (a nest,
-- a capsule, the floor), studs: every egg stands on its bottom, not its middle (decision 084).
local function liftOf(size: EggConfig.SizeId): number
	return EGG_SIZE.Y / 2 * (EggConfig.SIZES[size].scale - 1)
end

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	EGG_SIZE = EGG_SIZE,
	liftOf = liftOf,

	-- The glowing ribbon behind an egg on the move, in the egg's color. It always faces the
	-- camera, so it is seen from behind too. Width is studs across; lifetime is how long a piece
	-- stays, so length = lifetime x speed.
	CARRIED_TRAIL = table.freeze({ width = 2.4, lifetime = 1.2, brightness = 3, startTransparency = 0 }),
	LOOSE_TRAIL = table.freeze({ width = 1.4, lifetime = 0.6, brightness = 2, startTransparency = 0.1 }),
	-- A meteor egg burns: a scorched shell with lava in its cracks, flames around it scaled by
	-- its size. No stars, ring or halo, whatever its rarity.
	METEOR = table.freeze({
		shell = Color3.fromRGB(107, 71, 61),
		crackColor = Color3.fromRGB(255, 140, 50),
		fireColor = Color3.fromRGB(255, 120, 30),
		fireSecondaryColor = Color3.fromRGB(255, 220, 90),
		fireSize = 4,
		fireHeat = 6,
	}),
	-- The shell is glossy plastic: the nebula is in its vertex colours, which Roblox multiplies by
	-- the part's colour. Stars, cracks and rings are thin, so Neon glows on them without burning
	-- a whole egg white (docs/design/BLENDER_ROBLOX.md, section 2).
	SHELL_MATERIAL = Enum.Material.SmoothPlastic,
	STAR_COLOR = Color3.fromRGB(255, 250, 235),
	-- Cracks, the orbit and the halo: the rarity's colour lightened by this much towards white.
	ACCENT_LIGHTEN = 0.35,
	-- A ring in orbit round the egg, like a planet's: radius in studs of a medium egg (it scales
	-- with the egg), tilted off flat, a little see-through.
	ORBIT = table.freeze({
		radius = 1.35,
		tilt = CFrame.Angles(math.rad(16), 0, math.rad(22)),
		transparency = 0.15,
	}),
	-- The legendary egg's halo: radius, and how far above the egg's top it floats, studs of a
	-- medium egg.
	HALO = table.freeze({
		radius = 0.38,
		gap = 0.35,
		color = Color3.fromRGB(255, 199, 89),
	}),
	-- An egg with extra luck (the star egg) sparkles, wherever it is: in hands, loose, in the
	-- incubator. Greybox.
	LUCKY_SPARKLE_COLOR = Color3.fromRGB(190, 170, 255),
	-- Sparks around a carried egg: they hang behind a thief in flight.
	SPARK_RATE = 45,
	SPARK_LIFETIME = NumberRange.new(0.8, 1.4),
	SPARK_SPEED = NumberRange.new(1, 2.5),
	SPARK_SIZE = 1,
})
