--!strict
-- How eggs look. Kept apart from EggConfig so the numbers there load in Lune (the balance
-- calculator and tests), where Roblox datatypes do not exist.
--
-- An egg is a ceramic capsule (decision 088) from the egg kit (World/EggKit): its plastic body
-- with the colours baked in and what each rarity wears are in the meshes
-- (assets/blender/eggs/egg_kit.py): common is plain matte grey; uncommon a pearl capsule with a
-- coloured cap and a lit seam; rare adds a lit window and foot ring; epic glowing stripes on the
-- cap, an antenna and an orbit; legendary a gold crowned cap, two orbits and a halo. A meteor egg
-- wears the same on a scorched capsule, glowing lava. Here: what the game paints on them.

local EggConfig = require("./EggConfig")

export type RarityLook = {
	-- The rarity's colour wherever it is shown: the trail, sparks, the interface, and what glows
	-- on the egg (its Neon piece). The caps baked in the kit match these.
	read color: Color3,
	-- A light round the egg: 0 for none. Lights are dear on phones and the Neon already shows the
	-- rarity: only the rarest eggs carry a faint one, so they are spotted from afar.
	read glow: number,
	-- A nest's beacon (EggBeaconController): a column of light through the egg, longer the rarer
	-- it is, seen only nearby (BEACON.range). None for a common egg: no beacon reads as common.
	read beacon: BeaconLook?,
}

export type BeaconLook = {
	-- The column: studs it runs above the egg (as many below), studs wide (plus a few pixels:
	-- BEACON.glowMinPixels).
	read height: number,
	read width: number,
}

local RARITIES: { [EggConfig.RarityId]: RarityLook } = {
	Common = { color = Color3.fromRGB(226, 230, 240), glow = 0 },
	Uncommon = {
		color = Color3.fromRGB(120, 235, 130),
		glow = 0,
		beacon = { height = 22, width = 1.6 },
	},
	Rare = {
		color = Color3.fromRGB(90, 170, 255),
		glow = 0,
		beacon = { height = 38, width = 2.2 },
	},
	Epic = {
		color = Color3.fromRGB(200, 90, 255),
		glow = 0.6,
		beacon = { height = 58, width = 2.8 },
	},
	Legendary = {
		color = Color3.fromRGB(255, 200, 60),
		glow = 1,
		beacon = { height = 85, width = 3.6 },
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
	-- A meteor egg burns: a scorched capsule (baked in the kit) with lava in its seam, window and
	-- cracks, flames around it scaled by its size. No antenna, ring or halo, whatever its rarity.
	METEOR = table.freeze({
		lava = Color3.fromRGB(255, 120, 30),
		fireColor = Color3.fromRGB(255, 120, 30),
		fireSecondaryColor = Color3.fromRGB(255, 220, 90),
		fireSize = 4,
		fireHeat = 6,
	}),
	-- The capsule's body: plastic, white, so the baked colours show as they are. Its Neon piece is
	-- thin (seam, window, tip, rings), so it glows without burning the egg white under Bloom
	-- (docs/design/BLENDER_ROBLOX.md, section 2).
	SHELL_MATERIAL = Enum.Material.SmoothPlastic,
	-- The legendary cap: polished gold, as the pets' (AlienDress); bright and saturated, or dark
	-- space turns it olive.
	GOLD = Color3.fromRGB(255, 190, 45),
	-- Nest beacons (EggBeaconController).
	BEACON = table.freeze({
		-- How far off a column shows, studs: only the eggs around you, not the whole map (user,
		-- 2026-11-10: a map-wide radar is "слишком имба", an idea to sell later, docs/IDEAS.md).
		range = 500,
		-- The column: a coloured glow round a core whitened by this much, each at least this many
		-- pixels wide on top of its width in studs (a Beam thinned to nothing at a distance);
		-- their transparency at the egg (both fade out to the ends). Dense: a see-through column
		-- got lost against the bright nebulae (Studio, 2026-11-10).
		glowMinPixels = 6,
		coreMinPixels = 2,
		coreWidth = 0.35,
		glowTransparency = 0.2,
		coreTransparency = 0,
		coreWhiten = 0.6,
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
