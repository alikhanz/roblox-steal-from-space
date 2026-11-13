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
	it("fills the first free pod, then the shelf", function()
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

describe("Bay.hasRoom", function()
	it("is true with a free pod or a free niche, false with neither", function()
		local data = fresh()
		expect(Bay.hasRoom(data, 2)).toBe(true)
		for uid = 1, 3 do
			Bay.addHatched(data, alien(uid, "Common"))
		end
		expect(Bay.hasRoom(data, 2)).toBe(true)
		data.floor = { alien(4, "Common") }
		expect(Bay.hasRoom(data, 2)).toBe(true)
		table.insert(data.floor, alien(5, "Common"))
		expect(Bay.hasRoom(data, 2)).toBe(false)
		-- A shelf over its size (an old profile) has no room either.
		table.insert(data.floor, alien(6, "Common"))
		expect(Bay.hasRoom(data, 2)).toBe(false)
		data.pods[1].alien = nil
		expect(Bay.hasRoom(data, 2)).toBe(true)
	end)
end)

describe("Bay.find and Bay.remove", function()
	it("finds aliens wherever they are", function()
		local data = fresh()
		data.pods[2].alien = alien(1, "Common")
		data.floor = { alien(3, "Epic") }
		local _, where = Bay.find(data, 1)
		expect(where).toBe("Pod")
		_, where = Bay.find(data, 3)
		expect(where).toBe("Floor")
		expect(Bay.find(data, 4)).toBeNil()
	end)

	it("removes an alien and leaves the rest in place", function()
		local data = fresh()
		data.pods[2].alien = alien(1, "Common")
		data.floor = { alien(2, "Rare"), alien(3, "Rare") }
		expect(Bay.remove(data, 1)).toEqual(alien(1, "Common"))
		expect(data.pods[2].alien).toBeNil()
		expect(Bay.remove(data, 2)).toEqual(alien(2, "Rare"))
		expect(uids(data.floor)).toEqual({ 3 })
		expect(Bay.remove(data, 9)).toBeNil()
	end)
end)

describe("Bay.removeMany", function()
	it("takes out every alien named, from pods and the shelf", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Rare")
		data.floor = { alien(2, "Common"), alien(3, "Common"), alien(4, "Epic") }
		local removed = Bay.removeMany(data, { 3, 1 })
		expect(removed and uids(removed)).toEqual({ 3, 1 })
		expect(data.pods[1].alien).toBeNil()
		expect(uids(data.floor)).toEqual({ 2, 4 })
	end)

	it("takes out none when a uid repeats or is not the player's", function()
		local data = fresh()
		data.floor = { alien(2, "Common"), alien(3, "Common") }
		expect(Bay.removeMany(data, { 2, 2 })).toBeNil()
		expect(Bay.removeMany(data, { 2, 9 })).toBeNil()
		expect(uids(data.floor)).toEqual({ 2, 3 })
	end)
end)

describe("Bay.fillPod", function()
	it("puts the best of the shelf into an empty pod", function()
		local data = fresh()
		data.floor = { alien(1, "Common"), alien(2, "Epic"), alien(3, "Rare"), alien(4, "Epic") }
		local moved = Bay.fillPod(data, 2, incomeOf)
		expect(moved and moved.uid).toBe(2)
		expect(podUids(data)).toEqual({ nil, 2 })
		expect(uids(data.floor)).toEqual({ 1, 3, 4 })
	end)

	it("does nothing for a taken or missing pod, or an empty shelf", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Common")
		data.floor = { alien(2, "Epic") }
		expect(Bay.fillPod(data, 1, incomeOf)).toBeNil()
		expect(Bay.fillPod(data, 9, incomeOf)).toBeNil()
		expect(Bay.fillPod(fresh(), 1, incomeOf)).toBeNil()
		expect(uids(data.floor)).toEqual({ 2 })
	end)
end)

describe("Bay.moveToPod", function()
	it("swaps a shelf alien with the one in the pod, in its place on the shelf", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Common")
		data.floor = { alien(2, "Rare"), alien(3, "Epic"), alien(4, "Rare") }
		expect(Bay.moveToPod(data, 3, 1)).toBe(true)
		expect(podUids(data)).toEqual({ 3 })
		expect(uids(data.floor)).toEqual({ 2, 1, 4 })
	end)

	it("takes a shelf alien off the shelf into an empty pod", function()
		local data = fresh()
		data.floor = { alien(2, "Rare"), alien(3, "Epic") }
		expect(Bay.moveToPod(data, 2, 3)).toBe(true)
		expect(podUids(data)).toEqual({ nil, nil, 2 })
		expect(uids(data.floor)).toEqual({ 3 })
	end)

	it("swaps two pods without touching the shelf", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Common")
		data.pods[2].alien = alien(2, "Rare")
		data.floor = { alien(5, "Epic") }
		expect(Bay.moveToPod(data, 1, 2)).toBe(true)
		expect(podUids(data)).toEqual({ 2, 1 })
		expect(Bay.moveToPod(data, 1, 3)).toBe(true)
		expect(podUids(data)).toEqual({ 2, nil, 1 })
		expect(uids(data.floor)).toEqual({ 5 })
	end)

	it("refuses an unknown alien or pod", function()
		local data = fresh()
		data.floor = { alien(2, "Rare") }
		expect(Bay.moveToPod(data, 9, 1)).toBe(false)
		expect(Bay.moveToPod(data, 2, 9)).toBe(false)
		expect(uids(data.floor)).toEqual({ 2 })
	end)
end)

describe("Bay.toShelf", function()
	it("moves an alien from its pod to the end of the shelf while there is room", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Common")
		data.pods[2].alien = alien(2, "Rare")
		data.floor = { alien(3, "Epic") }
		expect(Bay.toShelf(data, 1, SLOTS)).toBe(true)
		expect(uids(data.floor)).toEqual({ 3, 1 })
		expect(Bay.toShelf(data, 2, SLOTS)).toBe(false)
		expect(podUids(data)).toEqual({ nil, 2 })
	end)

	it("refuses an alien that is not in a pod", function()
		local data = fresh()
		data.floor = { alien(3, "Epic") }
		expect(Bay.toShelf(data, 3, SLOTS)).toBe(false)
		expect(Bay.toShelf(data, 9, SLOTS)).toBe(false)
	end)
end)

describe("Bay.incomePerSecond", function()
	it("adds up the pods only", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Rare")
		data.pods[3].alien = alien(2, "Epic")
		data.floor = { alien(3, "Epic") }
		expect(Bay.incomePerSecond(data, incomeOf).mantissa).toBe(20)
		expect(Bay.incomePerSecond(fresh(), incomeOf)).toBe(BigNum.ZERO)
	end)
end)

describe("Bay.autoPlace", function()
	it("puts the best earners in pods and the rest on the shelf, best first", function()
		local data = fresh()
		data.pods[1].alien = alien(1, "Common")
		data.pods[2].alien = alien(2, "Common")
		data.floor = { alien(3, "Epic"), alien(4, "Common"), alien(5, "Rare"), alien(6, "Rare"), alien(7, "Common") }
		Bay.autoPlace(data, incomeOf)
		expect(podUids(data)).toEqual({ 3, 5, 6 })
		expect(uids(data.floor)).toEqual({ 1, 2, 4, 7 })
	end)

	it("changes nothing when run again", function()
		local data = fresh()
		data.floor = { alien(3, "Epic"), alien(4, "Common"), alien(5, "Rare"), alien(6, "Rare"), alien(7, "Common") }
		Bay.autoPlace(data, incomeOf)
		local pods, floor = podUids(data), uids(data.floor)
		Bay.autoPlace(data, incomeOf)
		expect(podUids(data)).toEqual(pods)
		expect(uids(data.floor)).toEqual(floor)
	end)

	it("leaves pods empty when there are fewer aliens than pods", function()
		local data = fresh()
		data.floor = { alien(1, "Common") }
		Bay.autoPlace(data, incomeOf)
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

describe("Bay.hatch", function()
	local function egg(uid: number, hatchAt: number): PlayerData.EggRecord
		return { uid = uid, rarity = "Common", size = "Small", grade = 1, hatchAt = hatchAt }
	end
	local function waitingEgg(uid: number, hatchSeconds: number): PlayerData.WaitingEgg
		return { uid = uid, rarity = "Common", size = "Small", grade = 1, hatchSeconds = hatchSeconds }
	end

	it("counts the eggs whose time has come as ready, and they keep their slots", function()
		local data = fresh()
		data.incubatorSlots = 4
		data.incubator = { egg(1, 300), egg(2, 100), egg(3, 500), egg(4, 200) }
		expect(Bay.readyCount(data, 300)).toBe(3)
		expect(Bay.isReady(data.incubator[3], 300)).toBe(false)
		expect(#data.incubator).toBe(4)
	end)

	it("hatches a ready egg and gives it back", function()
		local data = fresh()
		data.incubator = { egg(1, 300), egg(2, 100) }
		local hatched = Bay.hatch(data, 2, 150)
		expect((hatched :: PlayerData.EggRecord).uid).toBe(2)
		expect(uids(data.incubator :: any)).toEqual({ 1 })
	end)

	it("does not hatch an egg before its time, or one that is not there", function()
		local data = fresh()
		data.incubator = { egg(1, 300) }
		expect(Bay.hatch(data, 1, 299)).toBeNil()
		expect(Bay.hatch(data, 7, 1000)).toBeNil()
		expect(#data.incubator).toBe(1)
	end)

	it("moves the first waiting egg into the slot, warming from the hatch", function()
		local data = fresh()
		data.incubator = { egg(1, 100), egg(2, 1000) }
		data.waiting = { waitingEgg(3, 50), waitingEgg(4, 400) }
		Bay.hatch(data, 1, 120)
		-- Egg 3 starts when egg 1 is hatched, at 120, not when it was ready at 100.
		expect(uids(data.incubator :: any)).toEqual({ 2, 3 })
		expect(data.incubator[2].hatchAt).toBe(170)
		expect(uids(data.waiting :: any)).toEqual({ 4 })
	end)

	it("keeps the queue waiting while ready eggs are not hatched, however long", function()
		local data = fresh()
		data.incubator = { egg(1, 100), egg(2, 200) }
		data.waiting = { waitingEgg(3, 50) }
		expect(Bay.readyCount(data, 100000)).toBe(2)
		expect(#data.waiting).toBe(1)
		expect(data.waiting[1].hatchSeconds).toBe(50)
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
		Bay.hatch(data, data.incubator[1].uid, 10)
		expect(data.incubator[1].luck).toBe(0.7)
	end)

	it("runs faster: every egg in a slot comes closer to being ready", function()
		local data = fresh()
		Bay.addEgg(data, "Rare", "Medium", 1, 1000, 0)
		Bay.addEgg(data, "Common", "Small", 1, 300, 0)
		Bay.advanceIncubator(data, 290)
		expect(data.incubator[1].hatchAt).toBe(710)
		expect(data.incubator[2].hatchAt).toBe(10)
		expect(Bay.readyCount(data, 10)).toBe(1)
	end)

	it("prices slots like pods: the base for the first bought one, then growing", function()
		local base, growth = BigNum.fromNumber(150), BigNum.fromNumber(3)
		expect(BigNum.toNumber(Bay.slotPrice(2, 2, base, growth))).toBe(150)
		expect(BigNum.toNumber(Bay.slotPrice(3, 2, base, growth))).toBe(450)
	end)
end)

describe("Bay.capsulesFor", function()
	it("puts new eggs into the first free capsules, in order", function()
		local capsules = Bay.capsulesFor({ 7, 8, 9 }, {}, 4)
		expect(capsules[7]).toBe(1)
		expect(capsules[8]).toBe(2)
		expect(capsules[9]).toBe(3)
	end)

	it("keeps every other egg in its capsule when one hatches", function()
		local capsules = Bay.capsulesFor({ 8, 9 }, { [7] = 1, [8] = 2, [9] = 3 }, 4)
		expect(capsules[8]).toBe(2)
		expect(capsules[9]).toBe(3)
		expect(capsules[7]).toBeNil()
	end)

	it("gives the freed capsule to the egg that comes from the queue", function()
		local capsules = Bay.capsulesFor({ 8, 9, 10 }, { [8] = 2, [9] = 3 }, 4)
		expect(capsules[10]).toBe(1)
	end)

	it("moves an egg whose capsule is gone into a free one", function()
		local capsules = Bay.capsulesFor({ 5, 6 }, { [5] = 4, [6] = 1 }, 2)
		expect(capsules[6]).toBe(1)
		expect(capsules[5]).toBe(2)
	end)
end)

describe("Bay.newAlien", function()
	it("gives a new uid and an outfit drawn from the alien's tier's pools", function()
		local AlienConfig = require("../../src/shared/Config/AlienConfig")
		local AlienOutfit = require("../../src/shared/Domain/AlienOutfit")
		local data = fresh()
		local nextInteger = AlienOutfit.sequence(4)
		local seen: { [number]: boolean } = {}
		for _, tier in AlienConfig.TIER_ORDER do
			local id = AlienConfig.GRADES[1].aliens[tier]
			local record = Bay.newAlien(data, id, nextInteger)
			expect(seen[record.uid]).toBeNil()
			seen[record.uid] = true
			expect(record.id).toBe(id)
			local outfit = record.outfit :: AlienOutfit.Picks
			expect(outfit).toBeTruthy()
			for _, slot in AlienOutfit.SLOTS do
				local piece = (outfit :: any)[slot]
				if piece then
					expect(AlienOutfit.isPiece(slot, piece)).toBe(true)
				end
			end
			if tier == "Legendary" then
				expect(outfit.head).toBe("crown")
			elseif tier == "Common" then
				expect(outfit.back).toBeNil()
			end
		end
	end)
end)
