--!strict
-- A player's bay on the station: pods, inventory, crossbreeding, selling and offline income.

local BigNum = require("../Domain/BigNum")
local Trainer = require("../Domain/Trainer")

-- The trainer zone in the bay's frame (X right, -Z toward the platform center, Y up): on the
-- station floor just off the bay's right side, level with the pods.
local TRAINER_PAD: Trainer.Pad = {
	x = 16.5,
	z = -3.75,
	radius = 1.8,
	height = 6,
}

return table.freeze({
	-- Pods a new player owns; more are bought with coins.
	STARTING_PODS = 3,
	MAX_PODS = 12,
	-- Bought pod number n (counting the starting ones) costs
	-- POD_PRICE_BASE * POD_PRICE_GROWTH^(n - STARTING_PODS - 1). The first ones are cheap: a
	-- new player should grow their income within minutes.
	POD_PRICE_BASE = BigNum.fromNumber(100),
	POD_PRICE_GROWTH = BigNum.fromNumber(3),

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

	-- The bay shows at most this many incubator eggs and floor aliens as models; the rest stay
	-- in the profile and the window (a pile of eighty glowing eggs lit the whole station).
	INCUBATOR_SHOWN_MAX = 12,
	FLOOR_SHOWN_MAX = 24,

	-- Bay model attributes and tags (replicated for the client views).
	TAG = "Bay",
	-- On the incubator part: how many eggs it holds and the server time the next one hatches.
	INCUBATOR_COUNT_ATTRIBUTE = "EggCount",
	INCUBATOR_NEXT_HATCH_ATTRIBUTE = "NextHatchAt",
	OWNER_ID_ATTRIBUTE = "OwnerUserId",
	OWNER_NAME_ATTRIBUTE = "OwnerName",
	-- Instance names inside a bay model.
	SIGN_NAME = "Sign",
	INCUBATOR_NAME = "Incubator",
	TRAINER_NAME = "Trainer",
	CONTENTS_NAME = "Contents",
	-- On the bay model: the owner's trainer level, for the sign over the pad.
	TRAINER_LEVEL_ATTRIBUTE = "TrainerLevel",
	-- Alien models standing in pods or waiting on the floor.
	ALIEN_TAG = "Alien",
	ALIEN_ID_ATTRIBUTE = "AlienId",
	ALIEN_UID_ATTRIBUTE = "Uid",
	-- Eggs lying in an incubator; HatchAt is server (Unix) time.
	INCUBATOR_EGG_TAG = "IncubatorEgg",
	EGG_UID_ATTRIBUTE = "Uid",
	EGG_HATCH_AT_ATTRIBUTE = "HatchAt",
})
