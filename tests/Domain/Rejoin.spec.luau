--!strict

local ActivityConfig = require("../../src/shared/Config/ActivityConfig")
local Rejoin = require("../../src/shared/Domain/Rejoin")
local RejoinConfig = require("../../src/shared/Config/RejoinConfig")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local THRESHOLDS: Rejoin.Thresholds = { warnAt = 990, requestAt = 1020 }
local COOLDOWN = 900
local GAP = 60

local function ask(overrides: { [string]: any }?): Rejoin.Ask
	local value: { [string]: any } = {
		isAway = true,
		now = 10000,
		record = Rejoin.empty(),
		lastTriedAt = nil,
		cooldownSeconds = COOLDOWN,
		retryGapSeconds = GAP,
	}
	for key, field in overrides or {} do
		value[key] = field
	end
	return value :: any
end

describe("Rejoin.clientStep", function()
	it("does nothing, warns, then asks as the idle time grows", function()
		expect(Rejoin.clientStep(120, THRESHOLDS)).toBe("None")
		expect(Rejoin.clientStep(989, THRESHOLDS)).toBe("None")
		expect(Rejoin.clientStep(990, THRESHOLDS)).toBe("Warn")
		expect(Rejoin.clientStep(1019, THRESHOLDS)).toBe("Warn")
		expect(Rejoin.clientStep(1020, THRESHOLDS)).toBe("Request")
		expect(Rejoin.clientStep(1110, THRESHOLDS)).toBe("Request")
	end)
end)

describe("Rejoin.refusal", function()
	it("agrees for an away player who never rejoined", function()
		expect(Rejoin.refusal(ask())).toBe(nil)
	end)

	it("ignores a player the server sees playing, whatever the client says", function()
		expect(Rejoin.refusal(ask({ isAway = false }))).toBe("Active")
	end)

	it("allows one rejoin per cooldown, kept in the record", function()
		local record = Rejoin.started(10000 - COOLDOWN + 1, true)
		expect(Rejoin.refusal(ask({ record = record }))).toBe("Cooldown")
		local older = Rejoin.started(10000 - COOLDOWN, true)
		expect(Rejoin.refusal(ask({ record = older }))).toBe(nil)
	end)

	it("counts a time ahead of now (another server's clock) as within the cooldown", function()
		expect(Rejoin.refusal(ask({ record = Rejoin.started(10005, false) }))).toBe("Cooldown")
	end)

	it("drops requests right after a try on this server", function()
		expect(Rejoin.refusal(ask({ lastTriedAt = 10000 - GAP + 1 }))).toBe("Busy")
		expect(Rejoin.refusal(ask({ lastTriedAt = 10000 - GAP }))).toBe(nil)
	end)

	it("says Active before anything else", function()
		local refusal =
			Rejoin.refusal(ask({ isAway = false, lastTriedAt = 9999, record = Rejoin.started(9999, false) }))
		expect(refusal).toBe("Active")
	end)
end)

describe("Rejoin targets", function()
	it("comes back to the same server while others play there", function()
		local place: Rejoin.Place = { isPrivate = false, hasInstance = true, othersHere = 2 }
		expect(Rejoin.firstTarget(place)).toBe("SameServer")
	end)

	it("goes to any server when alone (the server closes) or with no instance id (Studio)", function()
		expect(Rejoin.firstTarget({ isPrivate = false, hasInstance = true, othersHere = 0 })).toBe("AnyServer")
		expect(Rejoin.firstTarget({ isPrivate = false, hasInstance = false, othersHere = 3 })).toBe("AnyServer")
	end)

	it("stays in a private server", function()
		expect(Rejoin.firstTarget({ isPrivate = true, hasInstance = true, othersHere = 0 })).toBe("PrivateServer")
	end)

	it("falls back to any server once, then gives up", function()
		expect(Rejoin.fallback("SameServer")).toBe("AnyServer")
		expect(Rejoin.fallback("PrivateServer")).toBe("AnyServer")
		expect(Rejoin.fallback("AnyServer")).toBe(nil)
	end)
end)

describe("Rejoin arrival", function()
	it("puts a player who stood on the stand back on it", function()
		local record = Rejoin.started(5000, true)
		expect(Rejoin.arrival(record, 5010, 300)).toBe("Stand")
		expect(Rejoin.arrival(Rejoin.started(5000, false), 5010, 300)).toBe("Free")
	end)

	it("forgets a rejoin once landed or too old", function()
		local record = Rejoin.started(5000, true)
		local landed = Rejoin.landed(record)
		expect(Rejoin.arrival(landed, 5010, 300)).toBe(nil)
		expect(landed).toEqual({ at = 5000, arriving = false, onStand = false })
		expect(Rejoin.arrival(record, 5301, 300)).toBe(nil)
		expect(Rejoin.arrival(Rejoin.empty(), 5010, 300)).toBe(nil)
	end)

	it("keeps the cooldown after landing", function()
		local landed = Rejoin.landed(Rejoin.started(10000 - 10, true))
		expect(Rejoin.refusal(ask({ record = landed }))).toBe("Cooldown")
	end)
end)

describe("RejoinConfig", function()
	it("asks before Roblox's kick, with room for saving and two teleports", function()
		expect(RejoinConfig.WARN_IDLE_SECONDS < RejoinConfig.REQUEST_IDLE_SECONDS).toBe(true)
		local spare = RejoinConfig.ROBLOX_KICK_SECONDS - RejoinConfig.REQUEST_IDLE_SECONDS
		expect(spare >= RejoinConfig.SAVE_TIMEOUT_SECONDS + RejoinConfig.TELEPORT_TIMEOUT_SECONDS).toBe(true)
	end)

	it("asks only once the server, too, sees the player away", function()
		-- Idled comes every ~30 s: the request lands at least one step past the server's "away".
		expect(RejoinConfig.REQUEST_IDLE_SECONDS >= ActivityConfig.IDLE_SECONDS + 30).toBe(true)
		expect(RejoinConfig.TEST_REQUEST_IDLE_SECONDS >= ActivityConfig.IDLE_SECONDS + 30).toBe(true)
		expect(RejoinConfig.TEST_WARN_IDLE_SECONDS < RejoinConfig.TEST_REQUEST_IDLE_SECONDS).toBe(true)
	end)

	it("lets the next stretch of idling rejoin again", function()
		-- After a rejoin the client's idle time starts over: it asks again only past the cooldown.
		expect(RejoinConfig.REQUEST_IDLE_SECONDS >= RejoinConfig.COOLDOWN_SECONDS).toBe(true)
		expect(RejoinConfig.TEST_REQUEST_IDLE_SECONDS >= RejoinConfig.TEST_COOLDOWN_SECONDS).toBe(true)
	end)
end)
