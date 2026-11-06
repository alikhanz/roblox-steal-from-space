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

local TUNING: Purchases.PassTuning = {
	doubleTrainingMultiplier = 2,
	nightShiftIncomeCapSeconds = 12 * 3600,
	nightShiftTrainingCapSeconds = 24 * 3600,
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

describe("Purchases passes", function()
	it("changes nothing without passes", function()
		local effects = Purchases.passEffects({}, TUNING)
		expect(effects.trainerMultiplier).toBe(1)
		expect(effects.offlineIncomeCapSeconds).toBe(4 * 3600)
		expect(effects.offlineTrainingCapSeconds).toBe(8 * 3600)
	end)

	it("doubles training and lengthens the time away with the passes", function()
		local effects = Purchases.passEffects({ "DoubleTraining", "NightShift" }, TUNING)
		expect(effects.trainerMultiplier).toBe(2)
		expect(effects.offlineIncomeCapSeconds).toBe(12 * 3600)
		expect(effects.offlineTrainingCapSeconds).toBe(24 * 3600)
	end)

	it("notes a pass once", function()
		local data = fresh()
		expect(Purchases.notePass(data, "NightShift")).toBe(true)
		expect(Purchases.notePass(data, "NightShift")).toBe(false)
		expect(data.passes).toEqual({ "NightShift" })
	end)
end)

describe("Purchases.trainerRate", function()
	it("multiplies the trainer's rate by the passes' multiplier", function()
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
end)
