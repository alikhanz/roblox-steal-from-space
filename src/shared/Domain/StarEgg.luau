--!strict
-- The star egg the serpent drops (decision 055): of the zone it was knocked out in, at that
-- zone's middle guardian's grade, epic or better, and lucky: it hatches as a large egg (decision
-- 113). Pure Luau: the game and the balance calculator roll it the same way.

local EggConfig = require("../Config/EggConfig")
local Loot = require("./Loot")
local SerpentConfig = require("../Config/SerpentConfig")
local ZoneConfig = require("../Config/ZoneConfig")

local StarEgg = {}

export type Egg = {
	rarity: EggConfig.RarityId,
	size: EggConfig.SizeId,
	grade: number,
	luck: number,
}

-- `rarity`, or `floor` when that is the rarer one.
function StarEgg.atLeast(rarity: EggConfig.RarityId, floor: EggConfig.RarityId): EggConfig.RarityId
	local order = EggConfig.RARITY_ORDER
	local rank = assert(table.find(order, rarity), `unknown rarity {rarity}`)
	local floorRank = assert(table.find(order, floor), `unknown rarity {floor}`)
	return if rank < floorRank then floor else rarity
end

-- The grade of a star egg knocked out in `zone`.
function StarEgg.grade(zone: ZoneConfig.ZoneId): number
	return ZoneConfig.postIndex(zone, SerpentConfig.POWER_POST)
end

-- A star egg of `zone`, from two random numbers in [0, 1): the zone's loot, its rarity raised
-- to SerpentConfig.STAR_EGG_MIN_RARITY when below it.
function StarEgg.roll(zone: ZoneConfig.ZoneId, rarityRoll: number, sizeRoll: number): Egg
	local loot = ZoneConfig.ZONES[zone]
	return {
		rarity = StarEgg.atLeast(Loot.pick(loot.rarityLoot, rarityRoll), SerpentConfig.STAR_EGG_MIN_RARITY),
		size = Loot.pick(loot.sizeLoot, sizeRoll),
		grade = StarEgg.grade(zone),
		luck = SerpentConfig.STAR_EGG_LUCK,
	}
end

return table.freeze(StarEgg)
