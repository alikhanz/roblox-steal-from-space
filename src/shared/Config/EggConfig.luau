--!strict
-- Eggs, nests and the theft loop: rarities, loot, grabbing and timings.

local Loot = require("../Domain/Loot")

export type RarityId = "Common" | "Uncommon" | "Rare"
export type SizeId = "Small" | "Medium" | "Large"

export type Rarity = {
	read grabSeconds: number,
	-- Share of the speed stat a medium egg takes away while carried (see Speed.eggWeight).
	read weight: number,
	read color: Color3,
	-- Glow around the egg: 0 for none. Rarer eggs shine brighter and are easier to spot.
	read glow: number,
}

export type Size = {
	-- Multiplies the rarity weight.
	read weightFactor: number,
	-- Multiplies the egg model size.
	read scale: number,
}

local SIZES: { [SizeId]: Size } = {
	Small = { weightFactor = 0.7, scale = 0.8 },
	Medium = { weightFactor = 1, scale = 1 },
	Large = { weightFactor = 1.4, scale = 1.25 },
}

local DEBRIS_BELT_SIZE_LOOT: { Loot.Entry<SizeId> } = {
	{ id = "Small", weight = 50 },
	{ id = "Medium", weight = 35 },
	{ id = "Large", weight = 15 },
}

local RARITIES: { [RarityId]: Rarity } = {
	Common = {
		grabSeconds = 2,
		weight = 0.1,
		color = Color3.fromRGB(226, 230, 240),
		glow = 0,
	},
	Uncommon = {
		grabSeconds = 2.5,
		weight = 0.18,
		color = Color3.fromRGB(120, 235, 130),
		glow = 0.6,
	},
	Rare = {
		grabSeconds = 3,
		weight = 0.28,
		color = Color3.fromRGB(90, 170, 255),
		glow = 1,
	},
}

local DEBRIS_BELT_LOOT: { Loot.Entry<RarityId> } = {
	{ id = "Common", weight = 70 },
	{ id = "Uncommon", weight = 25 },
	{ id = "Rare", weight = 5 },
}

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	SIZES = table.freeze(SIZES),
	DEBRIS_BELT_LOOT = table.freeze(DEBRIS_BELT_LOOT),
	DEBRIS_BELT_SIZE_LOOT = table.freeze(DEBRIS_BELT_SIZE_LOOT),
	-- The guardian's recommended speed is computed for an egg of this size.
	TYPICAL_SIZE = "Medium" :: SizeId,

	-- A player can grab an egg within this distance of it, studs.
	GRAB_REACH = 9,
	-- An empty nest grows a new egg after this long, seconds.
	RESPAWN_SECONDS = 20,
	-- A dropped egg floats this long before flying back to its nest, seconds.
	LOOSE_SECONDS = 10,

	-- Egg size, studs (an elongated sphere).
	EGG_SIZE = Vector3.new(1.6, 2.1, 1.6),

	-- Nest attributes (replicated to clients for the HUD and to the simulation for grabbing).
	NEST_TAG = "Nest",
	NEST_HAS_EGG_ATTRIBUTE = "HasEgg",
	NEST_RARITY_ATTRIBUTE = "Rarity",
	NEST_EGG_POSITION_ATTRIBUTE = "EggPosition",
	-- Name of the egg part inside a nest model.
	NEST_EGG_NAME = "Egg",
	-- Loose eggs floating in space after a drop.
	LOOSE_EGG_TAG = "LooseEgg",
	LOOSE_EGG_RARITY_ATTRIBUTE = "Rarity",

	-- Character attributes.
	GRAB_PROGRESS_ATTRIBUTE = "GrabProgress",
	GRAB_TARGET_ATTRIBUTE = "GrabTarget",
	CARRIED_RARITY_ATTRIBUTE = "CarriedEgg",
	-- Player attribute: eggs delivered this session (stage 3 replaces it with saved data).
	DELIVERED_ATTRIBUTE = "EggsDelivered",
})
