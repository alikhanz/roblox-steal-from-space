--!strict
-- Daily quests (Domain/Quests): the pool, how many a day and what they pay. A reward is minutes
-- of the player's own play: all three together are about 25 minutes of income and trainer
-- rate, which `lune run balance` checks stays a small boost (stage 7: at most 10-15 %).

local BigNum = require("../Domain/BigNum")
local Quests = require("../Domain/Quests")

local DEFINITIONS: { Quests.Definition } = {
	{ kind = "DeliverEggs", weight = 3, minTarget = 3, maxTarget = 5, rewardMinutes = 10 },
	-- From the zone of the farthest guardian beaten: the player's own frontier.
	{ kind = "DeliverFromZone", weight = 2, minTarget = 1, maxTarget = 1, rewardMinutes = 8 },
	{ kind = "HatchAliens", weight = 3, minTarget = 3, maxTarget = 5, rewardMinutes = 8 },
	-- Seconds on the trainer pad.
	{ kind = "Train", weight = 2, minTarget = 5 * 60, maxTarget = 5 * 60, rewardMinutes = 7 },
	{ kind = "Crossbreed", weight = 1, minTarget = 1, maxTarget = 1, rewardMinutes = 7, requires = "CanCrossbreed" },
	-- Needs another player with an egg: the day's swap is there for empty servers.
	{ kind = "KnockEgg", weight = 1, minTarget = 1, maxTarget = 1, rewardMinutes = 10, requires = "CanFight" },
}

for _, definition in DEFINITIONS do
	table.freeze(definition)
end

return table.freeze({
	DEFINITIONS = table.freeze(DEFINITIONS),
	-- Quests a day.
	COUNT = 3,
	-- The least a quest pays in coins, for a player with no income yet.
	MIN_REWARD_COINS = BigNum.fromNumber(200),
	-- Online players get the new day's quests within this many seconds of UTC midnight.
	DAY_CHECK_SECONDS = 5,
})
