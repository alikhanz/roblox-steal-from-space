--!strict
-- Eggs, nests and the theft loop: rarities, loot, grabbing and timings. Looks live in EggLooks.
-- Pure Luau: the balance calculator and tests load it in Lune.

local Grab = require("../Domain/Grab")
local Hatch = require("../Domain/Hatch")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type SizeId = "Small" | "Medium" | "Large"

export type Rarity = {
	-- The egg's name, e.g. "Rare egg".
	read nameKey: keyof<typeof(Strings)>,
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

-- The magnetic grab: holding the grab input in reach locks the flyer onto the egg.
local MAGNET: Grab.MagnetTuning = {
	speed = 14,
	holdDistance = 3.5,
	response = 6,
}

local RARITIES: { [RarityId]: Rarity } = {
	-- Common eggs hatch within a couple of minutes so the first aliens (and the first income)
	-- come fast; the rarest take hours.
	Common = {
		nameKey = "egg.common.title",
		grabSeconds = 2,
		weight = 0.1,
		hatchSeconds = { min = 10, max = 2 * 60 },
		luck = 0,
	},
	Uncommon = {
		nameKey = "egg.uncommon.title",
		grabSeconds = 2.5,
		weight = 0.18,
		hatchSeconds = { min = 60, max = 6 * 60 },
		luck = 0.35,
	},
	Rare = {
		nameKey = "egg.rare.title",
		grabSeconds = 3,
		weight = 0.28,
		hatchSeconds = { min = 5 * 60, max = 30 * 60 },
		luck = 0.7,
	},
	Epic = {
		nameKey = "egg.epic.title",
		grabSeconds = 3.5,
		weight = 0.38,
		hatchSeconds = { min = 30 * 60, max = 2 * 60 * 60 },
		luck = 1,
	},
	Legendary = {
		nameKey = "egg.legendary.title",
		grabSeconds = 4,
		weight = 0.5,
		hatchSeconds = { min = 1.5 * 60 * 60, max = 5 * 60 * 60 },
		luck = 1.4,
	},
}

-- From the most common up. Which eggs grow where is in ZoneConfig.
local RARITY_ORDER: { RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	RARITY_ORDER = table.freeze(RARITY_ORDER),
	SIZES = table.freeze(SIZES),
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
	-- Loose eggs floating in space after a drop, and eggs welded to a thief; both carry the
	-- rarity attribute for the client's trail.
	LOOSE_EGG_TAG = "LooseEgg",
	CARRIED_EGG_TAG = "CarriedEgg",
	LOOSE_EGG_RARITY_ATTRIBUTE = "Rarity",
	LOOSE_EGG_SIZE_ATTRIBUTE = "Size",

	-- Character attributes.
	GRAB_PROGRESS_ATTRIBUTE = "GrabProgress",
	GRAB_TARGET_ATTRIBUTE = "GrabTarget",
	CARRIED_RARITY_ATTRIBUTE = "CarriedEgg",
	CARRIED_SIZE_ATTRIBUTE = "CarriedEggSize",
})
