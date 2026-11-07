--!strict
-- A player's bay on the station: pods, inventory, crossbreeding, selling and offline income.

local BigNum = require("../Domain/BigNum")
local Trainer = require("../Domain/Trainer")

-- The trainer zone in the island's frame (X right when facing the station center, -Z toward it,
-- Y up): in the entrance's wedge, on the left of a player who walks in from the spawn
-- (docs/design/screens/island.md).
local TRAINER_PAD: Trainer.Pad = {
	x = 17,
	z = -55,
	radius = 3,
	height = 6,
}

return table.freeze({
	-- Pods a new player owns; more are bought with coins.
	STARTING_PODS = 3,
	-- Places on the island (BayLooks.PLACES, Domain/PlaceLayout).
	MAX_PODS = 30,
	-- Bought pod number n (counting the starting ones) costs
	-- POD_PRICE_BASE * POD_PRICE_GROWTH^(n - STARTING_PODS - 1). The first ones are cheap: a
	-- new player should grow their income within minutes.
	POD_PRICE_BASE = BigNum.fromNumber(100),
	POD_PRICE_GROWTH = BigNum.fromNumber(3),

	-- Incubator slots (decision 058): a new player's, and the most there can be (as many eggs as
	-- the incubator shows). Bought slot n costs SLOT_PRICE_BASE * SLOT_PRICE_GROWTH^(n - 1),
	-- counting from the first bought one: cheap at first, so a new player is never kept waiting,
	-- then steep enough to keep up with income, which grows faster than anything (decision 059:
	-- by `lune run balance`, a free player buys the 3rd-4th in the first hour, the 5th-6th in the
	-- first week and the 7th-8th by the third; past that a slot costs hours to days of income,
	-- for those who steal faster than the model, and the last ones are for Robux, stage 8).
	STARTING_INCUBATOR_SLOTS = 2,
	MAX_INCUBATOR_SLOTS = 12,
	SLOT_PRICE_BASE = BigNum.fromNumber(150),
	SLOT_PRICE_GROWTH = BigNum.fromNumber(30),

	INVENTORY_SLOTS = 10,

	-- Aliens of one grade that make one crossbreed.
	CROSSBREED_COUNT = 3,
	-- Luck of a crossbreed (see Hatch.shiftedWeights): the result tilts toward the top tiers.
	CROSSBREED_LUCK = 0.5,

	-- Selling an alien pays this many seconds of its income: placing it is always the better deal.
	SELL_INCOME_SECONDS = 120,

	-- Pods keep earning while the player is away, up to this long.
	OFFLINE_INCOME_CAP_SECONDS = 4 * 60 * 60,
	-- Pods pay out this often (CONVENTIONS, performance: income at 1 Hz).
	INCOME_TICK_SECONDS = 1,

	-- The trainer pad: the owner trains while standing on it (Domain/Trainer), with this much
	-- slack past its edge, studs. The upgrade prompt works from this far.
	TRAINER_PAD = table.freeze(TRAINER_PAD),
	TRAINER_TOLERANCE = 1.2,
	TRAINER_PROMPT_DISTANCE = 8,

	-- The bay shows at most this many queued eggs and floor aliens as models; the rest stay in
	-- the profile and the window (a pile of eighty glowing eggs lit the whole station). The
	-- incubator shows all of its eggs: no more than MAX_INCUBATOR_SLOTS.
	WAITING_SHOWN_MAX = 24,
	FLOOR_SHOWN_MAX = 24,

	-- Bay model attributes and tags (replicated for the client views).
	TAG = "Bay",
	-- On the incubator part: how many eggs warm in it, its slots and how many eggs wait.
	INCUBATOR_COUNT_ATTRIBUTE = "EggCount",
	INCUBATOR_SLOTS_ATTRIBUTE = "Slots",
	INCUBATOR_WAITING_ATTRIBUTE = "Waiting",
	OWNER_ID_ATTRIBUTE = "OwnerUserId",
	OWNER_NAME_ATTRIBUTE = "OwnerName",
	-- Instance names inside a bay model.
	SIGN_NAME = "Sign",
	INCUBATOR_NAME = "Incubator",
	TRAINER_NAME = "Trainer",
	PODS_SIGN_NAME = "PodsSign",
	CONTENTS_NAME = "Contents",
	-- On the bay model: the owner's trainer level and pod count, for the signs.
	TRAINER_LEVEL_ATTRIBUTE = "TrainerLevel",
	POD_COUNT_ATTRIBUTE = "PodCount",
	-- Alien models standing in pods or waiting on the floor.
	ALIEN_TAG = "Alien",
	ALIEN_ID_ATTRIBUTE = "AlienId",
	ALIEN_UID_ATTRIBUTE = "Uid",
	-- Eggs lying in an incubator (HatchAt is server, Unix, time) and eggs waiting for a slot.
	INCUBATOR_EGG_TAG = "IncubatorEgg",
	WAITING_EGG_TAG = "WaitingEgg",
	EGG_UID_ATTRIBUTE = "Uid",
	EGG_HATCH_AT_ATTRIBUTE = "HatchAt",
	-- On a bay's prompts (hatch an egg, pick up an alien): the owner's UserId. Only the owner can
	-- use them, so only the owner's client draws them.
	PROMPT_OWNER_ATTRIBUTE = "OwnerId",
	-- On the prompt of a warming egg that hatches it for Robux: the "Egg ready now" price tier
	-- (MonetizationConfig.readyNowTierOf). The owner's client words it with the price and asks
	-- Roblox for the purchase.
	READY_NOW_TIER_ATTRIBUTE = "ReadyNowTier",
})
