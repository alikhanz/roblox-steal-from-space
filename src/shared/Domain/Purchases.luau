--!strict
-- What every Robux purchase does to the profile (decision 061): the passes' effects, the
-- training packs, an egg ready now, a slot for Robux, collecting the time away twice, and the
-- record of processed receipts that makes each purchase count once. Pure Luau: numbers come in
-- as parameters (MonetizationConfig), the server applies the result in one profile update.

local BigNum = require("./BigNum")
local PlayReward = require("./PlayReward")
local PlayerData = require("./PlayerData")
local Upgrades = require("./Upgrades")

export type PassId = "DoubleTraining" | "NightShift"

-- What the passes change, and the values without them.
export type PassTuning = {
	-- Double training: the trainer's rate is multiplied by this, away too.
	read doubleTrainingMultiplier: number,
	-- Night shift: how long the pods earn and the trainer works while the player is away.
	read nightShiftIncomeCapSeconds: number,
	read nightShiftTrainingCapSeconds: number,
	-- The same caps without the pass.
	read incomeCapSeconds: number,
	read trainingCapSeconds: number,
}

-- What the passes a player owns do, all together.
export type PassEffects = {
	trainerMultiplier: number,
	offlineIncomeCapSeconds: number,
	offlineTrainingCapSeconds: number,
}

-- The part of the profile the purchases touch (PlayerData has all of it).
type Data = PlayerData.PlayerData

local Purchases = {}

-- True once a receipt with `purchaseId` was granted.
function Purchases.hasReceipt(receipts: { string }, purchaseId: string): boolean
	return table.find(receipts, purchaseId) ~= nil
end

-- Records a granted receipt, keeping the last `keep` of them (Roblox asks again only about
-- recent ones). False when it was already recorded: the purchase must not be granted twice.
function Purchases.recordReceipt(data: Data, purchaseId: string, keep: number): boolean
	if Purchases.hasReceipt(data.purchaseIds, purchaseId) then
		return false
	end
	table.insert(data.purchaseIds, purchaseId)
	while #data.purchaseIds > keep do
		table.remove(data.purchaseIds, 1)
	end
	return true
end

function Purchases.ownsPass(passes: { string }, pass: PassId): boolean
	return table.find(passes, pass) ~= nil
end

-- Notes a pass the player owns (Roblox is the source of truth; this is the copy for when its
-- check fails). False when it was noted already.
function Purchases.notePass(data: Data, pass: PassId): boolean
	if Purchases.ownsPass(data.passes, pass) then
		return false
	end
	table.insert(data.passes, pass)
	return true
end

function Purchases.passEffects(passes: { string }, tuning: PassTuning): PassEffects
	local nightShift = Purchases.ownsPass(passes, "NightShift")
	return {
		trainerMultiplier = if Purchases.ownsPass(passes, "DoubleTraining") then tuning.doubleTrainingMultiplier else 1,
		offlineIncomeCapSeconds = if nightShift then tuning.nightShiftIncomeCapSeconds else tuning.incomeCapSeconds,
		offlineTrainingCapSeconds = if nightShift
			then tuning.nightShiftTrainingCapSeconds
			else tuning.trainingCapSeconds,
	}
end

-- The trainer's rate at `level` with the passes' `multiplier` (PassEffects.trainerMultiplier):
-- what the pad pays per second, at home and away, and what a training pack is measured in.
function Purchases.trainerRate(level: number, multiplier: number, tuning: Upgrades.Tuning): BigNum.BigNum
	return BigNum.mul(Upgrades.trainerRate(level, tuning), BigNum.fromNumber(multiplier))
end

-- A training pack: as many speed points as the trainer gives at `rate` (the player's own, with
-- their passes) in `seconds`, and the stat they add at the jetpack's `multiplier`. No coins.
function Purchases.trainingPack(rate: BigNum.BigNum, seconds: number, multiplier: BigNum.BigNum): PlayReward.Paid
	local trained = BigNum.mul(rate, BigNum.fromNumber(seconds))
	return { coins = BigNum.ZERO, trained = trained, speed = BigNum.mul(trained, multiplier) }
end

-- The price tier of making an egg ready now: its guardian's zone (0 for the first) plus its
-- rarity (0 for Common), one-based and no higher than `tiers`.
function Purchases.readyNowTier(zoneIndex: number, rarityIndex: number, tiers: number): number
	return math.clamp(zoneIndex + rarityIndex + 1, 1, tiers)
end

-- Makes an egg in a slot ready now, for a purchase of `tier`: the egg `uid` the player chose
-- when it is still warming and of that tier or below, otherwise the warming egg with the most
-- time left among those of that tier or below (a receipt may come back after the choice is
-- gone). Returns the egg's uid, or nil when no egg can take it.
function Purchases.makeReady(
	data: Data,
	uid: number?,
	tier: number,
	tierOf: (egg: PlayerData.EggRecord) -> number,
	now: number
): number?
	local chosen: PlayerData.EggRecord? = nil
	for _, egg in data.incubator do
		local fits = egg.hatchAt > now and tierOf(egg) <= tier
		if fits and egg.uid == uid then
			chosen = egg
			break
		end
		if fits and (not chosen or egg.hatchAt > chosen.hatchAt) then
			chosen = egg
		end
	end
	if not chosen then
		return nil
	end
	chosen.hatchAt = now
	return chosen.uid
end

-- The price tier of the incubator's next slot when it has `slots`: the first tier whose last
-- slot (`lastSlots`, ascending) is not below the next one.
function Purchases.slotTier(slots: number, lastSlots: { number }): number
	for tier, last in lastSlots do
		if slots + 1 <= last then
			return tier
		end
	end
	return #lastSlots
end

-- What a time away paid, kept for "Collect x2" until the next time away replaces it.
function Purchases.setPendingDouble(data: Data, coins: BigNum.BigNum, trained: BigNum.BigNum)
	data.pendingDouble = { coins = coins, trained = trained }
end

-- True while there is a time away to collect again.
function Purchases.hasPendingDouble(data: Data): boolean
	local pending = data.pendingDouble
	return not BigNum.isZero(pending.coins) or not BigNum.isZero(pending.trained)
end

-- The price tier of "Collect x2" for a time away that paid `coins`: the first tier whose limit
-- (`limits`, ascending, in coins) is above them; past the last limit, the top tier
-- (#limits + 1). The bigger the reward, the higher the price (decision 064).
function Purchases.doubleTier(coins: BigNum.BigNum, limits: { number }): number
	for tier, limit in limits do
		if BigNum.lessThan(coins, BigNum.fromNumber(limit)) then
			return tier
		end
	end
	return #limits + 1
end

-- Takes the time away to collect again (nothing when there is none) and clears it, so it is
-- collected twice at most. With `maxCoins` (a cheaper tier than the reward needs) it pays only
-- that many coins and the same share of the speed points.
function Purchases.takePendingDouble(data: Data, maxCoins: BigNum.BigNum?): (BigNum.BigNum, BigNum.BigNum)
	local pending = data.pendingDouble
	data.pendingDouble = { coins = BigNum.ZERO, trained = BigNum.ZERO }
	if not maxCoins or not BigNum.lessThan(maxCoins, pending.coins) then
		return pending.coins, pending.trained
	end
	local share = BigNum.div(maxCoins, pending.coins)
	return maxCoins, BigNum.floor(BigNum.mul(pending.trained, share))
end

return table.freeze(Purchases)
