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
		expect(data.trained).toBe(DEFAULTS.startingSpeed)
		expect(data.trainerLevel).toBe(0)
		expect(data.jetpackLevel).toBe(0)
		expect(#data.pods).toBe(3)
		expect(data.pods[1].alien).toBeNil()
		expect(data.nextUid).toBe(1)
		expect(data.lastSeenAt).toBe(0)
		expect(data.playSeconds).toBe(0)
	end)
end)

describe("PlayerData.load", function()
	it("loads a fresh profile", function()
		local outcome = load(savedTemplate())
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.coins).toBe(BigNum.ZERO)
			expect(outcome.data.trained).toEqual(DEFAULTS.startingSpeed)
		end
	end)

	it("restores saved BigNums as immutable values", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 1500, exponent = 0 }
		saved.trained = { mantissa = 2.5, exponent = 400 }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.coins.mantissa).toBe(1500)
			expect(outcome.data.trained.exponent).toBe(400)
			expect(table.isfrozen(outcome.data.coins :: any)).toBe(true)
			expect(table.isfrozen(outcome.data.trained :: any)).toBe(true)
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
					data.trained = 10
				end,
				detail = "trained",
			},
			{
				patch = function(data)
					data.trainerLevel = -1
				end,
				detail = "trainerLevel is invalid",
			},
			{
				patch = function(data)
					data.jetpackLevel = 1.5
				end,
				detail = "jetpackLevel is invalid",
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
			{
				patch = function(data)
					data.playSeconds = "lots"
				end,
				detail = "playSeconds is invalid",
			},
			{
				patch = function(data)
					data.onboardingSteps = 1.5
				end,
				detail = "onboardingSteps is invalid",
			},
			{
				patch = function(data)
					data.bestPost = -1
				end,
				detail = "bestPost is invalid",
			},
			{
				patch = function(data)
					data.coinsEarned = "lots"
				end,
				detail = "coinsEarned is not a valid BigNum",
			},
			{
				patch = function(data)
					data.coinsEarned = { mantissa = -5, exponent = 0 }
				end,
				detail = "coinsEarned is negative",
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
			expect(data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(data.coins.mantissa).toBe(250)
			expect(data.trained).toEqual(DEFAULTS.startingSpeed)
			expect(data.trainerLevel).toBe(0)
			expect(data.jetpackLevel).toBe(0)
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

describe("PlayerData migration v2 -> v3", function()
	local function v2Save(): { [string]: any }
		local saved = savedTemplate()
		saved.schemaVersion = 2
		saved.trained = nil
		saved.trainerLevel = nil
		saved.jetpackLevel = nil
		saved.speed = { mantissa = 2500, exponent = 0 }
		saved.pods = { { alien = alien(1) }, {}, {} }
		saved.nextUid = 2
		return saved
	end

	it("keeps the old speed as the trained speed and starts the levels at zero", function()
		local outcome = load(v2Save())
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			local data = outcome.data
			expect(data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(data.trained.mantissa).toBe(2500)
			expect(data.trainerLevel).toBe(0)
			expect(data.jetpackLevel).toBe(0)
			expect((data :: any).speed).toBeNil()
			expect(data.pods[1].alien).toEqual(alien(1))
		end
	end)
end)

describe("PlayerData migration v3 -> v4", function()
	it("starts the play time at zero and keeps the rest", function()
		local saved = savedTemplate()
		saved.schemaVersion = 3
		saved.playSeconds = nil
		saved.trainerLevel = 4
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.playSeconds).toBe(0)
			expect(outcome.data.trainerLevel).toBe(4)
		end
	end)
end)

describe("PlayerData migration v4 -> v5", function()
	it("starts the funnel and the progression from nothing and keeps the rest", function()
		local saved = savedTemplate()
		saved.schemaVersion = 4
		saved.onboardingSteps = nil
		saved.bestPost = nil
		saved.playSeconds = 300
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.onboardingSteps).toBe(0)
			expect(outcome.data.bestPost).toBe(0)
			expect(outcome.data.playSeconds).toBe(300)
		end
	end)
end)

describe("PlayerData migration v5 -> v6", function()
	it("starts the coins earned from the balance and keeps the rest", function()
		local saved = savedTemplate()
		saved.schemaVersion = 5
		saved.coinsEarned = nil
		saved.coins = { mantissa = 2.5, exponent = 400 }
		saved.bestPost = 3
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.coinsEarned).toEqual(BigNum.new(2.5, 400))
			expect(outcome.data.coins).toEqual(BigNum.new(2.5, 400))
			expect(outcome.data.bestPost).toBe(3)
		end
	end)
end)

describe("PlayerData migration v6 -> v7", function()
	it("starts with no quests and keeps the rest", function()
		local saved = savedTemplate()
		saved.schemaVersion = 6
		saved.quests = nil
		saved.coinsEarned = { mantissa = 900, exponent = 0 }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.quests.day).toBe(0)
			expect(outcome.data.quests.rerolled).toBe(false)
			expect(#outcome.data.quests.list).toBe(0)
			expect(outcome.data.coinsEarned).toEqual(BigNum.fromNumber(900))
		end
	end)
end)

describe("PlayerData migration v8 -> v9", function()
	it("finds the aliens the player has, with their rewards taken", function()
		local saved = savedTemplate()
		saved.schemaVersion = 8
		saved.index = nil
		saved.pods = { { alien = alien(1, "DebrisBelt1.Common") }, {}, { alien = alien(2, "IceRings2.Epic") } }
		saved.inventory = { alien(3, "DebrisBelt1.Rare") }
		saved.floor = { alien(4, "DebrisBelt1.Common") }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.index.found).toEqual({
				["DebrisBelt1.Common"] = true,
				["IceRings2.Epic"] = true,
				["DebrisBelt1.Rare"] = true,
			})
			expect(outcome.data.index.sets).toEqual({})
		end
	end)

	it("rejects a broken index", function()
		local saved = savedTemplate()
		saved.index = { found = { ["DebrisBelt1.Common"] = "yes" }, sets = {} }
		expectCorrupted(saved, "index found is invalid")
		local other = savedTemplate()
		other.index = { found = {}, sets = { 0 } }
		expectCorrupted(other, "index sets is invalid")
	end)
end)

