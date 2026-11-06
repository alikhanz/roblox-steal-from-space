--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Tables = require("../../src/shared/Runtime/Tables")
local Test = require("../../lune/lib/Test")
local Tutorial = require("../../src/shared/Domain/Tutorial")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = BigNum.fromNumber(10),
	startingPods = 3,
	startingIncubatorSlots = 2,
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

describe("PlayerData migration v9 -> v10", function()
	it("names the claimed index sets by id", function()
		local saved = savedTemplate()
		saved.schemaVersion = 9
		saved.index = { found = { ["DebrisBelt1.Common"] = true }, sets = { 1, 4 } }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.index.sets).toEqual({ "1", "4" })
			expect(outcome.data.index.found).toEqual({ ["DebrisBelt1.Common"] = true })
		end
	end)

	it("keeps an egg's variant and rejects a broken one", function()
		local saved = savedTemplate()
		saved.incubator =
			{ { uid = 5, rarity = "Rare", size = "Large", grade = 2, hatchAt = 1000, variant = "Meteor" } }
		saved.nextUid = 6
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.incubator[1].variant).toBe("Meteor")
		end
		local broken = savedTemplate()
		broken.incubator = { { uid = 5, rarity = "Rare", size = "Large", grade = 2, hatchAt = 1000, variant = "" } }
		broken.nextUid = 6
		expectCorrupted(broken, "egg variant is invalid")
	end)
end)

describe("PlayerData migration v10 -> v11", function()
	it("loads eggs from before with no extra luck", function()
		local saved = savedTemplate()
		saved.schemaVersion = 10
		saved.incubator = { { uid = 5, rarity = "Rare", size = "Large", grade = 2, hatchAt = 1000 } }
		saved.nextUid = 6
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.incubator[1].luck).toBeNil()
		end
	end)

	it("keeps an egg's extra luck and rejects a negative one", function()
		local saved = savedTemplate()
		saved.incubator = { { uid = 5, rarity = "Rare", size = "Large", grade = 2, hatchAt = 1000, luck = 0.35 } }
		saved.nextUid = 6
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.incubator[1].luck).toBe(0.35)
		end
		local broken = savedTemplate()
		broken.incubator = { { uid = 5, rarity = "Rare", size = "Large", grade = 2, hatchAt = 1000, luck = -1 } }
		broken.nextUid = 6
		expectCorrupted(broken, "egg luck is invalid")
	end)
end)

describe("PlayerData migration v11 -> v12", function()
	local function migrated(level: number): number?
		local saved = savedTemplate()
		saved.schemaVersion = 11
		saved.jetpackLevel = level
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		return if outcome.ok then outcome.data.jetpackLevel else nil
	end

	it("keeps each jetpack's multiplier on the two-mark levels", function()
		expect(migrated(0)).toBe(0)
		-- x2 was level 1 and stays level 1; x4 was 2, now 3; x8 was 3, now 5.
		expect(migrated(1)).toBe(1)
		expect(migrated(2)).toBe(3)
		expect(migrated(3)).toBe(5)
		-- x128 was 7, now 13; x2048 was 11, now the top, 21.
		expect(migrated(7)).toBe(13)
		expect(migrated(11)).toBe(21)
	end)

	it("brings a jetpack past x2048 down to the top", function()
		expect(migrated(15)).toBe(21)
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

describe("PlayerData migration v12 -> v13", function()
	it("gives an incubator from before two slots and an empty queue", function()
		local saved = savedTemplate()
		saved.schemaVersion = 12
		saved.incubatorSlots = nil
		saved.waiting = nil
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.incubatorSlots).toBe(2)
			expect(outcome.data.waiting).toEqual({})
		end
	end)

	it("keeps a queue and rejects a broken one", function()
		local saved = savedTemplate()
		saved.waiting = { { uid = 7, rarity = "Rare", size = "Large", grade = 2, hatchSeconds = 300 } }
		saved.nextUid = 8
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.waiting[1].hatchSeconds).toBe(300)
		end
		local broken = savedTemplate()
		broken.waiting = { { uid = 7, rarity = "Rare", size = "Large", grade = 2, hatchSeconds = -1 } }
		broken.nextUid = 8
		expectCorrupted(broken, "waiting egg hatch seconds are invalid")
		local noSlots = savedTemplate()
		noSlots.incubatorSlots = 0
		expectCorrupted(noSlots, "incubatorSlots is invalid")
	end)
end)

describe("PlayerData migration v13 -> v14", function()
	it("gives a profile from before no receipts, no passes and nothing to collect again", function()
		local saved = savedTemplate()
		saved.schemaVersion = 13
		saved.purchaseIds = nil
		saved.passes = nil
		saved.pendingDouble = nil
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.purchaseIds).toEqual({})
			expect(outcome.data.passes).toEqual({})
			expect(BigNum.isZero(outcome.data.pendingDouble.coins)).toBe(true)
			expect(BigNum.isZero(outcome.data.pendingDouble.trained)).toBe(true)
		end
	end)

	it("keeps saved purchases and rejects broken ones", function()
		local saved = savedTemplate()
		saved.purchaseIds = { "receipt-1", "receipt-2" }
		saved.passes = { "NightShift" }
		saved.pendingDouble =
			{ coins = { mantissa = 1500000, exponent = 0 }, trained = { mantissa = 2000, exponent = 0 } }
		local outcome = load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.purchaseIds).toEqual({ "receipt-1", "receipt-2" })
			expect(outcome.data.passes).toEqual({ "NightShift" })
			expect(BigNum.toNumber(outcome.data.pendingDouble.coins)).toBe(1.5e6)
		end
		local badReceipts = savedTemplate()
		badReceipts.purchaseIds = { "receipt-1", 7 }
		expectCorrupted(badReceipts, "purchaseIds is invalid")
		local badPending = savedTemplate()
		badPending.pendingDouble = { coins = "lots", trained = { mantissa = 0, exponent = 0 } }
		expectCorrupted(badPending, "pendingDouble coins is invalid")
	end)
end)

describe("PlayerData migration v14 -> v15", function()
	it("starts the tutorial for a new player and skips it for one past guardian 2", function()
		local fresh = savedTemplate()
		fresh.schemaVersion = 14
		fresh.tutorialStep = nil
		local outcome = load(fresh)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.tutorialStep).toBe(Tutorial.NOT_STARTED)
		end
		local veteran = savedTemplate()
		veteran.schemaVersion = 14
		veteran.tutorialStep = nil
		veteran.bestPost = 3
		local done = load(veteran)
		expect(done.ok).toBe(true)
		if done.ok then
			expect(done.data.tutorialStep).toBe(Tutorial.DONE)
		end
	end)

	it("rejects a broken tutorial step", function()
		local broken = savedTemplate()
		broken.tutorialStep = Tutorial.DONE + 1
		expectCorrupted(broken, "tutorialStep is invalid")
	end)
end)
