--!strict

local Bay = require("../../src/shared/Domain/Bay")
local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = BigNum.fromNumber(10),
	startingPods = 3,
}
local SLOTS = 2

-- Income by alien id: "Common" earns 1, "Rare" 5, "Epic" 15.
local INCOMES: { [string]: number } = { Common = 1, Rare = 5, Epic = 15 }
local function incomeOf(id: string): BigNum.BigNum
	return BigNum.fromNumber(assert(INCOMES[id], `unknown alien {id}`))
end

local function alien(uid: number, id: string): PlayerData.AlienRecord
	return { uid = uid, id = id }
end

local function fresh(): PlayerData.PlayerData
	local data = PlayerData.template(DEFAULTS)
	data.nextUid = 100
	return data
end

local function uids(list: { PlayerData.AlienRecord }): { number }
	local result = {}
	for _, record in list do
		table.insert(result, record.uid)
	end
	return result
end

local function podUids(data: PlayerData.PlayerData): { number? }
	local result = {}
	for index, pod in data.pods do
		result[index] = if pod.alien then pod.alien.uid else nil
	end
	return result
end

describe("Bay.newUid", function()
	it("hands out increasing uids", function()
		local data = fresh()
		expect(Bay.newUid(data)).toBe(100)
		expect(Bay.newUid(data)).toBe(101)
		expect(data.nextUid).toBe(102)
	end)
end)

describe("Bay.addHatched", function()
	it("fills the first free pod, then the floor", function()
		local data = fresh()
		expect(Bay.addHatched(data, alien(1, "Common"))).toBe("Pod")
		expect(Bay.addHatched(data, alien(2, "Common"))).toBe("Pod")
		expect(Bay.addHatched(data, alien(3, "Common"))).toBe("Pod")
		expect(Bay.addHatched(data, alien(4, "Common"))).toBe("Floor")
		expect(podUids(data)).toEqual({ 1, 2, 3 })
		expect(uids(data.floor)).toEqual({ 4 })
		expect(Bay.freePods(data)).toBe(0)
	end)
end)

describe("Bay.addCrossbred", function()
	it("goes to the inventory while there is room, then wherever a hatch would", function()
		local data = fresh()
		expect(Bay.addCrossbred(data, alien(1, "Common"), 1)).toBe("Inventory")
		expect(Bay.addCrossbred(data, alien(2, "Common"), 1)).toBe("Pod")
		expect(Bay.addCrossbred(data, alien(3, "Common"), 1)).toBe("Pod")
		expect(Bay.addCrossbred(data, alien(4, "Common"), 1)).toBe("Pod")
		expect(Bay.addCrossbred(data, alien(5, "Common"), 1)).toBe("Floor")
		expect(uids(data.inventory)).toEqual({ 1 })
		expect(uids(data.floor)).toEqual({ 5 })
	end)
end)

describe("Bay.find and Bay.remove", function()
	it("finds aliens wherever they are", function()
		local data = fresh()
		data.pods[2].alien = alien(1, "Common")
		data.inventory = { alien(2, "Rare") }
		data.floor = { alien(3, "Epic") }
		local _, where = Bay.find(data, 1)
		expect(where).toBe("Pod")
		_, where = Bay.find(data, 2)
		expect(where).toBe("Inventory")
		_, where = Bay.find(data, 3)
		expect(where).toBe("Floor")
		expect(Bay.find(data, 4)).toBeNil()
	end)

	it("removes an alien and leaves the rest in place", function()
		local data = fresh()
		data.pods[2].alien = alien(1, "Common")
		data.inventory = { alien(2, "Rare"), alien(3, "Rare") }
		expect(Bay.remove(data, 1)).toEqual(alien(1, "Common"))
		expect(data.pods[2].alien).toBeNil()
		expect(Bay.remove(data, 2)).toEqual(alien(2, "Rare"))
		expect(uids(data.inventory)).toEqual({ 3 })
		expect(Bay.remove(data, 9)).toBeNil()
	end)
end)

describe("Bay.pickUp", function()
	it("moves a floor alien into the inventory while there is room", function()
		local data = fresh()
		data.floor = { alien(1, "Common"), alien(2, "Common"), alien(3, "Common") }
		expect(Bay.pickUp(data, 1, SLOTS)).toBe(true)
		expect(Bay.pickUp(data, 2, SLOTS)).toBe(true)
		expect(Bay.pickUp(data, 3, SLOTS)).toBe(false)
		expect(uids(data.inventory)).toEqual({ 1, 2 })
		expect(uids(data.floor)).toEqual({ 3 })
	end)

	it("ignores aliens that are not on the floor", function()
		local data = fresh()
		data.inventory = { alien(1, "Common") }
		expect(Bay.pickUp(data, 1, SLOTS)).toBe(false)
		expect(Bay.pickUp(data, 7, SLOTS)).toBe(false)
	end)
end)

describe("Bay.incomePerSecond", function()
	it("adds up the pods only", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Rare")
		data.pods[3].alien = alien(2, "Epic")
		data.inventory = { alien(3, "Epic") }
		expect(Bay.incomePerSecond(data, incomeOf).mantissa).toBe(20)
		expect(Bay.incomePerSecond(fresh(), incomeOf)).toBe(BigNum.ZERO)
	end)
end)

