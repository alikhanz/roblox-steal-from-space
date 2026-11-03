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
})
