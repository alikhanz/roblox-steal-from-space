--!strict
-- Robux purchases (decisions 061, 132): which Roblox subscription and product ids belong to which
-- game, what each one does and the numbers behind them. The prices are set in the Creator Hub, not
-- here: the game shows the price Roblox returns. Pure Luau: tests load it in Lune.

local BayConfig = require("./BayConfig")
local BigNum = require("../Domain/BigNum")
local EggConfig = require("./EggConfig")
local Purchases = require("../Domain/Purchases")
local UpgradeConfig = require("./UpgradeConfig")
local ZoneConfig = require("./ZoneConfig")

-- What a developer product does.
export type ProductKind = "Training" | "ReadyNow" | "IncubatorSlot" | "CollectDouble"
-- Everything on offer, for the analytics of where it was offered.
export type ShopItem = Purchases.SubscriptionId | ProductKind
-- Where a purchase was offered: the shop window opened from the menu (Store) or from the speed
-- goal (Goal), the welcome-back screen, the bay window, the prompt on a warming egg (Egg).
export type ShopSource = "Store" | "Goal" | "Welcome" | "Bay" | "Egg"

export type Product = {
	read kind: ProductKind,
	-- Training: seconds of the trainer's rate. ReadyNow, IncubatorSlot, CollectDouble: the price
	-- tier.
	read seconds: number?,
	read tier: number?,
}

-- One game's ids: its subscriptions (Roblox's "EXP-…" ids; a game without them offers none) and
-- its products, by Roblox id.
export type GameCatalog = {
	read subscriptions: { [Purchases.SubscriptionId]: string },
	read products: { [number]: Product },
}

local SUBSCRIPTION_TUNING: Purchases.Tuning = {
	doubleTrainingMultiplier = 2,
	-- The night away trains at the full rate of a flight and earns twice the free time (user,
	-- 2026-11-14: «ночная тренировка 100%»): by `lune run balance` the Whale in 26 days instead of
	-- 56, faster than with Double training (36).
	nightShiftTrainingFactor = 1,
	nightShiftIncomeCapSeconds = 8 * 60 * 60,
	nightShiftTrainingCapSeconds = UpgradeConfig.OFFLINE_TRAINING_CAP_SECONDS,
	trainingFactor = UpgradeConfig.OFFLINE_TRAINING_FACTOR,
	incomeCapSeconds = BayConfig.OFFLINE_INCOME_CAP_SECONDS,
	trainingCapSeconds = UpgradeConfig.OFFLINE_TRAINING_CAP_SECONDS,
}

local HOUR = 60 * 60
-- The training packs, shortest first: seconds of the trainer's rate each one gives.
local TRAINING_PACK_SECONDS = { HOUR, 8 * HOUR, 24 * HOUR }

-- Each game has its own subscriptions and products (decision 011: Dev and Prod are separate games).
-- The permanent passes of decision 061 are switched off (decision 132): Dev 2070386434 /
-- 2070559216, Prod 2078156255 / 2075939060, off sale in the Creator Hub.
local GAMES: { [number]: GameCatalog } = {
	-- Steal from Space Dev (created 2026-11-06).
	[10774871729] = {
		subscriptions = {
			DoubleTraining = "EXP-1517120272369582672",
			NightShift = "EXP-3561621462288826877",
		},
		products = {
			[3728652464] = { kind = "Training", seconds = TRAINING_PACK_SECONDS[1] },
			[3728652573] = { kind = "Training", seconds = TRAINING_PACK_SECONDS[2] },
			[3728652763] = { kind = "Training", seconds = TRAINING_PACK_SECONDS[3] },
			[3728652908] = { kind = "ReadyNow", tier = 1 },
			[3728653127] = { kind = "ReadyNow", tier = 2 },
			[3728653284] = { kind = "ReadyNow", tier = 3 },
			[3728653436] = { kind = "ReadyNow", tier = 4 },
			[3728653592] = { kind = "ReadyNow", tier = 5 },
			[3728653681] = { kind = "ReadyNow", tier = 6 },
			[3728653855] = { kind = "ReadyNow", tier = 7 },
			[3728653985] = { kind = "ReadyNow", tier = 8 },
			[3728654116] = { kind = "IncubatorSlot", tier = 1 },
			[3728654221] = { kind = "IncubatorSlot", tier = 2 },
			[3728654379] = { kind = "IncubatorSlot", tier = 3 },
			[3728983039] = { kind = "CollectDouble", tier = 1 },
			[3728983222] = { kind = "CollectDouble", tier = 2 },
			[3728983343] = { kind = "CollectDouble", tier = 3 },
			[3728983452] = { kind = "CollectDouble", tier = 4 },
			[3728983549] = { kind = "CollectDouble", tier = 5 },
			[3728983641] = { kind = "CollectDouble", tier = 6 },
			[3728983708] = { kind = "CollectDouble", tier = 7 },
			[3728654444] = { kind = "CollectDouble", tier = 8 },
		},
	},
	-- Fly & Steal Space Eggs, the Prod game owned by the community (created 2026-11-11).
	[10775754016] = {
		subscriptions = {
			DoubleTraining = "EXP-3043727158911566296",
			NightShift = "EXP-6169272579306684973",
		},
		products = {
			[3730276086] = { kind = "Training", seconds = TRAINING_PACK_SECONDS[1] },
			[3730276256] = { kind = "Training", seconds = TRAINING_PACK_SECONDS[2] },
			[3730276305] = { kind = "Training", seconds = TRAINING_PACK_SECONDS[3] },
			[3730276317] = { kind = "ReadyNow", tier = 1 },
			[3730276329] = { kind = "ReadyNow", tier = 2 },
			[3730276341] = { kind = "ReadyNow", tier = 3 },
			[3730276356] = { kind = "ReadyNow", tier = 4 },
			[3730276414] = { kind = "ReadyNow", tier = 5 },
			[3730276427] = { kind = "ReadyNow", tier = 6 },
			[3730276443] = { kind = "ReadyNow", tier = 7 },
			[3730276456] = { kind = "ReadyNow", tier = 8 },
			[3730276474] = { kind = "IncubatorSlot", tier = 1 },
			[3730276492] = { kind = "IncubatorSlot", tier = 2 },
			[3730276508] = { kind = "IncubatorSlot", tier = 3 },
			[3730276633] = { kind = "CollectDouble", tier = 1 },
			[3730276643] = { kind = "CollectDouble", tier = 2 },
			[3730276655] = { kind = "CollectDouble", tier = 3 },
			[3730276671] = { kind = "CollectDouble", tier = 4 },
			[3730276681] = { kind = "CollectDouble", tier = 5 },
			[3730276693] = { kind = "CollectDouble", tier = 6 },
			[3730276710] = { kind = "CollectDouble", tier = 7 },
			[3730276526] = { kind = "CollectDouble", tier = 8 },
		},
	},
}

