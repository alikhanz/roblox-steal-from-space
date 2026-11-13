--!strict
-- How eggs look. Kept apart from EggConfig so the numbers there load in Lune (the balance
-- calculator and tests), where Roblox datatypes do not exist.
--
-- An egg is a cut gem (decision 122) from the egg kit (World/EggKit): a faceted shell in its
-- rarity's colour with a girdle of light, and what its rarity and kind add (Domain/EggPieces): a
-- tip, fins, an orbit, a gold crown; a meteor egg is scorched, with lava cracks and a flame; the
-- star egg is night blue with a gold star and specks. The kit's shapes carry no colour: here is
-- what the game paints on them (GEM).

local EggConfig = require("./EggConfig")
local EggKind = require("../Domain/EggKind")

export type RarityLook = {
	-- The rarity's colour wherever it is shown: the trail, sparks, the interface, and on the egg
	-- its shell and its light (Domain/EggPieces: Shell, Line).
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

-- How far above its centre a medium gem egg reaches with what it wears on top, studs
-- (the kit's export prints them: assets/blender/lowpoly/export_eggs_lowpoly.py): the tip, the
-- meteor's flame, the star egg's star. Its box (EGG_SIZE) ends at 1.05.
local REACH: { [EggKind.Kind]: number } = { Normal = 1.37, Meteor = 1.55, Star = 1.73 }

-- How far above its centre an egg of `kind` `height` studs tall reaches: what hangs over an egg
-- (its chip) stands above this, not above its box.
local function reachOf(kind: EggKind.Kind, height: number): number
	return REACH[kind] * height / EGG_SIZE.Y
end

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	EGG_SIZE = EGG_SIZE,
	liftOf = liftOf,
	reachOf = reachOf,

	-- The glowing ribbon behind an egg on the move, in the egg's color. It always faces the
	-- camera, so it is seen from behind too. Width is studs across; lifetime is how long a piece
	-- stays, so length = lifetime x speed.
	CARRIED_TRAIL = table.freeze({ width = 2.4, lifetime = 1.2, brightness = 3, startTransparency = 0 }),
	LOOSE_TRAIL = table.freeze({ width = 1.4, lifetime = 0.6, brightness = 2, startTransparency = 0.1 }),
	-- A meteor egg burns: a scorched shell with lava in its girdle and cracks, a flame for a tip,
	-- flames around it scaled by its size.
	METEOR = table.freeze({
		lava = Color3.fromRGB(255, 120, 30),
		fireColor = Color3.fromRGB(255, 120, 30),
		fireSecondaryColor = Color3.fromRGB(255, 220, 90),
		fireSize = 4,
		fireHeat = 6,
	}),
	-- The plastic pieces (shell, fins, crown, a common egg's girdle). The Neon pieces are thin
	-- (girdle, tip, orbit, cracks, star), so they glow without burning the egg white under Bloom
	-- (docs/design/BLENDER_ROBLOX.md, section 2).
	SHELL_MATERIAL = Enum.Material.SmoothPlastic,
	-- The legendary crown: polished gold, as the pets' (AlienDress); bright and saturated, or dark
	-- space turns it olive.
	GOLD = Color3.fromRGB(255, 190, 45),
	-- How each paint of the gem egg (Domain/EggPieces) is coloured, on top of the rarity's colour.
	GEM = table.freeze({
		-- A meteor egg's shell: its rarity's colour scorched this far towards char.
		char = Color3.fromRGB(52, 40, 38),
		charMix = 0.72,
		-- Fins: the rarity's colour this far towards dark.
		dark = Color3.fromRGB(40, 42, 56),
		finMix = 0.35,
		-- A common egg's girdle is plain plastic, its colour this far towards white (no light).
		commonLineWhiten = 0.4,
		-- The meteor's flame.
		flame = Color3.fromRGB(255, 170, 60),
		-- The star egg: night-blue shell, gold light.
		starShell = Color3.fromRGB(34, 36, 96),
		starGold = Color3.fromRGB(255, 214, 110),
	}),
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
