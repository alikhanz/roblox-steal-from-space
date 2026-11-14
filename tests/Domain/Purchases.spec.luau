--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Purchases = require("../../src/shared/Domain/Purchases")
local Test = require("../../lune/lib/Test")
local UpgradeConfig = require("../../src/shared/Config/UpgradeConfig")
local Upgrades = require("../../src/shared/Domain/Upgrades")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = BigNum.fromNumber(10),
	startingPods = 3,
	startingIncubatorSlots = 2,
}

local TUNING: Purchases.Tuning = {
	doubleTrainingMultiplier = 2,
	nightShiftTrainingFactor = 1,
	nightShiftIncomeCapSeconds = 8 * 3600,
	nightShiftTrainingCapSeconds = 10 * 3600,
	trainingFactor = 0.2,
	incomeCapSeconds = 4 * 3600,
	trainingCapSeconds = 8 * 3600,
}

local function fresh(): PlayerData.PlayerData
	return PlayerData.template(DEFAULTS)
end

local function egg(uid: number, hatchAt: number, grade: number?): PlayerData.EggRecord
	return { uid = uid, rarity = "Common", size = "Small", grade = grade or 1, hatchAt = hatchAt }
end

-- In these tests an egg's tier is its grade.
local function tierOf(record: PlayerData.EggRecord): number
	return record.grade
end

describe("Purchases receipts", function()
	it("grants a receipt once", function()
		local data = fresh()
		expect(Purchases.recordReceipt(data, "a", 100)).toBe(true)
		expect(Purchases.recordReceipt(data, "a", 100)).toBe(false)
		expect(Purchases.hasReceipt(data.purchaseIds, "a")).toBe(true)
	end)

	it("keeps only the latest receipts", function()
		local data = fresh()
		for index = 1, 5 do
			Purchases.recordReceipt(data, `r{index}`, 3)
		end
		expect(data.purchaseIds).toEqual({ "r3", "r4", "r5" })
	end)
end)

describe("Purchases weeks", function()
	local WEEK = 7 * 86400
	local NOW = 1000000

	it("starts a week from now and adds the next one on top", function()
		local data = fresh()
		expect(Purchases.extendWeek(data, "NightShift", WEEK, NOW)).toBe(NOW + WEEK)
		expect(Purchases.extendWeek(data, "NightShift", WEEK, NOW + 100)).toBe(NOW + 2 * WEEK)
		-- After one ran out, the next starts from the purchase, not from the old end.
		expect(Purchases.extendWeek(data, "DoubleTraining", WEEK, NOW)).toBe(NOW + WEEK)
		expect(Purchases.extendWeek(data, "DoubleTraining", WEEK, NOW + 3 * WEEK)).toBe(NOW + 4 * WEEK)
	end)

	it("counts a running week as the perk, once, with or without the subscription", function()
		local data = fresh()
		Purchases.extendWeek(data, "NightShift", WEEK, NOW)
		expect(Purchases.active(data, NOW + 10)).toEqual({ "NightShift" })
		expect(Purchases.active(data, NOW + WEEK)).toEqual({})
		data.subscriptions = { "NightShift" }
		expect(Purchases.active(data, NOW + 10)).toEqual({ "NightShift" })
		Purchases.extendWeek(data, "DoubleTraining", WEEK, NOW)
		expect(Purchases.active(data, NOW + 10)).toEqual({ "DoubleTraining", "NightShift" })
		-- Both perks of the same kind never double twice.
		local effects = Purchases.effects(Purchases.active(data, NOW + 10), TUNING)
		expect(effects.trainerMultiplier).toBe(2)
	end)

	it("covers as much of a time away as a week lasted, all of it for a subscription", function()
		local data = fresh()
		data.weeks = { NightShift = NOW + 3600, DoubleTraining = NOW - 50 }
		local covered = Purchases.coveredAway(data, NOW, 5 * 3600)
		expect(covered.NightShift).toBe(3600)
		expect(covered.DoubleTraining).toBe(0)
		data.subscriptions = { "DoubleTraining" }
		expect(Purchases.coveredAway(data, NOW, 5 * 3600).DoubleTraining).toBe(5 * 3600)
	end)
end)

