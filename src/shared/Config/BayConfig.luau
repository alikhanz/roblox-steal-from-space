--!strict
-- A player's bay on the station: pods, the shelf, crossbreeding, selling and offline income.

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

	-- Aliens with no pod stand on the shelf, one to a niche (docs/design/screens/storage-shelf.md,
	-- Domain/Shelf.capacity); a full shelf and no free pod keep ready eggs from hatching (decision
	-- 106, docs/design/screens/aliens-and-hints.md).
	SHELF_SLOTS = 24,

	-- At most this many aliens are sold with one command ("Sell all", decision 106): more than the
	-- pods and the shelf can hold together.
	SELL_MANY_MAX = 64,

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

	-- The bay shows at most this many queued eggs as models; the rest stay in the profile and the
	-- window (a pile of eighty glowing eggs lit the whole station). The incubator shows all of its
	-- eggs: no more than MAX_INCUBATOR_SLOTS. Aliens with no place: as many as the shelf has niches
	-- (SHELF_SLOTS), the rest (only an old profile has more) only in the window.
	WAITING_SHOWN_MAX = 24,

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
	-- The shelf where aliens with no place stand (docs/design/screens/storage-shelf.md).
	SHELF_NAME = "Shelf",
	-- In the shelf: the point its count hangs at (decision 106).
	SHELF_COUNTER_NAME = "Counter",
	CONTENTS_NAME = "Contents",
	-- The terminals (docs/design/screens/terminals.md) and the part their screen is drawn on.
	PLACES_TERMINAL_NAME = "PlacesTerminal",
	INCUBATOR_TERMINAL_NAME = "IncubatorTerminal",
	TRAINER_TERMINAL_NAME = "TrainerTerminal",
	TERMINAL_SCREEN_NAME = "Screen",
	-- The attachments on the screen part where the client's beam starts (the lens) and ends (the
	-- screen's bottom edge).
	TERMINAL_BEAM_FROM_NAME = "BeamFrom",
	TERMINAL_BEAM_TO_NAME = "BeamTo",
	-- The jetpack stand (docs/design/screens/jetpack-stand.md): one model of all its parts, the
	-- trainer's platform its primary part (what the tutorial lights up), and the parts the client
	-- lights up inside it.
	STAND_NAME = "Stand",
	STAND_GRATE_NAME = "StandGrate",
	STAND_PILOT_NAME = "StandPilot",
	-- The stand from the kit (decision 091): the rest of its look (body, light, gold) and the level
	-- dial's lamps; on the stand, the tier it wears.
	STAND_LOOK_NAME = "StandLook",
	STAND_LAMP_NAME = "StandLamp",
	STAND_TIER_ATTRIBUTE = "Tier",
	-- On the bay model: the owner's trainer level and pod count, for the terminals.
	TRAINER_LEVEL_ATTRIBUTE = "TrainerLevel",
	POD_COUNT_ATTRIBUTE = "PodCount",
	-- On the bay model: how many aliens stand on the shelf (its counter, decision 106).
	SHELF_COUNT_ATTRIBUTE = "ShelfCount",
	-- Alien models standing in pods or waiting on the floor.
	ALIEN_TAG = "Alien",
	ALIEN_ID_ATTRIBUTE = "AlienId",
	ALIEN_UID_ATTRIBUTE = "Uid",
	-- Where the server stands an alien (its model's pivot, a CFrame): the client moves the pet
	-- around it and follows it when the bay's layout shifts the alien to another place.
	ALIEN_PIVOT_ATTRIBUTE = "Pivot",
	-- How far an alien's pivot stands above where it stands, studs (World/AlienModel).
	ALIEN_LIFT_ATTRIBUTE = "StandLift",
	-- When the server built the alien's model (server time): a fresh one pops onto its place on
	-- the client (docs/design/screens/buttons.md); one that streams in later just appears.
	ALIEN_SHOWN_AT_ATTRIBUTE = "ShownAt",
	-- A place's model, and where it stands (its floor frame, a CFrame): when the layout shifts it,
	-- the client glides it there with its alien.
	PLACE_TAG = "BayPlace",
	PLACE_PIVOT_ATTRIBUTE = "Pivot",
	-- True on a bought place with no alien: the owner's client marks it free (decision 106).
	PLACE_EMPTY_ATTRIBUTE = "Empty",
	-- True on an alien standing small on the shelf: the client shows only its model (no effects,
	-- no motion) and its chip only up close.
	ALIEN_PLAIN_ATTRIBUTE = "Plain",
	-- Eggs lying in an incubator (HatchAt is server, Unix, time) and eggs waiting for a slot.
	INCUBATOR_EGG_TAG = "IncubatorEgg",
	WAITING_EGG_TAG = "WaitingEgg",
	EGG_UID_ATTRIBUTE = "Uid",
	EGG_HATCH_AT_ATTRIBUTE = "HatchAt",
	-- On a bay's prompts (hatch an egg, pick up an alien): the owner's UserId. Only the owner can
	-- use them, so only the owner's client draws them.
	PROMPT_OWNER_ATTRIBUTE = "OwnerId",
	-- On a prompt whose action is not the usual "do it" (green): what it does, for its colour
	-- (docs/design/screens/buttons.md). A prompt that hatches for Robux is told by its ReadyNowTier.
	PROMPT_ACTION_ATTRIBUTE = "Action",
	-- The prompt on an alien on the shelf that opens the bay window with it chosen (decision 106),
	-- and on a free place that puts the best of the shelf there.
	PROMPT_ACTION_OPEN_BAY = "OpenBay",
	PROMPT_ACTION_PLACE_BEST = "PlaceBest",
	-- On a ready egg that cannot hatch (the shelf is full and no place is free): the owner's client
	-- draws it red, and pressing it opens the bay window.
	PROMPT_ACTION_SHELF_FULL = "ShelfFull",
	-- On the prompt of an alien on the shelf: its uid, for the window to open with it chosen.
	PROMPT_ALIEN_UID_ATTRIBUTE = "AlienUid",
	-- On the prompt of a warming egg that hatches it for Robux: the "Egg ready now" price tier
	-- (MonetizationConfig.readyNowTierOf). The owner's client words it with the price and asks
	-- Roblox for the purchase.
	READY_NOW_TIER_ATTRIBUTE = "ReadyNowTier",
	-- On a prompt: how high over its part's centre the client draws it, studs (default: at the
	-- centre). An egg's prompt hangs low, this far under the egg, on the capsule's stand: the
	-- timer and "Ready!" chips of the ring of capsules sit over the eggs and used to cover it.
	PROMPT_STUDS_ABOVE_ATTRIBUTE = "StudsAbove",
	EGG_PROMPT_BELOW = 0.75,
})
