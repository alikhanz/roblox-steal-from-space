--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Tables = require("../../src/shared/Runtime/Tables")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = BigNum.fromNumber(10),
	startingPods = 3,
}

local function load(saved: unknown): PlayerData.LoadOutcome
	return PlayerData.load(saved, DEFAULTS)
end

local function savedTemplate(): { [string]: any }
	-- What a fresh profile looks like after a DataStore round trip: plain, unfrozen tables.
	return Tables.deepCopy(PlayerData.template(DEFAULTS)) :: any
end

local function alien(uid: number, id: string?): { [string]: any }
	return { uid = uid, id = id or "DebrisBelt1.Common" }
end

local function expectCorrupted(saved: unknown, detail: string)
	local outcome = load(saved)
	expect(outcome.ok).toBe(false)
	if not outcome.ok then
		expect(outcome.reason).toBe("Corrupted")
		expect(string.find(outcome.detail, detail, 1, true)).toBeTruthy()
	end
end

describe("PlayerData.template", function()
	it("starts with the configured speed and empty pods", function()
		local data = PlayerData.template(DEFAULTS)
		expect(data.speed).toBe(DEFAULTS.startingSpeed)
		expect(#data.pods).toBe(3)
		expect(data.pods[1].alien).toBeNil()
		expect(data.nextUid).toBe(1)
		expect(data.lastSeenAt).toBe(0)
	end)
end)

describe("PlayerData.load", function()
	it("loads a fresh profile", function()
		local outcome = load(savedTemplate())
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.coins).toBe(BigNum.ZERO)
			expect(outcome.data.speed).toEqual(DEFAULTS.startingSpeed)
		end
	end)

	it("restores saved BigNums as immutable values", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 1500, exponent = 0 }
		saved.speed = { mantissa = 2.5, exponent = 400 }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.coins.mantissa).toBe(1500)
			expect(outcome.data.speed.exponent).toBe(400)
			expect(table.isfrozen(outcome.data.coins :: any)).toBe(true)
			expect(table.isfrozen(outcome.data.speed :: any)).toBe(true)
		end
	end)

	it("keeps the bay as saved", function()
		local saved = savedTemplate()
		saved.pods = { { alien = alien(1) }, {}, { alien = alien(2, "DebrisBelt2.Rare") }, {} }
		saved.inventory = { alien(3) }
		saved.floor = { alien(4) }
		saved.incubator = { { uid = 5, rarity = "Rare", size = "Large", grade = 2, hatchAt = 1000 } }
		saved.nextUid = 6
		saved.lastSeenAt = 900
		local snapshot = Tables.deepCopy(saved)
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(#outcome.data.pods).toBe(4)
			expect(outcome.data.pods[3].alien).toEqual(snapshot.pods[3].alien)
			expect(outcome.data.inventory).toEqual(snapshot.inventory)
			expect(outcome.data.floor).toEqual(snapshot.floor)
			expect(outcome.data.incubator).toEqual(snapshot.incubator)
			expect(outcome.data.nextUid).toBe(6)
			expect(outcome.data.lastSeenAt).toBe(900)
		end
	end)

	it("gives back the starting pods to a save that lost them", function()
		local saved = savedTemplate()
		saved.pods = {}
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(#outcome.data.pods).toBe(DEFAULTS.startingPods)
		end
	end)

	it("moves the uid counter past every uid in use", function()
		local saved = savedTemplate()
		saved.floor = { alien(7) }
		saved.incubator = { { uid = 9, rarity = "Common", size = "Small", grade = 1, hatchAt = 0 } }
		saved.nextUid = 2
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.nextUid).toBe(10)
		end
	end)

	it("never modifies the saved table", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 42, exponent = 0 }
		local snapshot = Tables.deepCopy(saved)
		load(saved)
		expect(saved).toEqual(snapshot)
	end)

	it("refuses data from a newer version without touching it", function()
		local saved = savedTemplate()
		saved.schemaVersion = PlayerData.SCHEMA_VERSION + 1
		saved.futureField = "keep me"
		local snapshot = Tables.deepCopy(saved)

		local outcome = load(saved)
		expect(outcome.ok).toBe(false)
		if not outcome.ok then
			expect(outcome.reason).toBe("NewerVersion")
		end
		expect(saved).toEqual(snapshot)
	end)

	it("treats broken data as corrupted", function()
		local noVersion = savedTemplate()
		noVersion.schemaVersion = nil
		expectCorrupted(noVersion, "InvalidVersion")
		expectCorrupted("not a table", "saved data is a string")

		local cases: { { patch: (data: { [string]: any }) -> (), detail: string } } = {
			{
				patch = function(data)
					data.coins = { mantissa = "lots", exponent = 0 }
				end,
				detail = "coins",
			},
			{
				patch = function(data)
					data.speed = 10
				end,
				detail = "speed",
			},
			{
				patch = function(data)
					data.pods = "three"
				end,
				detail = "pods is not a list",
			},
			{
				patch = function(data)
					data.pods = { { alien = alien(1) }, { alien = alien(1) }, {} }
				end,
				detail = "uid 1 repeats",
			},
			{
				patch = function(data)
					data.inventory = { alien(1), alien(2) }
					data.floor = { alien(2) }
				end,
				detail = "floor: uid 2 repeats",
			},
			{
				patch = function(data)
					data.inventory = { { uid = 1.5, id = "DebrisBelt1.Common" } }
				end,
				detail = "uid is invalid",
			},
			{
				patch = function(data)
					data.floor = { { uid = 1, id = "" } }
				end,
				detail = "alien id is invalid",
			},
			{
				patch = function(data)
					data.floor = { [2] = alien(1) }
				end,
				detail = "floor is not a proper list",
			},
			{
				patch = function(data)
					data.incubator = { { uid = 1, rarity = "Common", size = "Small", grade = 1 } }
				end,
				detail = "egg hatch time is invalid",
			},
			{
				patch = function(data)
					data.incubator = { { uid = 1, rarity = "Common", size = "Small", grade = 0, hatchAt = 1 } }
				end,
				detail = "egg grade is invalid",
			},
			{
				patch = function(data)
					data.nextUid = 0
				end,
				detail = "nextUid is invalid",
			},
			{
				patch = function(data)
					data.lastSeenAt = -1
				end,
				detail = "lastSeenAt is invalid",
			},
		}
		for _, case in cases do
			local saved = savedTemplate()
			case.patch(saved)
			expectCorrupted(saved, case.detail)
		end
	end)
end)

describe("PlayerData migration v1 -> v2", function()
	local function v1Save(): { [string]: any }
		return { schemaVersion = 1, coins = { mantissa = 250, exponent = 0 } }
	end

	it("keeps the coins and fills the bay with starting values", function()
		local outcome = load(v1Save())
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			local data = outcome.data
			expect(data.schemaVersion).toBe(2)
			expect(data.coins.mantissa).toBe(250)
			expect(data.speed).toEqual(DEFAULTS.startingSpeed)
			expect(#data.pods).toBe(DEFAULTS.startingPods)
			expect(data.inventory).toEqual({})
			expect(data.floor).toEqual({})
			expect(data.incubator).toEqual({})
			expect(data.nextUid).toBe(1)
			expect(data.lastSeenAt).toBe(0)
		end
	end)

	it("gives the same result when run again on migrated data", function()
		local first = load(v1Save())
		expect(first.ok).toBe(true)
		if first.ok then
			local second = load(Tables.deepCopy(first.data))
			expect(second.ok).toBe(true)
			if second.ok then
				expect(second.data).toEqual(first.data)
			end
		end
	end)
end)
