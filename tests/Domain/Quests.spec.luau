--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Quests = require("../../src/shared/Domain/Quests")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local POOL: { Quests.Definition } = {
	{ kind = "DeliverEggs", weight = 3, minTarget = 3, maxTarget = 5, rewardMinutes = 10 },
	{ kind = "DeliverFromZone", weight = 2, minTarget = 1, maxTarget = 1, rewardMinutes = 8 },
	{ kind = "HatchAliens", weight = 3, minTarget = 3, maxTarget = 5, rewardMinutes = 8 },
	{ kind = "Train", weight = 2, minTarget = 300, maxTarget = 300, rewardMinutes = 7 },
	{ kind = "Crossbreed", weight = 1, minTarget = 1, maxTarget = 1, rewardMinutes = 7, requires = "CanCrossbreed" },
	{ kind = "KnockEgg", weight = 1, minTarget = 1, maxTarget = 1, rewardMinutes = 10, requires = "CanFight" },
}

local NEWBIE: Quests.Context = { zone = "DebrisBelt", canCrossbreed = false, canFight = false }
local VETERAN: Quests.Context = { zone = "IceRings", canCrossbreed = true, canFight = true }

-- math.random as the random source the domain takes.
local function uniform(): number
	return math.random()
end

-- A fixed sequence of random numbers, repeated.
local function sequence(values: { number }): () -> number
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

local function kinds(list: { Quests.Record }): { string }
	local result = {}
	for _, record in list do
		table.insert(result, record.kind)
	end
	return result
end

local function record(kind: string, target: number, zone: string?): Quests.Record
	return { kind = kind, target = target, progress = 0, claimed = false, zone = zone }
end

local function stateWith(list: { Quests.Record }): Quests.State
	return { day = 100, rerolled = false, list = list }
end

describe("Quests days", function()
	it("counts UTC days from the epoch", function()
		expect(Quests.dayOf(0)).toBe(0)
		expect(Quests.dayOf(86399)).toBe(0)
		expect(Quests.dayOf(86400)).toBe(1)
	end)

	it("counts the seconds left to midnight", function()
		expect(Quests.secondsLeftInDay(86400 * 5 + 600)).toBe(86400 - 600)
	end)
end)