describe("Purchases.away", function()
	local H = 3600

	it("pays the free share and caps without perks", function()
		local paid = Purchases.away(10 * H, {}, TUNING)
		expect(paid.incomeSeconds).toBe(4 * H)
		expect(paid.rateSeconds).toBeCloseTo(8 * H * 0.2, 1e-6)
	end)

	it("pays Night shift for the whole time it covered", function()
		local paid = Purchases.away(12 * H, { NightShift = 12 * H }, TUNING)
		expect(paid.incomeSeconds).toBe(8 * H)
		-- The tuning's night cap is 10 h.
		expect(paid.rateSeconds).toBeCloseTo(10 * H * 1, 1e-6)
	end)

	it("pays a week only for the part of the time away it lasted", function()
		-- Night shift ran out 3 h in: 3 h at the full rate, then the free share up to the free cap.
		local paid = Purchases.away(12 * H, { NightShift = 3 * H }, TUNING)
		expect(paid.rateSeconds).toBeCloseTo(3 * H * 1 + 5 * H * 0.2, 1e-6)
		-- It earned the free 4 h, as it lasted less.
		expect(paid.incomeSeconds).toBe(4 * H)
		-- Lasting 6 h, it earns 6 h.
		expect(Purchases.away(12 * H, { NightShift = 6 * H }, TUNING).incomeSeconds).toBe(6 * H)
	end)

	it("doubles what was trained while Double training lasted", function()
		local paid = Purchases.away(12 * H, { DoubleTraining = 2 * H }, TUNING)
		expect(paid.rateSeconds).toBeCloseTo(2 * H * 0.2 * 2 + 6 * H * 0.2, 1e-6)
		local both = Purchases.away(12 * H, { DoubleTraining = 12 * H, NightShift = 12 * H }, TUNING)
		expect(both.rateSeconds).toBeCloseTo(10 * H * 1 * 2, 1e-6)
	end)

	it("pays nothing for no time away", function()
		local paid = Purchases.away(0, { NightShift = 0 }, TUNING)
		expect(paid.incomeSeconds).toBe(0)
		expect(paid.rateSeconds).toBe(0)
	end)
end)

describe("Purchases subscriptions", function()
	it("changes nothing without subscriptions", function()
		local effects = Purchases.effects({}, TUNING)
		expect(effects.trainerMultiplier).toBe(1)
		expect(effects.offlineTrainingFactor).toBe(0.2)
		expect(effects.offlineIncomeCapSeconds).toBe(4 * 3600)
		expect(effects.offlineTrainingCapSeconds).toBe(8 * 3600)
	end)

	it("doubles training with Double training", function()
		local effects = Purchases.effects({ "DoubleTraining" }, TUNING)
		expect(effects.trainerMultiplier).toBe(2)
		expect(effects.offlineTrainingFactor).toBe(0.2)
		expect(effects.offlineIncomeCapSeconds).toBe(4 * 3600)
	end)

	it("trains at the full rate and earns longer away with Night shift", function()
		local effects = Purchases.effects({ "NightShift" }, TUNING)
		expect(effects.trainerMultiplier).toBe(1)
		expect(effects.offlineTrainingFactor).toBe(1)
		expect(effects.offlineIncomeCapSeconds).toBe(8 * 3600)
		expect(effects.offlineTrainingCapSeconds).toBe(10 * 3600)
	end)

	it("turns a subscription on and off, reporting only changes", function()
		local data = fresh()
		expect(Purchases.setSubscribed(data, "NightShift", true)).toBe(true)
		expect(Purchases.setSubscribed(data, "NightShift", true)).toBe(false)
		expect(Purchases.setSubscribed(data, "DoubleTraining", true)).toBe(true)
		expect(data.subscriptions).toEqual({ "NightShift", "DoubleTraining" })
		expect(Purchases.setSubscribed(data, "NightShift", false)).toBe(true)
		expect(Purchases.setSubscribed(data, "NightShift", false)).toBe(false)
		expect(data.subscriptions).toEqual({ "DoubleTraining" })
		expect(Purchases.isSubscribed(data.subscriptions, "DoubleTraining")).toBe(true)
		expect(Purchases.isSubscribed(data.subscriptions, "NightShift")).toBe(false)
	end)
end)

describe("Purchases.trainerRate", function()
	it("multiplies the trainer's rate by the subscriptions' multiplier", function()
		local tuning = UpgradeConfig.TUNING
		local base = Upgrades.trainerRate(3, tuning)
		expect(BigNum.toNumber(Purchases.trainerRate(3, 1, tuning))).toBe(BigNum.toNumber(base))
		expect(BigNum.toNumber(Purchases.trainerRate(3, 2, tuning))).toBe(BigNum.toNumber(base) * 2)
	end)
end)

describe("Purchases.trainingPack", function()
	it("gives an hour of the trainer's rate, and the stat at the jetpack", function()
		local paid = Purchases.trainingPack(BigNum.fromNumber(3), 3600, BigNum.fromNumber(4))
		expect(BigNum.toNumber(paid.trained)).toBe(10800)
		expect(BigNum.toNumber(paid.speed)).toBe(43200)
		expect(BigNum.isZero(paid.coins)).toBe(true)
	end)
end)

