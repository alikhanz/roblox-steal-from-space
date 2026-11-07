--!strict
-- Aliens: what hatches from eggs. Every guardian post has a grade, its own set of five aliens
-- (one per tier) that hatch only from its eggs. Tiers differ in income and odds; grades earn
-- more the farther their guardian is from the station.

local BigNum = require("../Domain/BigNum")
local Loot = require("../Domain/Loot")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")
local ZoneConfig = require("./ZoneConfig")

export type TierId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
-- Every alien comes in each variant: the usual one from guardians' eggs, and the meteor one
-- from the meteor shower's eggs, which earns more.
export type VariantId = "Normal" | "Meteor"
export type AlienId = string

export type Tier = {
	read nameKey: keyof<typeof(Strings)>,
	-- The name cut short, for narrow columns (the index).
	read shortKey: keyof<typeof(Strings)>,
	-- Multiplies the grade's base income.
	read incomeFactor: number,
	-- Base odds of hatching into this tier, before the egg's luck (see Hatch.shiftedWeights).
	read hatchWeight: number,
	-- How much bigger this tier stands than the grade's common one (decision 068).
	read sizeFactor: number,
}

export type Variant = {
	-- Multiplies the income of the same grade and tier.
	read incomeFactor: number,
	-- Added in front of the tier in the alien's name, and in front of its egg's name (an egg is
	-- grammatically neuter in Russian, hence its own word); nil for the usual aliens.
	read nameKey: keyof<typeof(Strings)>?,
	read eggNameKey: keyof<typeof(Strings)>?,
}

export type Alien = {
	read id: AlienId,
	read grade: number,
	read tier: TierId,
	read variant: VariantId,
	-- Coins per second while in a place.
	read income: BigNum.BigNum,
	-- How big it stands against the first guardian's common alien (decision 068): grows with
	-- every guardian and with the tier.
	read scale: number,
}

export type Grade = {
	read index: number,
	read zone: ZoneConfig.ZoneId,
	-- The usual aliens by tier (the same as variants.Normal).
	read aliens: { [TierId]: AlienId },
	read variants: { [VariantId]: { [TierId]: AlienId } },
}

-- From the lowest tier up. Hatch and Crossbreed rely on this order.
local TIER_ORDER: { TierId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local TIERS: { [TierId]: Tier } = {
	Common = {
		nameKey = "tier.common.title",
		shortKey = "tier.commonShort.title",
		incomeFactor = 1,
		hatchWeight = 55,
		sizeFactor = 1,
	},
	Uncommon = {
		nameKey = "tier.uncommon.title",
		shortKey = "tier.uncommonShort.title",
		incomeFactor = 2,
		hatchWeight = 28,
		sizeFactor = 1.15,
	},
	Rare = {
		nameKey = "tier.rare.title",
		shortKey = "tier.rareShort.title",
		incomeFactor = 5,
		hatchWeight = 12,
		sizeFactor = 1.3,
	},
	Epic = {
		nameKey = "tier.epic.title",
		shortKey = "tier.epicShort.title",
		incomeFactor = 15,
		hatchWeight = 4,
		sizeFactor = 1.5,
	},
	Legendary = {
		nameKey = "tier.legendary.title",
		shortKey = "tier.legendaryShort.title",
		incomeFactor = 50,
		hatchWeight = 1,
		sizeFactor = 1.8,
	},
}

-- The common alien of guardian k earns INCOME_BASE * INCOME_GROWTH^(k-1) coins per second. Income
-- grows slower than guardian speed (x1.8 against x3), so money matters more with every zone.
local INCOME_BASE = BigNum.fromNumber(1)
local INCOME_GROWTH = BigNum.fromNumber(1.7)
-- Each guardian's aliens stand this many times bigger than the previous one's (decision 068):
-- the last guardian's legendary is about eight times a player's height.
local SIZE_GROWTH = 1.108

local TIER_POSITIONS: { [TierId]: number } = {}
local HATCH_ENTRIES: { Loot.Entry<TierId> } = {}
for position, tier in TIER_ORDER do
	TIER_POSITIONS[tier] = position
	HATCH_ENTRIES[position] = table.freeze({ id = tier, weight = TIERS[tier].hatchWeight })
end

-- The usual variant first. Ids of the usual aliens carry no variant.
local VARIANT_ORDER: { VariantId } = { "Normal", "Meteor" }

local VARIANTS: { [VariantId]: Variant } = {
	Normal = { incomeFactor = 1 },
	-- About twice the usual alien of the same grade and tier (stage 7, meteor shower).
	Meteor = {
		incomeFactor = 2,
		nameKey = "variant.meteor.title" :: keyof<typeof(Strings)>,
		eggNameKey = "variant.meteorEgg.title" :: keyof<typeof(Strings)>,
	},
}

-- One grade per guardian post, in post order (six per zone). Ids name the zone and the post's
-- number within it, then the tier, then the variant unless it is the usual one:
-- "IceRings3.Rare", "IceRings3.Rare.Meteor". Part of the save format: never renumber.
local GRADES: { Grade } = {}
local ALIENS: { [AlienId]: Alien } = {}
for index = 1, ZoneConfig.POST_COUNT do
	local zone, localIndex = ZoneConfig.zoneOfPost(index)
	local baseIncome = BigNum.mul(INCOME_BASE, BigNum.pow(INCOME_GROWTH, index - 1))
	local variants: { [VariantId]: { [TierId]: AlienId } } = {}
	for _, variant in VARIANT_ORDER do
		local aliens: { [TierId]: AlienId } = {}
		local suffix = if variant == "Normal" then "" else `.{variant}`
		for _, tier in TIER_ORDER do
			local id = `{zone}{localIndex}.{tier}{suffix}`
			aliens[tier] = id
			local factor = TIERS[tier].incomeFactor * VARIANTS[variant].incomeFactor
			ALIENS[id] = table.freeze({
				id = id,
				grade = index,
				tier = tier,
				variant = variant,
				income = BigNum.mul(baseIncome, BigNum.fromNumber(factor)),
				scale = SIZE_GROWTH ^ (index - 1) * TIERS[tier].sizeFactor,
			})
		end
		variants[variant] = table.freeze(aliens)
	end
	GRADES[index] = table.freeze({
		index = index,
		zone = zone,
		aliens = variants.Normal,
		variants = table.freeze(variants),
	})
end

for _, variant in VARIANTS do
	table.freeze(variant)
end

return table.freeze({
	TIER_ORDER = table.freeze(TIER_ORDER),
	TIERS = table.freeze(TIERS),
	-- Position of each tier in TIER_ORDER, 1 for the lowest.
	TIER_POSITIONS = table.freeze(TIER_POSITIONS),
	-- Hatch odds in tier order: the shape Hatch.shiftedWeights takes.
	HATCH_ENTRIES = table.freeze(HATCH_ENTRIES),
	INCOME_BASE = INCOME_BASE,
	INCOME_GROWTH = INCOME_GROWTH,
	VARIANT_ORDER = table.freeze(VARIANT_ORDER),
	VARIANTS = table.freeze(VARIANTS),
	GRADES = table.freeze(GRADES),
	ALIENS = table.freeze(ALIENS),
})
