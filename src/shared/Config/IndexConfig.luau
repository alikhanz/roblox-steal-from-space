--!strict
-- The alien index (Domain/AlienIndex): what finding aliens pays. A reward is minutes of the
-- player's own income (Domain/PlayReward), more for rarer tiers, and a bigger one for a full
-- guardian set. There are only 120 aliens, most found in the first days, so it is a treat, not
-- a pace change; `lune run balance` checks it.

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

-- Each guardian's set, built from the one alien registry (AlienConfig), by grade.
local SETS: { AlienIndex.Set } = {}
for _, grade in AlienConfig.GRADES do
	local aliens: { string } = {}
	for _, tier in AlienConfig.TIER_ORDER do
		table.insert(aliens, grade.aliens[tier])
	end
	local set: AlienIndex.Set = { grade = grade.index, aliens = aliens }
	SETS[grade.index] = set
end

return table.freeze({
	REWARD_MINUTES = table.freeze(REWARD_MINUTES),
	-- A full set: all five tiers of one guardian.
	SET_REWARD_MINUTES = 15,
	-- The least a reward pays, for a player with no income yet.
	MIN_REWARD_COINS = BigNum.fromNumber(100),
	SETS = table.freeze(SETS),
})