describe("Purchases ready now", function()
	it("prices by zone and rarity, from 1 up to the last tier", function()
		expect(Purchases.readyNowTier(0, 0, 8)).toBe(1)
		expect(Purchases.readyNowTier(3, 4, 8)).toBe(8)
		expect(Purchases.readyNowTier(1, 2, 8)).toBe(4)
		expect(Purchases.readyNowTier(3, 9, 8)).toBe(8)
	end)

	it("makes the chosen warming egg ready", function()
		local data = fresh()
		data.incubator = { egg(1, 500, 2), egg(2, 900, 2) }
		expect(Purchases.makeReady(data, 1, 2, tierOf, 100)).toBe(1)
		expect(data.incubator[1].hatchAt).toBe(100)
		expect(data.incubator[2].hatchAt).toBe(900)
	end)

	it("takes the egg with the most time left when the choice cannot have it", function()
		local data = fresh()
		-- Egg 3 is above the tier paid for, egg 4 is ready already.
		data.incubator = { egg(1, 500, 1), egg(2, 900, 2), egg(3, 5000, 3), egg(4, 50, 1) }
		expect(Purchases.makeReady(data, 3, 2, tierOf, 100)).toBe(2)
		expect(Purchases.makeReady(data, nil, 2, tierOf, 100)).toBe(1)
		expect(Purchases.makeReady(data, nil, 2, tierOf, 100)).toBeNil()
		expect(data.incubator[3].hatchAt).toBe(5000)
	end)
end)

describe("Purchases.slotTier", function()
	it("prices the next slot by its number", function()
		local lastSlots = { 6, 9, 12 }
		expect(Purchases.slotTier(2, lastSlots)).toBe(1)
		expect(Purchases.slotTier(5, lastSlots)).toBe(1)
		expect(Purchases.slotTier(6, lastSlots)).toBe(2)
		expect(Purchases.slotTier(9, lastSlots)).toBe(3)
		expect(Purchases.slotTier(11, lastSlots)).toBe(3)
		expect(Purchases.slotTier(12, lastSlots)).toBe(3)
	end)
end)

describe("Purchases collect twice", function()
	it("gives the time away once more, then nothing", function()
		local data = fresh()
		expect(Purchases.hasPendingDouble(data)).toBe(false)
		Purchases.setPendingDouble(data, BigNum.fromNumber(500), BigNum.fromNumber(20))
		expect(Purchases.hasPendingDouble(data)).toBe(true)
		local coins, trained = Purchases.takePendingDouble(data)
		expect(BigNum.toNumber(coins)).toBe(500)
		expect(BigNum.toNumber(trained)).toBe(20)
		expect(Purchases.hasPendingDouble(data)).toBe(false)
		local again = Purchases.takePendingDouble(data)
		expect(BigNum.isZero(again)).toBe(true)
	end)

	it("pays a cheaper tier only up to its limit, with the same share of speed", function()
		local data = fresh()
		Purchases.setPendingDouble(data, BigNum.fromNumber(1000), BigNum.fromNumber(40))
		local coins, trained = Purchases.takePendingDouble(data, BigNum.fromNumber(250))
		expect(BigNum.toNumber(coins)).toBe(250)
		expect(BigNum.toNumber(trained)).toBe(10)
		expect(Purchases.hasPendingDouble(data)).toBe(false)
	end)

	it("pays it all when the limit is above the reward", function()
		local data = fresh()
		Purchases.setPendingDouble(data, BigNum.fromNumber(1000), BigNum.fromNumber(40))
		local coins, trained = Purchases.takePendingDouble(data, BigNum.fromNumber(5000))
		expect(BigNum.toNumber(coins)).toBe(1000)
		expect(BigNum.toNumber(trained)).toBe(40)
	end)
end)

describe("Purchases.doubleTier", function()
	it("prices a bigger reward higher", function()
		local limits = { 1e3, 1e6, 1e9 }
		expect(Purchases.doubleTier(BigNum.ZERO, limits)).toBe(1)
		expect(Purchases.doubleTier(BigNum.fromNumber(999), limits)).toBe(1)
		expect(Purchases.doubleTier(BigNum.fromNumber(1e3), limits)).toBe(2)
		expect(Purchases.doubleTier(BigNum.fromNumber(5e8), limits)).toBe(3)
		expect(Purchases.doubleTier(BigNum.fromNumber(1e9), limits)).toBe(4)
		expect(Purchases.doubleTier(BigNum.new(1, 30), limits)).toBe(4)
	end)
end)
