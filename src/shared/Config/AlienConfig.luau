--!strict
-- Aliens: what hatches from eggs. Every guardian post has a grade with its own kinds of alien
-- (its baby first, then the others, each with its own hatch odds: decisions 075, 080), each in
-- five tiers, that hatch only from its eggs. Tiers differ in income and odds; kinds of one grade earn the same (they are for the
-- collection); grades earn more the farther their guardian is from the station.

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
-- A kind's id is the model's id (assets/blender/aliens/robo_kinds.py): "crabDrone".
export type KindId = string
-- The body a kind is built on (the model's family).
export type FamilyId = "slime" | "crab" | "worm" | "ray" | "swarm" | "whale"

export type Kind = {
	read id: KindId,
	read grade: number,
	-- Its place among its guardian's kinds: 1 is the guardian's own baby (the main kind).
	read position: number,
	read family: FamilyId,
	-- The main kind is named after its guardian, so it reuses the guardian's name.
	read nameKey: keyof<typeof(Strings)>,
	-- Its share of the guardian's hatches, against the weights of the guardian's other kinds.
	read weight: number,
}

-- A row of POST_KINDS.
type KindRow = {
	id: KindId,
	family: FamilyId,
	nameKey: keyof<typeof(Strings)>,
	weight: number,
}

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
	read kind: KindId,
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
	-- Its kinds in order, the main one first.
	read kinds: { KindId },
	-- Hatch odds of its kinds (Loot entries in the same order).
	read kindEntries: { Loot.Entry<KindId> },
	-- The guardian's own aliens by tier: the usual variant of its main kind.
	read aliens: { [TierId]: AlienId },
	read variants: { [VariantId]: { [KindId]: { [TierId]: AlienId } } },
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

-- Hatch weights of a guardian's usual three kinds (decision 075): its baby most often, the rare
-- one seldom. A post may have more kinds, each with a weight of its own (decision 080).
local MAIN_WEIGHT = 60
local SECOND_WEIGHT = 30
local RARE_WEIGHT = 10

-- Each post's kinds, its main kind (the guardian's baby) first. Ids and order match the models
-- (assets/blender/aliens/robo_kinds.py POSTS; a test keeps them in step). Part of the save
-- format: never rename an id; a new kind goes at the end of its post's list.
local POST_KINDS: { { KindRow } } = {
	{
		{ id = "slimeWarden", family = "slime", nameKey = "guardian.slimeWarden.title", weight = MAIN_WEIGHT },
		{ id = "patrolSwarm", family = "swarm", nameKey = "kind.patrolSwarm.title", weight = SECOND_WEIGHT },
		{ id = "patrolRay", family = "ray", nameKey = "kind.patrolRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "crabDrone", family = "crab", nameKey = "guardian.crabDrone.title", weight = MAIN_WEIGHT },
		{ id = "droneRay", family = "ray", nameKey = "kind.droneRay.title", weight = SECOND_WEIGHT },
		{ id = "blimpWhale", family = "whale", nameKey = "kind.blimpWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "violetCrab", family = "crab", nameKey = "guardian.violetCrab.title", weight = MAIN_WEIGHT },
		{ id = "violetWorm", family = "worm", nameKey = "kind.violetWorm.title", weight = SECOND_WEIGHT },
		{ id = "violetRay", family = "ray", nameKey = "kind.violetRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "acidSlime", family = "slime", nameKey = "guardian.acidSlime.title", weight = MAIN_WEIGHT },
		{ id = "acidWorm", family = "worm", nameKey = "kind.acidWorm.title", weight = SECOND_WEIGHT },
		{ id = "acidWhale", family = "whale", nameKey = "kind.acidWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "rustyCrab", family = "crab", nameKey = "guardian.rustyCrab.title", weight = MAIN_WEIGHT },
		{ id = "rustySwarm", family = "swarm", nameKey = "kind.rustySwarm.title", weight = SECOND_WEIGHT },
		{ id = "rustyWhale", family = "whale", nameKey = "kind.rustyWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "slimeKing", family = "slime", nameKey = "guardian.slimeKing.title", weight = MAIN_WEIGHT },
		{ id = "royalSwarm", family = "swarm", nameKey = "kind.royalSwarm.title", weight = SECOND_WEIGHT },
		{ id = "royalRay", family = "ray", nameKey = "kind.royalRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "iceWorm", family = "worm", nameKey = "guardian.iceWorm.title", weight = MAIN_WEIGHT },
		{ id = "iceSwarm", family = "swarm", nameKey = "kind.iceSwarm.title", weight = SECOND_WEIGHT },
		{ id = "iceCrab", family = "crab", nameKey = "kind.iceCrab.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "snowCrab", family = "crab", nameKey = "guardian.snowCrab.title", weight = MAIN_WEIGHT },
		{ id = "snowSlime", family = "slime", nameKey = "kind.snowSlime.title", weight = SECOND_WEIGHT },
		{ id = "snowWhale", family = "whale", nameKey = "kind.snowWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "frostSlime", family = "slime", nameKey = "guardian.frostSlime.title", weight = MAIN_WEIGHT },
		{ id = "flakeSwarm", family = "swarm", nameKey = "kind.flakeSwarm.title", weight = SECOND_WEIGHT },
		{ id = "frostRay", family = "ray", nameKey = "kind.frostRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "crystalWorm", family = "worm", nameKey = "guardian.crystalWorm.title", weight = MAIN_WEIGHT },
		{ id = "crystalSlime", family = "slime", nameKey = "kind.crystalSlime.title", weight = SECOND_WEIGHT },
		{ id = "crystalWhale", family = "whale", nameKey = "kind.crystalWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "iceRay", family = "ray", nameKey = "guardian.iceRay.title", weight = MAIN_WEIGHT },
		{ id = "icebreakerCrab", family = "crab", nameKey = "kind.icebreakerCrab.title", weight = SECOND_WEIGHT },
		{ id = "auroraSwarm", family = "swarm", nameKey = "kind.auroraSwarm.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "wormMother", family = "worm", nameKey = "guardian.wormMother.title", weight = MAIN_WEIGHT },
		{ id = "motherWhale", family = "whale", nameKey = "kind.motherWhale.title", weight = SECOND_WEIGHT },
		{ id = "nannyRay", family = "ray", nameKey = "kind.nannyRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "devourerSwarm", family = "swarm", nameKey = "guardian.devourerSwarm.title", weight = MAIN_WEIGHT },
		{ id = "devourerCrab", family = "crab", nameKey = "kind.devourerCrab.title", weight = SECOND_WEIGHT },
		{ id = "devourerWorm", family = "worm", nameKey = "kind.devourerWorm.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "starRay", family = "ray", nameKey = "guardian.starRay.title", weight = MAIN_WEIGHT },
		{ id = "starSlime", family = "slime", nameKey = "kind.starSlime.title", weight = SECOND_WEIGHT },
		{ id = "starWhale", family = "whale", nameKey = "kind.starWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "fireSlime", family = "slime", nameKey = "guardian.fireSlime.title", weight = MAIN_WEIGHT },
		{ id = "fireWorm", family = "worm", nameKey = "kind.fireWorm.title", weight = SECOND_WEIGHT },
		{ id = "fireWhale", family = "whale", nameKey = "kind.fireWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "redSwarm", family = "swarm", nameKey = "guardian.redSwarm.title", weight = MAIN_WEIGHT },
		{ id = "redCrab", family = "crab", nameKey = "kind.redCrab.title", weight = SECOND_WEIGHT },
		{ id = "redRay", family = "ray", nameKey = "kind.redRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "lightningRay", family = "ray", nameKey = "guardian.lightningRay.title", weight = MAIN_WEIGHT },
		{ id = "stormSlime", family = "slime", nameKey = "kind.stormSlime.title", weight = SECOND_WEIGHT },
		{ id = "stormWhale", family = "whale", nameKey = "kind.stormWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "devourerQueen", family = "swarm", nameKey = "guardian.devourerQueen.title", weight = MAIN_WEIGHT },
		{ id = "guardCrab", family = "crab", nameKey = "kind.guardCrab.title", weight = SECOND_WEIGHT },
		{ id = "empressWorm", family = "worm", nameKey = "kind.empressWorm.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "shadowWorm", family = "worm", nameKey = "guardian.shadowWorm.title", weight = MAIN_WEIGHT },
		{ id = "shadowSlime", family = "slime", nameKey = "kind.shadowSlime.title", weight = SECOND_WEIGHT },
		{ id = "shadowCrab", family = "crab", nameKey = "kind.shadowCrab.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "blackRay", family = "ray", nameKey = "guardian.blackRay.title", weight = MAIN_WEIGHT },
		{ id = "eclipseSwarm", family = "swarm", nameKey = "kind.eclipseSwarm.title", weight = SECOND_WEIGHT },
		{ id = "eclipseWhale", family = "whale", nameKey = "kind.eclipseWhale.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "voidSwarm", family = "swarm", nameKey = "guardian.voidSwarm.title", weight = MAIN_WEIGHT },
		{ id = "voidSlime", family = "slime", nameKey = "kind.voidSlime.title", weight = SECOND_WEIGHT },
		{ id = "voidRay", family = "ray", nameKey = "kind.voidRay.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "gravityCrab", family = "crab", nameKey = "guardian.gravityCrab.title", weight = MAIN_WEIGHT },
		{ id = "gravityWorm", family = "worm", nameKey = "kind.gravityWorm.title", weight = SECOND_WEIGHT },
		{ id = "gravitySwarm", family = "swarm", nameKey = "kind.gravitySwarm.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "whaleCalf", family = "whale", nameKey = "guardian.whaleCalf.title", weight = MAIN_WEIGHT },
		{ id = "rayCalf", family = "ray", nameKey = "kind.rayCalf.title", weight = SECOND_WEIGHT },
		{ id = "stargazerCrab", family = "crab", nameKey = "kind.stargazerCrab.title", weight = RARE_WEIGHT },
	},
	{
		{ id = "spaceWhale", family = "whale", nameKey = "guardian.spaceWhale.title", weight = MAIN_WEIGHT },
		{ id = "spaceWorm", family = "worm", nameKey = "kind.spaceWorm.title", weight = SECOND_WEIGHT },
		{ id = "galaxySlime", family = "slime", nameKey = "kind.galaxySlime.title", weight = RARE_WEIGHT },
	},
}
assert(#POST_KINDS == ZoneConfig.POST_COUNT, "AlienConfig needs the kinds of every guardian post")

-- One grade per guardian post, in post order (six per zone). Ids name the zone and the post's
-- number within it, then the kind, the tier, and the variant unless it is the usual one:
-- "IceRings3.crystalWorm.Rare", "IceRings3.crystalWorm.Rare.Meteor". Part of the save format:
-- never renumber.
local GRADES: { Grade } = {}
local ALIENS: { [AlienId]: Alien } = {}
local KINDS: { [KindId]: Kind } = {}
for index = 1, ZoneConfig.POST_COUNT do
	local zone, localIndex = ZoneConfig.zoneOfPost(index)
	local baseIncome = BigNum.mul(INCOME_BASE, BigNum.pow(INCOME_GROWTH, index - 1))
	local kinds: { KindId } = {}
	local kindEntries: { Loot.Entry<KindId> } = {}
	for position, row in POST_KINDS[index] do
		local kindId = row.id
		assert(KINDS[kindId] == nil, `kind {kindId} is listed twice`)
		assert(row.weight > 0, `kind {kindId} needs a positive hatch weight`)
		KINDS[kindId] = table.freeze({
			id = kindId,
			grade = index,
			position = position,
			family = row.family,
			nameKey = row.nameKey,
			weight = row.weight,
		})
		table.insert(kinds, kindId)
		table.insert(kindEntries, table.freeze({ id = kindId, weight = row.weight }))
	end
	assert(#kinds > 0, `guardian post {index} needs at least one kind`)
	local variants: { [VariantId]: { [KindId]: { [TierId]: AlienId } } } = {}
	for _, variant in VARIANT_ORDER do
		local byKind: { [KindId]: { [TierId]: AlienId } } = {}
		local suffix = if variant == "Normal" then "" else `.{variant}`
		for _, kindId in kinds do
			local aliens: { [TierId]: AlienId } = {}
			for _, tier in TIER_ORDER do
				local id = `{zone}{localIndex}.{kindId}.{tier}{suffix}`
				aliens[tier] = id
				local factor = TIERS[tier].incomeFactor * VARIANTS[variant].incomeFactor
				ALIENS[id] = table.freeze({
					id = id,
					grade = index,
					kind = kindId,
					tier = tier,
					variant = variant,
					income = BigNum.mul(baseIncome, BigNum.fromNumber(factor)),
					scale = SIZE_GROWTH ^ (index - 1) * TIERS[tier].sizeFactor,
				})
			end
			byKind[kindId] = table.freeze(aliens)
		end
		variants[variant] = table.freeze(byKind)
	end
	GRADES[index] = table.freeze({
		index = index,
		zone = zone,
		kinds = table.freeze(kinds),
		kindEntries = table.freeze(kindEntries),
		aliens = variants.Normal[kinds[1]],
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
	KINDS = table.freeze(KINDS),
	ALIENS = table.freeze(ALIENS),
})
