--!strict

local Bay = require("../../src/shared/Domain/Bay")
local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = BigNum.fromNumber(10),
	startingPods = 3,
	startingIncubatorSlots = 2,
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
	local function waitingEgg(uid: number, hatchSeconds: number): PlayerData.WaitingEgg
		return { uid = uid, rarity = "Common", size = "Small", grade = 1, hatchSeconds = hatchSeconds }
	end

	it("takes the eggs whose time has come, in the order they hatched", function()
		local data = fresh()
		data.incubatorSlots = 4
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

	it("moves the first waiting egg into a freed slot, warming from when the slot freed", function()
		local data = fresh()
		data.incubator = { egg(1, 100), egg(2, 1000) }
		data.waiting = { waitingEgg(3, 50), waitingEgg(4, 400) }
		local hatched = Bay.takeHatched(data, 120)
		expect(uids(hatched :: any)).toEqual({ 1 })
		-- Egg 3 started at 100, when egg 1 hatched: it hatches at 150, not 170.
		expect(uids(data.incubator :: any)).toEqual({ 2, 3 })
		expect(data.incubator[2].hatchAt).toBe(150)
		expect(uids(data.waiting :: any)).toEqual({ 4 })
	end)

	it("runs the queue through a long time away", function()
		local data = fresh()
		data.incubator = { egg(1, 100), egg(2, 200) }
		data.waiting = { waitingEgg(3, 50), waitingEgg(4, 50), waitingEgg(5, 1000) }
		local hatched = Bay.takeHatched(data, 400)
		-- 1 at 100, then 3 (100 -> 150), 4 (150 -> 200) and 2 at 200, then 5 (200 -> 1200).
		expect(uids(hatched :: any)).toEqual({ 1, 3, 2, 4 })
		expect(#data.waiting).toBe(0)
		expect(uids(data.incubator :: any)).toEqual({ 5 })
		expect(data.incubator[1].hatchAt).toBe(1200)
	end)
end)

describe("Bay incubator", function()
	it("puts an egg into a free slot, warming from now, with a fresh uid", function()
		local data = fresh()
		local uid = Bay.addEgg(data, "Rare", "Medium", 3, 600, 1000)
		local egg = data.incubator[#data.incubator]
		expect(egg.uid).toBe(uid)
		expect(egg.grade).toBe(3)
		expect(egg.hatchAt).toBe(1600)
		expect(Bay.addEgg(data, "Common", "Small", 1, 5, 1000) > uid).toBe(true)
	end)

	it("queues an egg once every slot is taken, and warms none of the queue", function()
		local data = fresh()
		for _ = 1, DEFAULTS.startingIncubatorSlots + 2 do
			Bay.addEgg(data, "Common", "Small", 1, 60, 0)
		end
		expect(#data.incubator).toBe(DEFAULTS.startingIncubatorSlots)
		expect(#data.waiting).toBe(2)
		Bay.advanceIncubator(data, 30)
		expect(data.waiting[1].hatchSeconds).toBe(60)
	end)

	it("fills a slot bought with the first waiting egg, warming from now", function()
		local data = fresh()
		for _ = 1, DEFAULTS.startingIncubatorSlots + 1 do
			Bay.addEgg(data, "Common", "Small", 1, 60, 0)
		end
		data.incubatorSlots += 1
		Bay.fillSlots(data, 500)
		expect(#data.waiting).toBe(0)
		expect(data.incubator[#data.incubator].hatchAt).toBe(560)
	end)

	it("keeps a meteor egg's variant and saves none for the usual one", function()
		local data = fresh()
		data.incubatorSlots = 3
		Bay.addEgg(data, "Rare", "Medium", 3, 60, 0, "Meteor")
		Bay.addEgg(data, "Rare", "Medium", 3, 60, 0, "Normal")
		Bay.addEgg(data, "Rare", "Medium", 3, 60, 0)
		expect(data.incubator[1].variant).toBe("Meteor")
		expect(data.incubator[2].variant).toBeNil()
		expect(data.incubator[3].variant).toBeNil()
	end)

	it("keeps an egg's extra luck through the queue and saves none for no luck", function()
		local data = fresh()
		data.incubatorSlots = 1
		Bay.addEgg(data, "Rare", "Medium", 3, 10, 0, nil, 0)
		Bay.addEgg(data, "Rare", "Medium", 3, 10, 0, nil, 0.7)
		expect(data.incubator[1].luck).toBeNil()
		expect(data.waiting[1].luck).toBe(0.7)
		Bay.takeHatched(data, 10)
		expect(data.incubator[1].luck).toBe(0.7)
	end)

	it("runs faster: every egg in a slot comes closer to hatching", function()
		local data = fresh()
		Bay.addEgg(data, "Rare", "Medium", 1, 1000, 0)
		Bay.addEgg(data, "Common", "Small", 1, 300, 0)
		Bay.advanceIncubator(data, 290)
		expect(data.incubator[1].hatchAt).toBe(710)
		expect(data.incubator[2].hatchAt).toBe(10)
		expect(#Bay.takeHatched(data, 10)).toBe(1)
	end)

	it("prices slots like pods: the base for the first bought one, then growing", function()
		local base, growth = BigNum.fromNumber(150), BigNum.fromNumber(3)
		expect(BigNum.toNumber(Bay.slotPrice(2, 2, base, growth))).toBe(150)
		expect(BigNum.toNumber(Bay.slotPrice(3, 2, base, growth))).toBe(450)
	end)
end)
