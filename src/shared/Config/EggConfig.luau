--!strict
-- Eggs, nests and the theft loop: rarities, loot, grabbing and timings. Looks live in EggLooks.
-- Pure Luau: the balance calculator and tests load it in Lune.

local Grab = require("../Domain/Grab")
local Hatch = require("../Domain/Hatch")
local Loot = require("../Domain/Loot")
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
	-- the game take up to 4 hours.
	read hatchSeconds: Hatch.Range,
	-- What a medium egg hatches into (decision 113): the alien tier of its own name, or one tier
	-- down or up with these chances (Hatch.ladder). The size scales them (Size).
	read hatchStep: Hatch.Step,
}

export type Size = {
	-- Multiplies the rarity weight.
	read weightFactor: number,
	-- Multiplies the egg model size.
	read scale: number,
	-- Multiply the rarity's chances of hatching one tier down and one tier up (Hatch.scaled).
	read hatchDownFactor: number,
	read hatchUpFactor: number,
}

local SIZES: { [SizeId]: Size } = {
	-- Scales set apart (decision 084): a large egg is plainly the bigger prize, as in games like it.
	-- A large egg climbs twice as often and falls half as often as a medium one; a small one
	-- climbs half as often and falls one and a half times as often (decision 113).
	Small = { weightFactor = 0.7, scale = 0.65, hatchDownFactor = 1.5, hatchUpFactor = 0.5 },
	Medium = { weightFactor = 1, scale = 1, hatchDownFactor = 1, hatchUpFactor = 1 },
	Large = { weightFactor = 1.4, scale = 1.5, hatchDownFactor = 0.5, hatchUpFactor = 2 },
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
		hatchStep = { down = 0, up = 0.25 },
	},
	Uncommon = {
		nameKey = "egg.uncommon.title",
		grabSeconds = 2.5,
		weight = 0.18,
		hatchSeconds = { min = 60, max = 6 * 60 },
		hatchStep = { down = 0.2, up = 0.2 },
	},
	Rare = {
		nameKey = "egg.rare.title",
		grabSeconds = 3,
		weight = 0.28,
		hatchSeconds = { min = 5 * 60, max = 30 * 60 },
		hatchStep = { down = 0.2, up = 0.15 },
	},
	Epic = {
		nameKey = "egg.epic.title",
		grabSeconds = 3.5,
		weight = 0.38,
		hatchSeconds = { min = 30 * 60, max = 2 * 60 * 60 },
		hatchStep = { down = 0.15, up = 0.1 },
	},
	Legendary = {
		nameKey = "egg.legendary.title",
		grabSeconds = 4,
		weight = 0.5,
		hatchSeconds = { min = 2 * 60 * 60, max = 4 * 60 * 60 },
		hatchStep = { down = 0.2, up = 0 },
	},
}