local MonetizationConfig = {}

MonetizationConfig.SUBSCRIPTION_TUNING = table.freeze(SUBSCRIPTION_TUNING)
-- The subscriptions in the order the shop lists them.
MonetizationConfig.SUBSCRIPTION_ORDER = table.freeze({ "DoubleTraining", "NightShift" } :: { Purchases.SubscriptionId })
-- After a purchase prompt closes, Roblox may take a moment to report the new subscription: the
-- server asks again this long after the client says it closed (Roblox's own sample waits 10 s).
MonetizationConfig.SUBSCRIPTION_RECHECK_SECONDS = 10
MonetizationConfig.TRAINING_PACK_SECONDS = table.freeze(TRAINING_PACK_SECONDS)
-- "Egg ready now" tiers: zone of the egg's guardian plus its rarity (Purchases.readyNowTier).
MonetizationConfig.READY_NOW_TIERS = 8
-- The last slot of each "Incubator slot" tier: 3rd-6th, 7th-9th, 10th-12th.
MonetizationConfig.SLOT_TIER_LAST = table.freeze({ 6, 9, BayConfig.MAX_INCUBATOR_SLOTS })
-- "Collect x2" tiers by the coins the time away paid (decision 064): below 1M is tier 1, below
-- 10M tier 2 and so on; 1T and more is tier 8. Each step is ten times the reward: about the
-- first hours, day 1, days 2-3, week 1 (4 h away), weeks 2-3, a month and later (balance).
MonetizationConfig.DOUBLE_TIER_LIMITS = table.freeze({ 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12 })
-- Receipts kept in the profile so none is granted twice (Roblox asks again about recent ones).
MonetizationConfig.RECEIPTS_KEPT = 100
-- A purchase that finds nothing to apply to (its egg hatched, every slot bought meanwhile) is
-- not lost: it pays this many minutes of the player's income instead.
MonetizationConfig.COMPENSATION_MINUTES = 30
MonetizationConfig.COMPENSATION_MIN_COINS = 100
-- Player attributes, for every client: the subscriptions the player has (comma-separated
-- Purchases.SubscriptionId), the trainer's multiplier from them (the trainer sign over any bay shows
-- the owner's rate), and whether Roblox lets them buy subscriptions at all (PolicyService).
MonetizationConfig.SUBSCRIPTIONS_ATTRIBUTE = "Subscriptions"
MonetizationConfig.CAN_SUBSCRIBE_ATTRIBUTE = "CanSubscribe"
MonetizationConfig.TRAINER_MULTIPLIER_ATTRIBUTE = "TrainerMultiplier"

-- The catalog of the game with `gameId`, or nil: purchases are off in a game not listed here
-- (an unpublished place in Studio has game id 0).
function MonetizationConfig.catalogFor(gameId: number): GameCatalog?
	return GAMES[gameId]
end

-- The "Egg ready now" tier of an egg of guardian `grade` and `rarity`.
function MonetizationConfig.readyNowTierOf(grade: number, rarity: string): number
	local zone = ZoneConfig.zoneOfPost(grade)
	local zoneIndex = assert(table.find(ZoneConfig.ZONE_ORDER, zone), `no zone for grade {grade}`) - 1
	local rarityIndex = (table.find(EggConfig.RARITY_ORDER, rarity :: EggConfig.RarityId) or 1) - 1
	return Purchases.readyNowTier(zoneIndex, rarityIndex, MonetizationConfig.READY_NOW_TIERS)
end

-- The "Collect x2" tier of a time away that paid `coins`.
function MonetizationConfig.doubleTierOf(coins: BigNum.BigNum): number
	return Purchases.doubleTier(coins, MonetizationConfig.DOUBLE_TIER_LIMITS)
end

-- The most coins a "Collect x2" of `tier` pays: nil for the top tier, which pays any reward.
function MonetizationConfig.doubleLimitOf(tier: number): BigNum.BigNum?
	local limit = MonetizationConfig.DOUBLE_TIER_LIMITS[tier]
	return if limit then BigNum.fromNumber(limit) else nil
end

-- The product id of a kind (and tier, or training seconds) in `catalog`, or nil: for the client
-- to offer the right one.
function MonetizationConfig.productIdOf(
	catalog: GameCatalog,
	kind: ProductKind,
	tier: number?,
	seconds: number?
): number?
	for id, product in catalog.products do
		if product.kind == kind and product.tier == tier and product.seconds == seconds then
			return id
		end
	end
	return nil
end

return table.freeze(MonetizationConfig)
