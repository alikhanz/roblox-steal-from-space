--!strict
-- Aliens: what hatches from eggs. Every guardian post has a grade with three kinds of alien (its
-- baby, a second and a rare kind, decision 075), each in five tiers, that hatch only from its
-- eggs. Tiers differ in income and odds; kinds of one grade earn the same (they are for the
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
-- Which of its guardian's three kinds: its baby, the second one or the rare one.
export type KindSlot = "Main" | "Second" | "Rare"
-- The body a kind is built on (the model's family).
export type FamilyId = "slime" | "crab" | "worm" | "ray" | "swarm" | "whale"

export type Kind = {
	read id: KindId,
	read grade: number,
	read slot: KindSlot,
	read family: FamilyId,
	-- A main kind is named after its guardian, so it reuses the guardian's name.
	read nameKey: keyof<typeof(Strings)>,
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
	-- Its kinds in slot order: main, second, rare.
	read kinds: { KindId },
	-- Hatch odds of its kinds (Loot entries in slot order).
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

-- Kind slots in order, with their hatch odds (decision 075): the guardian's baby most often.
local KIND_SLOT_ORDER: { KindSlot } = { "Main", "Second", "Rare" }
local KIND_WEIGHTS: { [KindSlot]: number } = { Main = 60, Second = 30, Rare = 10 }

-- Each post's kinds in slot order: id, family and name. Ids and order match the models
-- (assets/blender/aliens/robo_kinds.py POSTS; a test keeps them in step). Part of the save
-- format: never rename an id.
local POST_KINDS: { { { any } } } = {
	{
		{ "slimeWarden", "slime", "guardian.slimeWarden.title" },
		{ "patrolSwarm", "swarm", "kind.patrolSwarm.title" },
		{ "patrolRay", "ray", "kind.patrolRay.title" },
	},
	{
		{ "crabDrone", "crab", "guardian.crabDrone.title" },
		{ "droneRay", "ray", "kind.droneRay.title" },
		{ "blimpWhale", "whale", "kind.blimpWhale.title" },
	},
	{
		{ "violetCrab", "crab", "guardian.violetCrab.title" },
		{ "violetWorm", "worm", "kind.violetWorm.title" },
		{ "violetRay", "ray", "kind.violetRay.title" },
	},
	{
		{ "acidSlime", "slime", "guardian.acidSlime.title" },
		{ "acidWorm", "worm", "kind.acidWorm.title" },
		{ "acidWhale", "whale", "kind.acidWhale.title" },
	},
	{
		{ "rustyCrab", "crab", "guardian.rustyCrab.title" },
		{ "rustySwarm", "swarm", "kind.rustySwarm.title" },
		{ "rustyWhale", "whale", "kind.rustyWhale.title" },
	},
	{
		{ "slimeKing", "slime", "guardian.slimeKing.title" },
		{ "royalSwarm", "swarm", "kind.royalSwarm.title" },
		{ "royalRay", "ray", "kind.royalRay.title" },
	},
	{
		{ "iceWorm", "worm", "guardian.iceWorm.title" },
		{ "iceSwarm", "swarm", "kind.iceSwarm.title" },
		{ "iceCrab", "crab", "kind.iceCrab.title" },
	},
	{
		{ "snowCrab", "crab", "guardian.snowCrab.title" },
		{ "snowSlime", "slime", "kind.snowSlime.title" },
		{ "snowWhale", "whale", "kind.snowWhale.title" },
	},
	{
		{ "frostSlime", "slime", "guardian.frostSlime.title" },
		{ "flakeSwarm", "swarm", "kind.flakeSwarm.title" },
		{ "frostRay", "ray", "kind.frostRay.title" },
	},
	{
		{ "crystalWorm", "worm", "guardian.crystalWorm.title" },
		{ "crystalSlime", "slime", "kind.crystalSlime.title" },
		{ "crystalWhale", "whale", "kind.crystalWhale.title" },
	},
	{
		{ "iceRay", "ray", "guardian.iceRay.title" },
		{ "icebreakerCrab", "crab", "kind.icebreakerCrab.title" },
		{ "auroraSwarm", "swarm", "kind.auroraSwarm.title" },
	},
	{
		{ "wormMother", "worm", "guardian.wormMother.title" },
		{ "motherWhale", "whale", "kind.motherWhale.title" },
		{ "nannyRay", "ray", "kind.nannyRay.title" },
	},
	{
		{ "devourerSwarm", "swarm", "guardian.devourerSwarm.title" },
		{ "devourerCrab", "crab", "kind.devourerCrab.title" },
		{ "devourerWorm", "worm", "kind.devourerWorm.title" },
	},
	{
		{ "starRay", "ray", "guardian.starRay.title" },
		{ "starSlime", "slime", "kind.starSlime.title" },
		{ "starWhale", "whale", "kind.starWhale.title" },
	},
	{
		{ "fireSlime", "slime", "guardian.fireSlime.title" },
		{ "fireWorm", "worm", "kind.fireWorm.title" },
		{ "fireWhale", "whale", "kind.fireWhale.title" },
	},
	{
		{ "redSwarm", "swarm", "guardian.redSwarm.title" },
		{ "redCrab", "crab", "kind.redCrab.title" },
		{ "redRay", "ray", "kind.redRay.title" },
	},
	{
		{ "lightningRay", "ray", "guardian.lightningRay.title" },
		{ "stormSlime", "slime", "kind.stormSlime.title" },
		{ "stormWhale", "whale", "kind.stormWhale.title" },
	},
	{
		{ "devourerQueen", "swarm", "guardian.devourerQueen.title" },
		{ "guardCrab", "crab", "kind.guardCrab.title" },
		{ "empressWorm", "worm", "kind.empressWorm.title" },
	},
	{
		{ "shadowWorm", "worm", "guardian.shadowWorm.title" },
		{ "shadowSlime", "slime", "kind.shadowSlime.title" },
		{ "shadowCrab", "crab", "kind.shadowCrab.title" },
	},
	{
		{ "blackRay", "ray", "guardian.blackRay.title" },
		{ "eclipseSwarm", "swarm", "kind.eclipseSwarm.title" },
		{ "eclipseWhale", "whale", "kind.eclipseWhale.title" },
	},
	{
		{ "voidSwarm", "swarm", "guardian.voidSwarm.title" },
		{ "voidSlime", "slime", "kind.voidSlime.title" },
		{ "voidRay", "ray", "kind.voidRay.title" },
	},
	{
		{ "gravityCrab", "crab", "guardian.gravityCrab.title" },
		{ "gravityWorm", "worm", "kind.gravityWorm.title" },
		{ "gravitySwarm", "swarm", "kind.gravitySwarm.title" },
	},
	{
		{ "whaleCalf", "whale", "guardian.whaleCalf.title" },
		{ "rayCalf", "ray", "kind.rayCalf.title" },
		{ "stargazerCrab", "crab", "kind.stargazerCrab.title" },
	},
	{
		{ "spaceWhale", "whale", "guardian.spaceWhale.title" },
		{ "spaceWorm", "worm", "kind.spaceWorm.title" },
		{ "galaxySlime", "slime", "kind.galaxySlime.title" },
	},
}
assert(#POST_KINDS == ZoneConfig.POST_COUNT, "AlienConfig needs three kinds for every guardian post")

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
	for position, slot in KIND_SLOT_ORDER do
		local row = POST_KINDS[index][position]
		local kindId: KindId = row[1]
		assert(KINDS[kindId] == nil, `kind {kindId} is listed twice`)
		KINDS[kindId] = table.freeze({ id = kindId, grade = index, slot = slot, family = row[2], nameKey = row[3] })
		table.insert(kinds, kindId)
		table.insert(kindEntries, table.freeze({ id = kindId, weight = KIND_WEIGHTS[slot] }))
	end
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
	KIND_SLOT_ORDER = table.freeze(KIND_SLOT_ORDER),
	GRADES = table.freeze(GRADES),
	KINDS = table.freeze(KINDS),
	ALIENS = table.freeze(ALIENS),
})
