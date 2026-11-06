--!strict
-- Robux purchases (decision 061): which Roblox pass and product ids belong to which game, what
-- each one does and the numbers behind them. The prices are set in the Creator Hub, not here:
-- the game shows the price Roblox returns. Pure Luau: tests load it in Lune.

local BayConfig = require("./BayConfig")
local EggConfig = require("./EggConfig")
local Purchases = require("../Domain/Purchases")
local UpgradeConfig = require("./UpgradeConfig")
local ZoneConfig = require("./ZoneConfig")

-- What a developer product does.
export type ProductKind = "Training" | "ReadyNow" | "IncubatorSlot" | "CollectDouble"

export type Product = {
	read kind: ProductKind,
	-- Training: seconds of the trainer's rate. ReadyNow and IncubatorSlot: the price tier.
	read seconds: number?,
	read tier: number?,
}

-- One game's ids: its passes and its products, by Roblox id.
export type GameCatalog = {
	read passes: { [Purchases.PassId]: number },
	read products: { [number]: Product },
}

local PASS_TUNING: Purchases.PassTuning = {
	doubleTrainingMultiplier = 2,
	nightShiftIncomeCapSeconds = 12 * 60 * 60,
	nightShiftTrainingCapSeconds = 24 * 60 * 60,
	incomeCapSeconds = BayConfig.OFFLINE_INCOME_CAP_SECONDS,
	trainingCapSeconds = UpgradeConfig.OFFLINE_TRAINING_CAP_SECONDS,
}

local HOUR = 60 * 60

-- Each game has its own passes and products (decision 011: Dev and Prod are separate games).
local GAMES: { [number]: GameCatalog } = {
	-- Steal from Space Dev (created 2026-11-06).
	[10774871729] = {
		passes = {
			DoubleTraining = 2070386434,
			NightShift = 2070559216,
		},
		products = {
			[3728652464] = { kind = "Training", seconds = HOUR },
			[3728652573] = { kind = "Training", seconds = 8 * HOUR },
			[3728652763] = { kind = "Training", seconds = 24 * HOUR },
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
			[3728654444] = { kind = "CollectDouble" },
		},
	},
}

local MonetizationConfig = {}

MonetizationConfig.PASS_TUNING = table.freeze(PASS_TUNING)
-- "Egg ready now" tiers: zone of the egg's guardian plus its rarity (Purchases.readyNowTier).
MonetizationConfig.READY_NOW_TIERS = 8
-- The last slot of each "Incubator slot" tier: 3rd-6th, 7th-9th, 10th-12th.
MonetizationConfig.SLOT_TIER_LAST = table.freeze({ 6, 9, BayConfig.MAX_INCUBATOR_SLOTS })
-- Receipts kept in the profile so none is granted twice (Roblox asks again about recent ones).
MonetizationConfig.RECEIPTS_KEPT = 100
-- A purchase that finds nothing to apply to (its egg hatched, every slot bought meanwhile) is
-- not lost: it pays this many minutes of the player's income instead.
MonetizationConfig.COMPENSATION_MINUTES = 30
MonetizationConfig.COMPENSATION_MIN_COINS = 100
-- Player attributes, for every client: the passes owned (comma-separated Purchases.PassId) and
-- the trainer's multiplier from them (the trainer sign over any bay shows the owner's rate).
MonetizationConfig.PASSES_ATTRIBUTE = "Passes"
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