describe("Quests.roll", function()
	it("gives quests of different kinds", function()
		for seed = 1, 20 do
			math.randomseed(seed)
			local list = Quests.roll(POOL, VETERAN, 3, uniform)
			expect(#list).toBe(3)
			local seen = {}
			for _, item in list do
				expect(seen[item.kind]).toBeNil()
				seen[item.kind] = true
			end
		end
	end)

	it("never gives a newbie quests they cannot do", function()
		for seed = 1, 50 do
			math.randomseed(seed)
			local list = Quests.roll(POOL, NEWBIE, 3, uniform)
			for _, item in list do
				expect(item.kind ~= "KnockEgg" and item.kind ~= "Crossbreed").toBe(true)
			end
		end
	end)

	it("picks targets inside the range", function()
		local low = Quests.roll({ POOL[1] }, NEWBIE, 1, sequence({ 0 }))
		local high = Quests.roll({ POOL[1] }, NEWBIE, 1, sequence({ 0.999 }))
		expect(low[1].target).toBe(3)
		expect(high[1].target).toBe(5)
	end)

	it("asks for the player's frontier zone", function()
		local list = Quests.roll({ POOL[2] }, VETERAN, 1, sequence({ 0.5 }))
		expect(list[1].zone).toBe("IceRings")
	end)

	it("gives fewer when the pool runs out", function()
		expect(#Quests.roll({ POOL[1], POOL[6] }, NEWBIE, 3, sequence({ 0.5 }))).toBe(1)
	end)
end)

describe("Quests.ensureDay", function()
	it("gives a fresh set and a fresh swap on a new day only", function()
		local state = Quests.empty()
		state.rerolled = true
		expect(Quests.ensureDay(state, 20000, POOL, VETERAN, 3, sequence({ 0.1, 0.5, 0.9 }))).toBe(true)
		expect(state.day).toBe(20000)
		expect(state.rerolled).toBe(false)
		expect(#state.list).toBe(3)
		local before = kinds(state.list)
		expect(Quests.ensureDay(state, 20000, POOL, VETERAN, 3, sequence({ 0.7 }))).toBe(false)
		expect(kinds(state.list)).toEqual(before)
	end)
end)

describe("Quests.advance", function()
	it("counts deliveries for both delivery quests when the zone matches", function()
		local state = stateWith({ record("DeliverEggs", 3), record("DeliverFromZone", 1, "IceRings") })
		Quests.advance(state, { kind = "Delivered", zone = "DebrisBelt" })
		expect(state.list[1].progress).toBe(1)
		expect(state.list[2].progress).toBe(0)
		local finished = Quests.advance(state, { kind = "Delivered", zone = "IceRings" })
		expect(state.list[1].progress).toBe(2)
		expect(finished).toEqual({ 2 })
	end)

	it("adds trained seconds and stops at the target", function()
		local state = stateWith({ record("Train", 300) })
		Quests.advance(state, { kind = "Trained", seconds = 299.75 })
		local finished = Quests.advance(state, { kind = "Trained", seconds = 0.5 })
		expect(state.list[1].progress).toBe(300)
		expect(finished).toEqual({ 1 })
	end)

	it("reports a change only when a quest moved", function()
		local state = stateWith({ record("HatchAliens", 3) })
		local _, changed = Quests.advance(state, { kind = "Crossbred" })
		expect(changed).toBe(false)
		local _, moved = Quests.advance(state, { kind = "Hatched" })
		expect(moved).toBe(true)
	end)

	it("leaves finished quests alone", function()
		local state = stateWith({ record("KnockEgg", 1) })
		Quests.advance(state, { kind = "KnockedEgg" })
		local finished, changed = Quests.advance(state, { kind = "KnockedEgg" })
		expect(finished).toEqual({})
		expect(changed).toBe(false)
	end)
end)

describe("Quests.claim", function()
	it("claims a finished quest once", function()
		local state = stateWith({ record("Crossbreed", 1) })
		expect(Quests.claim(state, 1)).toBe("QuestNotDone")
		Quests.advance(state, { kind = "Crossbred" })
		expect(Quests.claim(state, 1)).toBeNil()
		expect(state.list[1].claimed).toBe(true)
		expect(Quests.claim(state, 1)).toBe("QuestClaimed")
	end)

	it("refuses a quest that is not there", function()
		expect(Quests.claim(stateWith({}), 2)).toBe("NoSuchQuest")
	end)
end)

describe("Quests.reroll", function()
	it("swaps one quest for a kind not on the list, once a day", function()
		local state = stateWith({ record("DeliverEggs", 3), record("HatchAliens", 3), record("Train", 300) })
		expect(Quests.reroll(state, 2, POOL, NEWBIE, sequence({ 0.5 }))).toBeNil()
		expect(state.list[2].kind).toBe("DeliverFromZone")
		expect(state.rerolled).toBe(true)
		expect(Quests.reroll(state, 1, POOL, NEWBIE, sequence({ 0.5 }))).toBe("RerollUsed")
	end)

	it("does not swap a finished quest", function()
		local state = stateWith({ record("KnockEgg", 1) })
		Quests.advance(state, { kind = "KnockedEgg" })
		expect(Quests.reroll(state, 1, POOL, VETERAN, sequence({ 0.5 }))).toBe("QuestDone")
		expect(state.rerolled).toBe(false)
	end)

	it("says so when there is nothing else to give", function()
		local state = stateWith({ record("DeliverEggs", 3) })
		expect(Quests.reroll(state, 1, { POOL[1] }, NEWBIE, sequence({ 0.5 }))).toBe("NoOtherQuest")
		expect(state.rerolled).toBe(false)
	end)
end)

describe("Quests.reward", function()
	it("pays minutes of income and trainer rate", function()
		local coins, trained = Quests.reward(10, BigNum.fromNumber(5), BigNum.fromNumber(2), BigNum.fromNumber(200))
		expect(coins).toEqual(BigNum.fromNumber(3000))
		expect(trained).toEqual(BigNum.fromNumber(1200))
	end)

	it("pays at least the minimum coins", function()
		local coins = Quests.reward(7, BigNum.ZERO, BigNum.ONE, BigNum.fromNumber(200))
		expect(coins).toEqual(BigNum.fromNumber(200))
	end)

	it("scales past the plain number range", function()
		local coins = Quests.reward(10, BigNum.new(1, 400), BigNum.ONE, BigNum.fromNumber(200))
		expect(coins).toEqual(BigNum.new(6, 402))
	end)
end)
