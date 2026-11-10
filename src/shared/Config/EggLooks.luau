--!strict
-- How eggs look. Kept apart from EggConfig so the numbers there load in Lune (the balance
-- calculator and tests), where Roblox datatypes do not exist.

local EggConfig = require("./EggConfig")

export type RarityLook = {
	-- The rarity's colour wherever it is shown: the trail, sparks, the interface; and what glows
	-- on the egg (the seam, the window, the antenna's tip, the orbit).
	read color: Color3,
	-- Glow around the egg: 0 for none. Rarer eggs shine brighter and are easier to spot.
	read glow: number,
	-- The capsule (decision 087): a pearl base and a cap in this colour; a gold cap is polished
	-- metal. A rarer egg wears more: a lit seam, then a lit window, then an antenna and a ring in
	-- orbit, then a gold cap and a halo.
	read cap: Color3,
	read gold: boolean,
	read seamLit: boolean,
	read windowLit: boolean,
	read antenna: boolean,
	read orbit: boolean,
	read halo: boolean,
}

local PEARL = Color3.fromRGB(236, 239, 245)

local RARITIES: { [EggConfig.RarityId]: RarityLook } = {
	Common = {
		color = Color3.fromRGB(226, 230, 240),
		glow = 0,
		cap = PEARL,
		gold = false,
		seamLit = false,
		windowLit = false,
		antenna = false,
		orbit = false,
		halo = false,
	},
	Uncommon = {
		color = Color3.fromRGB(120, 235, 130),
		glow = 0.6,
		cap = Color3.fromRGB(71, 217, 107),
		gold = false,
		seamLit = true,
		windowLit = false,
		antenna = false,
		orbit = false,
		halo = false,
	},
	Rare = {
		color = Color3.fromRGB(90, 170, 255),
		glow = 1,
		cap = Color3.fromRGB(64, 140, 255),
		gold = false,
		seamLit = true,
		windowLit = true,
		antenna = false,
		orbit = false,
		halo = false,
	},
	Epic = {
		color = Color3.fromRGB(200, 90, 255),
		glow = 1.4,
		cap = Color3.fromRGB(173, 77, 255),
		gold = false,
		seamLit = true,
		windowLit = true,
		antenna = true,
		orbit = true,
		halo = false,
	},
	Legendary = {
		color = Color3.fromRGB(255, 200, 60),
		glow = 2,
		-- Bright and saturated: metal shows what it reflects, and dark space turns a dull gold
		-- olive (as the pets' gold, AlienDress).
		cap = Color3.fromRGB(255, 190, 45),
		gold = true,
		seamLit = true,
		windowLit = true,
		antenna = true,
		orbit = true,
		halo = true,
	},
}

-- Egg size, studs, before the size's scale (a medium egg: the kit is modelled at this size).
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
	-- A meteor egg burns: a scorched capsule with lava in its seam, window and cracks, flames
	-- around it scaled by its size. No antenna, ring or halo, whatever its rarity.
	METEOR = table.freeze({
		shell = Color3.fromRGB(90, 58, 48),
		lava = Color3.fromRGB(255, 120, 30),
		fireColor = Color3.fromRGB(255, 120, 30),
		fireSecondaryColor = Color3.fromRGB(255, 220, 90),
		fireSize = 4,
		fireHeat = 6,
	}),
	-- The capsule's shell is glossy plastic in the kiosks' pearl (the station's capsule kiosks);
	-- the foot and the window's rim are darker in the kit's vertex colours. What glows is thin
	-- (seam, window, tip, rings): Neon there, never a whole egg, which burns white under Bloom
	-- (docs/design/BLENDER_ROBLOX.md, section 2).
	PEARL = PEARL,
	SHELL_MATERIAL = Enum.Material.SmoothPlastic,
	-- A seam or window not lit yet: dark plastic.
	UNLIT = Color3.fromRGB(64, 66, 77),
	ANTENNA = Color3.fromRGB(77, 82, 97),
	-- A ring round the egg like a gyroscope: radius in studs of a medium egg (it scales with the
	-- egg), turned to stand nearly upright round it. Solid: Roblox hides see-through parts behind
	-- Glass, and a see-through ring vanished inside the incubator's glass capsule.
	ORBIT = table.freeze({
		radius = 1.1,
		tilt = CFrame.Angles(math.rad(72), 0, math.rad(14)),
		transparency = 0,
	}),
	-- The legendary egg's halo: radius, and how far above the egg's top it floats (clear of the
	-- antenna), studs of a medium egg.
	HALO = table.freeze({
		radius = 0.36,
		gap = 0.55,
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
