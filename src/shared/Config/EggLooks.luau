--!strict
-- How eggs look. Kept apart from EggConfig so the numbers there load in Lune (the balance
-- calculator and tests), where Roblox datatypes do not exist.

local EggConfig = require("./EggConfig")

export type RarityLook = {
	read color: Color3,
	-- Glow around the egg: 0 for none. Rarer eggs shine brighter and are easier to spot.
	read glow: number,
}

local RARITIES: { [EggConfig.RarityId]: RarityLook } = {
	Common = { color = Color3.fromRGB(226, 230, 240), glow = 0 },
	Uncommon = { color = Color3.fromRGB(120, 235, 130), glow = 0.6 },
	Rare = { color = Color3.fromRGB(90, 170, 255), glow = 1 },
	Epic = { color = Color3.fromRGB(200, 90, 255), glow = 1.4 },
	Legendary = { color = Color3.fromRGB(255, 200, 60), glow = 2 },
}

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	-- Egg size, studs (an elongated sphere), before the size's scale.
	EGG_SIZE = Vector3.new(1.6, 2.1, 1.6),

	-- The glowing ribbon behind an egg on the move, in the egg's color. It always faces the
	-- camera, so it is seen from behind too. Width is studs across; lifetime is how long a piece
	-- stays, so length = lifetime x speed.
	CARRIED_TRAIL = table.freeze({ width = 2.4, lifetime = 1.2, brightness = 3, startTransparency = 0 }),
	LOOSE_TRAIL = table.freeze({ width = 1.4, lifetime = 0.6, brightness = 2, startTransparency = 0.1 }),
	-- A meteor egg burns: flames around it, scaled by its size. Greybox; its real look comes with
	-- the art pass.
	METEOR = table.freeze({
		fireColor = Color3.fromRGB(255, 120, 30),
		fireSecondaryColor = Color3.fromRGB(255, 220, 90),
		fireSize = 4,
		fireHeat = 6,
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