describe("PlayerData migration v7 -> v8", function()
	it("starts the login gift streak from nothing and keeps the rest", function()
		local saved = savedTemplate()
		saved.schemaVersion = 7
		saved.loginGift = nil
		saved.quests = { day = 20000, rerolled = true, list = {} }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.loginGift).toEqual({ lastDay = 0, streak = 0 })
			expect(outcome.data.quests.rerolled).toBe(true)
		end
	end)

	it("rejects a broken streak", function()
		local saved = savedTemplate()
		saved.loginGift = { lastDay = 20000, streak = -1 }
		expectCorrupted(saved, "loginGift streak is invalid")
		local other = savedTemplate()
		other.loginGift = "yes"
		expectCorrupted(other, "loginGift is not a table")
	end)
end)

describe("PlayerData quests", function()
	it("keeps saved quests", function()
		local saved = savedTemplate()
		saved.quests = {
			day = 20000,
			rerolled = true,
			list = {
				{ kind = "Train", target = 300, progress = 12.5, claimed = false },
				{ kind = "DeliverFromZone", target = 1, progress = 1, claimed = true, zone = "IceRings" },
			},
		}
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.quests.list[1].progress).toBe(12.5)
			expect(outcome.data.quests.list[2].zone).toBe("IceRings")
		end
	end)

	it("rejects broken quests", function()
		local cases: { { quests: any, detail: string } } = {
			{ quests = "none", detail = "quests is not a table" },
			{ quests = { day = -1, rerolled = false, list = {} }, detail = "quests day is invalid" },
			{ quests = { day = 1, rerolled = "no", list = {} }, detail = "quests rerolled is invalid" },
			{
				quests = {
					day = 1,
					rerolled = false,
					list = { { kind = "", target = 1, progress = 0, claimed = false } },
				},
				detail = "quests: quest kind is invalid",
			},
			{
				quests = {
					day = 1,
					rerolled = false,
					list = { { kind = "X", target = 0, progress = 0, claimed = false } },
				},
				detail = "quests: quest target is invalid",
			},
			{
				quests = {
					day = 1,
					rerolled = false,
					list = { { kind = "X", target = 1, progress = -1, claimed = false } },
				},
				detail = "quests: quest progress is invalid",
			},
			{
				quests = { day = 1, rerolled = false, list = { { kind = "X", target = 1, progress = 0 } } },
				detail = "quests: quest claimed is invalid",
			},
		}
		for _, case in cases do
			local saved = savedTemplate()
			saved.quests = case.quests
			expectCorrupted(saved, case.detail)
		end
	end)
end)

describe("PlayerData coins earned", function()
	it("starts at zero", function()
		expect(PlayerData.template(DEFAULTS).coinsEarned).toBe(BigNum.ZERO)
	end)

	it("is raised to the balance when it fell behind", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 500, exponent = 0 }
		saved.coinsEarned = { mantissa = 100, exponent = 0 }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.coinsEarned).toEqual(BigNum.fromNumber(500))
		end
	end)

	it("keeps a count above the balance", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 500, exponent = 0 }
		saved.coinsEarned = { mantissa = 9000, exponent = 0 }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.coinsEarned).toEqual(BigNum.fromNumber(9000))
		end
	end)
end)
