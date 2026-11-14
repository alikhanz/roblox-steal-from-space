--!strict

local AlienOutfit = require("../../src/shared/Domain/AlienOutfit")
local Bench = require("../../src/shared/Domain/Bench")
local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = BigNum.fromNumber(10),
	startingPods = 3,
	startingIncubatorSlots = 2,
}
local MAX_PODS = 6
local ALIENS = { "A", "B", "C", "D", "E", "F" }

local function fresh(): PlayerData.PlayerData
	local data = PlayerData.template(DEFAULTS)
	data.nextUid = 100
	return data
end

describe("Bench.fill", function()
	it("adds places up to the most and fills the empty ones, keeping the player's own", function()
		local data = fresh()
		data.pods[2].alien = { uid = 1, id = "Own", incomePercent = 100 }
		expect(Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))).toBe(true)
		expect(#data.pods).toBe(MAX_PODS)
		expect((data.pods[2].alien :: PlayerData.AlienRecord).id).toBe("Own")
		expect((data.pods[1].alien :: PlayerData.AlienRecord).id).toBe("A")
		expect((data.pods[3].alien :: PlayerData.AlienRecord).id).toBe("B")
		local bench = data.bench :: PlayerData.BenchRecord
		expect(bench.pods).toBe(3)
		expect(#bench.uids).toBe(5)
	end)

	it("does nothing while a bench stands", function()
		local data = fresh()
		expect(Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))).toBe(true)
		expect(Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))).toBe(false)
		expect(#(data.bench :: PlayerData.BenchRecord).uids).toBe(MAX_PODS)
	end)

	it("adds nothing when every place is the player's own", function()
		local data = fresh()
		for index = 1, MAX_PODS do
			data.pods[index] = { alien = { uid = index, id = "Own", incomePercent = 100 } }
		end
		expect(Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))).toBe(false)
		expect(data.bench).toBeNil()
		expect(#data.pods).toBe(MAX_PODS)
	end)
end)

describe("Bench.clear", function()
	it("takes its aliens and places away and leaves the player's own", function()
		local data = fresh()
		data.pods[2].alien = { uid = 1, id = "Own", incomePercent = 100 }
		Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))
		expect(Bench.clear(data)).toBe(true)
		expect(#data.pods).toBe(3)
		expect(data.pods[1].alien).toBeNil()
		expect((data.pods[2].alien :: PlayerData.AlienRecord).id).toBe("Own")
		expect(data.bench).toBeNil()
	end)

	it("finds its aliens moved to the shelf", function()
		local data = fresh()
		Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))
		local moved = data.pods[1].alien :: PlayerData.AlienRecord
		data.pods[1].alien = nil
		table.insert(data.floor, moved)
		table.insert(data.floor, { uid = 7, id = "Own", incomePercent = 100 })
		Bench.clear(data)
		expect(#data.floor).toBe(1)
	end)

	it("keeps an added place that holds the player's own alien", function()
		local data = fresh()
		Bench.fill(data, ALIENS, MAX_PODS, AlienOutfit.sequence(1))
		data.pods[MAX_PODS].alien = { uid = 9, id = "Own", incomePercent = 100 }
		Bench.clear(data)
		expect(#data.pods).toBe(MAX_PODS)
	end)

	it("does nothing with no bench", function()
		expect(Bench.clear(fresh())).toBe(false)
	end)
end)

describe("Bench.fill outfits", function()
	it("dresses each alien it adds as a hatched one", function()
		local AlienConfig = require("../../src/shared/Config/AlienConfig")
		local data = fresh()
		local legendary = AlienConfig.GRADES[1].aliens.Legendary
		expect(Bench.fill(data, { legendary, legendary }, MAX_PODS, AlienOutfit.sequence(3))).toBe(true)
		for _, pod in data.pods do
			if pod.alien then
				expect(((pod.alien :: PlayerData.AlienRecord).outfit :: AlienOutfit.Picks).head).toBe("crown")
			end
		end
	end)
end)
