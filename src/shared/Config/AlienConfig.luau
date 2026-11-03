--!strict
-- Aliens: what hatches from eggs. Every guardian has a grade, its own set of five aliens (one
-- per tier) that hatch only from its eggs. Tiers differ in income and odds; grades earn more the
-- farther their guardian is from the station.

local BigNum = require("../Domain/BigNum")
local Loot = require("../Domain/Loot")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")

export type TierId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type AlienId = string

export type Tier = {
	read nameKey: keyof<typeof(Strings)>,
	-- Multiplies the grade's base income.
	read incomeFactor: number,
	-- Base odds of hatching into this tier, before the egg's luck (see Hatch.shiftedWeights).
	read hatchWeight: number,
}

export type Alien = {
	read id: AlienId,
	read grade: number,
	read tier: TierId,
	-- Coins per second while in a pod.
	read income: BigNum.BigNum,
}

export type Grade = {
	read index: number,
	read aliens: { [TierId]: AlienId },
}

-- From the lowest tier up. Hatch and Crossbreed rely on this order.
local TIER_ORDER: { TierId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local TIERS: { [TierId]: Tier } = {
	Common = { nameKey = "tier.common.title", incomeFactor = 1, hatchWeight = 55 },
	Uncommon = { nameKey = "tier.uncommon.title", incomeFactor = 2, hatchWeight = 28 },
	Rare = { nameKey = "tier.rare.title", incomeFactor = 5, hatchWeight = 12 },
	Epic = { nameKey = "tier.epic.title", incomeFactor = 15, hatchWeight = 4 },
	Legendary = { nameKey = "tier.legendary.title", incomeFactor = 50, hatchWeight = 1 },
}

-- The common alien of guardian k earns INCOME_BASE * INCOME_GROWTH^(k-1) coins per second. Income
-- grows slower than guardian speed (x1.8 against x3), so money matters more with every zone.
local INCOME_BASE = BigNum.fromNumber(1)
local INCOME_GROWTH = BigNum.fromNumber(1.7)
-- One grade per guardian post of the Debris Belt; GuardianConfig checks its posts against this.
local DEBRIS_BELT_GRADES = 3

local TIER_POSITIONS: { [TierId]: number } = {}
local HATCH_ENTRIES: { Loot.Entry<TierId> } = {}
for position, tier in TIER_ORDER do
	TIER_POSITIONS[tier] = position
	HATCH_ENTRIES[position] = table.freeze({ id = tier, weight = TIERS[tier].hatchWeight })
end

local GRADES: { Grade } = {}
local ALIENS: { [AlienId]: Alien } = {}
for index = 1, DEBRIS_BELT_GRADES do
	local baseIncome = BigNum.mul(INCOME_BASE, BigNum.pow(INCOME_GROWTH, index - 1))
	local aliens: { [TierId]: AlienId } = {}
	for _, tier in TIER_ORDER do
		-- Part of the save format: never renumber.
		local id = `DebrisBelt{index}.{tier}`
		aliens[tier] = id
		ALIENS[id] = table.freeze({
			id = id,
			grade = index,
			tier = tier,
			income = BigNum.mul(baseIncome, BigNum.fromNumber(TIERS[tier].incomeFactor)),
		})
	end
	GRADES[index] = table.freeze({ index = index, aliens = table.freeze(aliens) })
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
	DEBRIS_BELT_GRADES = DEBRIS_BELT_GRADES,
	GRADES = table.freeze(GRADES),
	ALIENS = table.freeze(ALIENS),
})
