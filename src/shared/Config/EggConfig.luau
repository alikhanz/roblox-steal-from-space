--!strict
-- Eggs, nests and the theft loop: rarities, loot, grabbing and timings. Looks live in EggLooks.
-- Pure Luau: the balance calculator and tests load it in Lune.

local Grab = require("../Domain/Grab")
local Hatch = require("../Domain/Hatch")
local Loot = require("../Domain/Loot")

export type RarityId = "Common" | "Uncommon" | "Rare"
export type SizeId = "Small" | "Medium" | "Large"

export type Rarity = {
	read grabSeconds: number,
	-- Share of the speed stat a medium egg takes away while carried (see Speed.eggWeight).
	read weight: number,
	-- Time in the incubator, rolled between min and max (see Hatch.duration). The rarest eggs of
	-- the game take up to 5 hours.
	read hatchSeconds: Hatch.Range,
	-- Tilts hatch odds toward the top tiers (see Hatch.shiftedWeights); adds up with the size's.
	read luck: number,
}

export type Size = {
	-- Multiplies the rarity weight.
	read weightFactor: number,
	-- Multiplies the egg model size.
	read scale: number,
	-- Tilts hatch odds toward the top tiers; adds up with the rarity's.
	read luck: number,
}

local SIZES: { [SizeId]: Size } = {
	Small = { weightFactor = 0.7, scale = 0.8, luck = 0 },
	Medium = { weightFactor = 1, scale = 1, luck = 0.15 },
	Large = { weightFactor = 1.4, scale = 1.25, luck = 0.3 },
}

local DEBRIS_BELT_SIZE_LOOT: { Loot.Entry<SizeId> } = {
	{ id = "Small", weight = 50 },
	{ id = "Medium", weight = 35 },
	{ id = "Large", weight = 15 },
}

-- The magnetic grab: holding the grab input in reach locks the flyer onto the egg.
local MAGNET: Grab.MagnetTuning = {
	speed = 14,
	holdDistance = 3.5,
	response = 6,
}

local RARITIES: { [RarityId]: Rarity } = {
	Common = {
		grabSeconds = 2,
		weight = 0.1,
		hatchSeconds = { min = 30, max = 10 * 60 },
		luck = 0,
	},
	Uncommon = {
		grabSeconds = 2.5,
		weight = 0.18,
		hatchSeconds = { min = 5 * 60, max = 40 * 60 },
		luck = 0.35,
	},
	Rare = {
		grabSeconds = 3,
		weight = 0.28,
		hatchSeconds = { min = 20 * 60, max = 2 * 60 * 60 },
		luck = 0.7,
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
	MAGNET = table.freeze(MAGNET),

	-- A knocked-out egg flies off at this speed, keeps this share of it per second and tumbles.
	DROP_SPEED = 40,
	DROP_RETENTION_PER_SECOND = 0.1,
	DROP_SPIN_RATE = math.rad(360),

	-- A player can grab an egg within this distance of it, studs.
	GRAB_REACH = 9,
	-- An empty nest grows a new egg after this long, seconds.
	RESPAWN_SECONDS = 20,
	-- A dropped egg nobody touches for this long flies back to its nest, seconds.
	LOOSE_SECONDS = 180,

	-- Nest attributes (replicated to clients for the HUD and to the simulation for grabbing).
	NEST_TAG = "Nest",
	NEST_HAS_EGG_ATTRIBUTE = "HasEgg",
	NEST_RARITY_ATTRIBUTE = "Rarity",
	NEST_SIZE_ATTRIBUTE = "Size",
	NEST_EGG_POSITION_ATTRIBUTE = "EggPosition",
	-- Name of the egg part inside a nest model.
	NEST_EGG_NAME = "Egg",
	-- Loose eggs floating in space after a drop.
	LOOSE_EGG_TAG = "LooseEgg",
	LOOSE_EGG_RARITY_ATTRIBUTE = "Rarity",
	LOOSE_EGG_SIZE_ATTRIBUTE = "Size",

	-- Character attributes.
	GRAB_PROGRESS_ATTRIBUTE = "GrabProgress",
	GRAB_TARGET_ATTRIBUTE = "GrabTarget",
	CARRIED_RARITY_ATTRIBUTE = "CarriedEgg",
	CARRIED_SIZE_ATTRIBUTE = "CarriedEggSize",
	-- Player attribute: eggs delivered this session (stage 3 replaces it with saved data).
	DELIVERED_ATTRIBUTE = "EggsDelivered",
})
