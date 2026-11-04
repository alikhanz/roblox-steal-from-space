--!strict
-- The alien index (Domain/AlienIndex): what finding aliens pays. A reward is minutes of the
-- player's own income (Domain/PlayReward), more for rarer tiers, and a bigger one for a full
-- guardian set. Every alien of the registry is in it, the usual ones and the meteor ones (a
-- section each); most are found in the first days, so it is a treat, not a pace change; `lune
-- run balance` checks it.

local AlienConfig = require("./AlienConfig")
local AlienIndex = require("../Domain/AlienIndex")
local BigNum = require("../Domain/BigNum")

local REWARD_MINUTES: { [AlienConfig.TierId]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 5,
	Legendary = 10,
}

-- Every guardian's set in every variant, built from the one alien registry (AlienConfig): the
-- usual ones first, by grade, then the meteor ones.
local SETS: { AlienIndex.Set } = {}
local SETS_BY_ID: { [string]: AlienIndex.Set } = {}
for _, variant in AlienConfig.VARIANT_ORDER do
	for _, grade in AlienConfig.GRADES do
		local aliens: { string } = {}
		for _, tier in AlienConfig.TIER_ORDER do
			table.insert(aliens, grade.variants[variant][tier])
		end
		local set: AlienIndex.Set = {
			id = AlienIndex.setId(grade.index, variant),
			grade = grade.index,
			variant = variant,
			aliens = aliens,
		}
		table.insert(SETS, set)
		SETS_BY_ID[set.id] = set
	end
end

return table.freeze({
	REWARD_MINUTES = table.freeze(REWARD_MINUTES),
	-- A full set: all five tiers of one guardian in one variant.
	SET_REWARD_MINUTES = 15,
	-- The least a reward pays, for a player with no income yet.
	MIN_REWARD_COINS = BigNum.fromNumber(100),
	SETS = table.freeze(SETS),
	SETS_BY_ID = table.freeze(SETS_BY_ID),
})