-- From the most common up. Which eggs grow where is in ZoneConfig. Egg rarities are named as
-- the alien tiers (AlienConfig.TIER_ORDER, the same order: a test keeps them in step), so the
-- hatch odds below list tiers by these ids.
local RARITY_ORDER: { RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- The hatch odds of every rarity and size (Hatch.ladder), worked out once.
local HATCH_ODDS: { [RarityId]: { [SizeId]: { Loot.Entry<RarityId> } } } = {}
for position, rarity in RARITY_ORDER do
	local bySize: { [SizeId]: { Loot.Entry<RarityId> } } = {}
	for sizeId, size in SIZES do
		local step = Hatch.scaled(RARITIES[rarity].hatchStep, size.hatchDownFactor, size.hatchUpFactor)
		bySize[sizeId] = Hatch.ladder(RARITY_ORDER, position, step)
	end
	HATCH_ODDS[rarity] = table.freeze(bySize)
end

-- The size an egg hatches as: a lucky egg (one with luck, the star egg: EggRecord.luck) counts as
-- a large one, whatever its own size (decision 113).
local function oddsSize(size: SizeId, luck: number?): SizeId
	return if luck and luck > 0 then "Large" else size
end

-- What an egg hatches into: alien tiers (named as the rarities) and their weights.
local function hatchEntries(rarity: RarityId, size: SizeId, luck: number?): { Loot.Entry<RarityId> }
	local bySize = assert(HATCH_ODDS[rarity], `unknown rarity {rarity}`)
	return assert(bySize[oddsSize(size, luck)], `unknown size {size}`)
end

return table.freeze({
	RARITIES = table.freeze(RARITIES),
	RARITY_ORDER = table.freeze(RARITY_ORDER),
	SIZES = table.freeze(SIZES),
	HATCH_ODDS = table.freeze(HATCH_ODDS),
	oddsSize = oddsSize,
	hatchEntries = hatchEntries,
	-- A server's first eggs (every nest fills at once when it starts) are of this rarity at most;
	-- rarer ones grow only as nests regrow during play, so a fresh server is no jackpot to hop to
	-- (decision 113, Loot.capped).
	FIRST_FILL_MAX_RARITY = "Rare" :: RarityId,
	-- The guardian's recommended speed is computed for an egg of this size.
	TYPICAL_SIZE = "Medium" :: SizeId,
	MAGNET = table.freeze(MAGNET),

	-- A knocked-out egg flies off at this speed, keeps this share of it per second and tumbles.
	DROP_SPEED = 40,
	DROP_RETENTION_PER_SECOND = 0.1,
	DROP_SPIN_RATE = math.rad(360),
	-- The dome keeps knocked-out eggs out, at least this far from its surface, studs: under it
	-- players walk and could not reach an egg floating over the platform; outside it, flying,
	-- they can.
	DOME_MARGIN = 4,

	-- A player can grab an egg within this distance of it, studs.
	GRAB_REACH = 9,
	-- The grab locks onto an egg this many seconds of flight away at the flyer's top speed (never
	-- less than the reach): at 250 studs/s that is 50 studs, at the start about the reach itself.
	LOCK_LEAD_SECONDS = 0.2,
	-- The grab button (docs/design/screens/grab-button.md) offers an egg this close, studs (or the
	-- lock range of a fast flyer, if farther); one press locks on and the magnet pulls the flyer
	-- in from there.
	GRAB_BUTTON_RANGE = 50,
	-- A locked-on grab lets go once its egg is this many button ranges away (it moved off, or
	-- the flyer got thrown), so a grab never pulls from across the map.
	GRAB_RELEASE_FACTOR = 1.5,
	-- The HUD looks for the egg to offer at least this often, seconds, while none is near
	-- (Grab.watchRange; every frame while one is): all 132 nests are walked each time.
	GRAB_SEARCH_SECONDS = 0.1,
	-- Within one search's time the flyer may go this many times its top speed (a strike's lunge).
	GRAB_SEARCH_SPEED_SLACK = 2,
	-- Steering away from the egg lets go of the grab: move input at least this strong, pointing
	-- away from the egg (its direction's dot with the way to the egg at most this).
	GRAB_LEAVE_MOVE = 0.5,
	GRAB_LEAVE_DOT = -0.5,
	-- A nest grows a new egg this long after its old one was delivered to a station, seconds
	-- (while the egg is away, the nest stays empty: Domain/NestCycle).
	RESPAWN_SECONDS = 20,
	-- A dropped egg nobody touches for this long flies back to its nest, seconds.
	LOOSE_SECONDS = 180,

	-- Nest attributes (replicated to clients for the HUD and to the simulation for grabbing).
	NEST_TAG = "Nest",
	NEST_HAS_EGG_ATTRIBUTE = "HasEgg",
	NEST_RARITY_ATTRIBUTE = "Rarity",
	NEST_SIZE_ATTRIBUTE = "Size",
	NEST_EGG_POSITION_ATTRIBUTE = "EggPosition",
	-- The grade of the nest's guardian (the tutorial points at a guardian's nests).
	NEST_GRADE_ATTRIBUTE = "Grade",
	-- Name of the egg part inside a nest model.
	NEST_EGG_NAME = "Egg",
	-- Loose eggs floating in space after a drop, and eggs welded to a thief; both carry the
	-- rarity attribute for the client's trail.
	LOOSE_EGG_TAG = "LooseEgg",
	CARRIED_EGG_TAG = "CarriedEgg",
	LOOSE_EGG_RARITY_ATTRIBUTE = "Rarity",
	LOOSE_EGG_SIZE_ATTRIBUTE = "Size",
	-- On a loose egg: the grade of the guardian that guards it (none for keepers without one),
	-- and the user id of the player who dropped it (the tutorial leads them back to it).
	LOOSE_EGG_GRADE_ATTRIBUTE = "Grade",
	LOOSE_EGG_DROPPED_BY_ATTRIBUTE = "DroppedBy",
	-- Server time it came loose: a fresh drop is news (its sound), one streaming in is not.
	LOOSE_EGG_DROPPED_AT_ATTRIBUTE = "DroppedAt",
	-- On every egg part: the alien variant it hatches into (AlienConfig.VariantId).
	EGG_VARIANT_ATTRIBUTE = "Variant",

	-- Character attributes.
	GRAB_PROGRESS_ATTRIBUTE = "GrabProgress",
	GRAB_TARGET_ATTRIBUTE = "GrabTarget",
	-- The egg the grab is locked on (pressed once; Grab.nextEngaged), and whether the grab input
	-- was down on the last step (a press is the moment it goes down).
	GRAB_ENGAGED_ATTRIBUTE = "GrabEngaged",
	GRAB_PRESSED_ATTRIBUTE = "GrabPressed",
	CARRIED_RARITY_ATTRIBUTE = "CarriedEgg",
	CARRIED_SIZE_ATTRIBUTE = "CarriedEggSize",
})