describe("Bay.autoPlace", function()
	it("puts the best earners in pods, the next in the inventory, the rest on the floor", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Common")
		data.pods[2].alien = alien(2, "Common")
		data.inventory = { alien(3, "Epic"), alien(4, "Common") }
		data.floor = { alien(5, "Rare"), alien(6, "Rare"), alien(7, "Common") }
		Bay.autoPlace(data, incomeOf, SLOTS)
		expect(podUids(data)).toEqual({ 3, 5, 6 })
		expect(uids(data.inventory)).toEqual({ 1, 2 })
		expect(uids(data.floor)).toEqual({ 4, 7 })
	end)

	it("changes nothing when run again", function()
		local data = fresh()
		data.inventory = { alien(3, "Epic"), alien(4, "Common") }
		data.floor = { alien(5, "Rare"), alien(6, "Rare"), alien(7, "Common"), alien(8, "Common") }
		Bay.autoPlace(data, incomeOf, SLOTS)
		local pods, inventory, floor = podUids(data), uids(data.inventory), uids(data.floor)
		Bay.autoPlace(data, incomeOf, SLOTS)
		expect(podUids(data)).toEqual(pods)
		expect(uids(data.inventory)).toEqual(inventory)
		expect(uids(data.floor)).toEqual(floor)
	end)

	it("leaves pods empty when there are fewer aliens than pods", function()
		local data = fresh()
		data.floor = { alien(1, "Common") }
		Bay.autoPlace(data, incomeOf, SLOTS)
		expect(podUids(data)).toEqual({ 1 })
		expect(Bay.freePods(data)).toBe(2)
		expect(#data.floor).toBe(0)
	end)
end)

describe("Bay.podPrice", function()
	it("grows from the first bought pod", function()
		local base, growth = BigNum.fromNumber(250), BigNum.fromNumber(3)
		expect(Bay.podPrice(3, 3, base, growth).mantissa).toBe(250)
		expect(Bay.podPrice(4, 3, base, growth).mantissa).toBe(750)
		expect(Bay.podPrice(5, 3, base, growth).mantissa).toBe(2250)
	end)

	it("never charges less than the base for a short profile", function()
		expect(Bay.podPrice(1, 3, BigNum.fromNumber(250), BigNum.fromNumber(3)).mantissa).toBe(250)
	end)
end)

describe("Bay.takeHatched", function()
	local function egg(uid: number, hatchAt: number): PlayerData.EggRecord
		return { uid = uid, rarity = "Common", size = "Small", grade = 1, hatchAt = hatchAt }
	end

	it("takes the eggs whose time has come, oldest first", function()
		local data = fresh()
		data.incubator = { egg(1, 300), egg(2, 100), egg(3, 500), egg(4, 200) }
		local hatched = Bay.takeHatched(data, 300)
		expect(uids(hatched :: any)).toEqual({ 2, 4, 1 })
		expect(uids(data.incubator :: any)).toEqual({ 3 })
	end)

	it("takes nothing before the time", function()
		local data = fresh()
		data.incubator = { egg(1, 300) }
		expect(Bay.takeHatched(data, 299)).toEqual({})
		expect(#data.incubator).toBe(1)
	end)
end)

describe("Bay incubator", function()
	it("puts an egg in with a fresh uid", function()
		local data = fresh()
		local egg = Bay.addEgg(data, "Rare", "Medium", 3, 1000)
		expect(data.incubator[#data.incubator]).toBe(egg)
		expect(egg.grade).toBe(3)
		expect(egg.hatchAt).toBe(1000)
		expect(Bay.addEgg(data, "Common", "Small", 1, 5).uid > egg.uid).toBe(true)
	end)

	it("keeps a meteor egg's variant and saves none for the usual one", function()
		local data = fresh()
		expect(Bay.addEgg(data, "Rare", "Medium", 3, 1000, "Meteor").variant).toBe("Meteor")
		expect(Bay.addEgg(data, "Rare", "Medium", 3, 1000, "Normal").variant).toBeNil()
		expect(Bay.addEgg(data, "Rare", "Medium", 3, 1000).variant).toBeNil()
	end)

	it("keeps an egg's extra luck and saves none for no luck", function()
		local data = fresh()
		expect(Bay.addEgg(data, "Rare", "Medium", 3, 1000, nil, 0.35).luck).toBe(0.35)
		expect(Bay.addEgg(data, "Rare", "Medium", 3, 1000, nil, 0).luck).toBeNil()
		expect(Bay.addEgg(data, "Rare", "Medium", 3, 1000).luck).toBeNil()
	end)

	it("runs faster: every egg comes closer to hatching", function()
		local data = fresh()
		Bay.addEgg(data, "Rare", "Medium", 1, 1000)
		Bay.addEgg(data, "Common", "Small", 1, 300)
		Bay.advanceIncubator(data, 290)
		expect(data.incubator[1].hatchAt).toBe(710)
		expect(data.incubator[2].hatchAt).toBe(10)
		expect(#Bay.takeHatched(data, 10)).toBe(1)
	end)
end)
