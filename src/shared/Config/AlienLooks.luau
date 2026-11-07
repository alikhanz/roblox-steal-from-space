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

return table.freeze({
	TIERS = table.freeze(TIERS),
	BODY_SIZE = BODY_SIZE,
	widthOf = widthOf,
	EYE_SIZE = Vector3.new(0.35, 0.5, 0.2),
	EYE_COLOR = Color3.fromRGB(20, 20, 30),
})
