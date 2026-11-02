--!strict
-- Eggs, nests and the theft loop: rarities, loot, grabbing, alert and timings.

local Alert = require("../Domain/Alert")
local Loot = require("../Domain/Loot")

export type RarityId = "Common" | "Uncommon" | "Rare"

export type Rarity = {
	read grabSeconds: number,
	-- Share of top flight speed lost while carrying (see Carry.speedMultiplier).
	read weight: number,
	read color: Color3,
	-- Glow around the egg: 0 for none. Rarer eggs shine brighter and are easier to spot.
	read glow: number,
}

local RARITIES: { [RarityId]: Rarity } = {
	Common = {
		grabSeconds = 0.5,
		weight = 0.1,
		color = Color3.fromRGB(226, 230, 240),
		glow = 0,
	},
	Uncommon = {
		grabSeconds = 0.8,
		weight = 0.18,
		color = Color3.fromRGB(120, 235, 130),
		glow = 0.6,
	},
	Rare = {
		grabSeconds = 1.2,
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

local ALERT: Alert.Tuning = {
	noiseRadius = 45,
	noisePerSecond = 0.9,
	grabPerSecond = 0.6,
	decayPerSecond = 0.12,
}

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	DEBRIS_BELT_LOOT = table.freeze(DEBRIS_BELT_LOOT),
	ALERT = table.freeze(ALERT),

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
	NEST_ALERT_ATTRIBUTE = "Alert",
	NEST_EGG_POSITION_ATTRIBUTE = "EggPosition",
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
