--!strict
-- Covers the persistence rows of the failure matrix in docs/CONVENTIONS.md.

local SessionManager = require("../../src/server/Data/SessionManager")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local USER_ID = 42
local LOAD_TIMEOUT = 30

type FakeHandle = SessionManager.ProfileHandle & {
	endCount: number,
	-- Simulates another server taking the session over.
	loseSession: () -> (),
	setActive: (active: boolean) -> (),
}

local function fakeHandle(data: { [string]: any }): FakeHandle
	local active = true
	local listeners: { () -> () } = {}
	local function notifyEnded()
		for _, listener in listeners do
			listener()
		end
	end

	local handle: FakeHandle
	local function isActive(): boolean
		return active
	end
	local function endSession()
		handle.endCount += 1
		if active then
			active = false
			notifyEnded()
		end
	end
	local function onSessionEnd(listener: () -> ())
		table.insert(listeners, listener)
	end
	local function loseSession()
		active = false
		notifyEnded()
	end
	local function setActive(value: boolean)
		active = value
	end

	handle = {
		data = data,
		endCount = 0,
		isActive = isActive,
		endSession = endSession,
		onSessionEnd = onSessionEnd,
		loseSession = loseSession,
		setActive = setActive,
	}
	return handle
end

type Event = { state: SessionManager.SessionState, reason: SessionManager.EndReason? }

type Harness = {
	manager: SessionManager.SessionManager,
	events: { Event },
	-- What the fake storage does when a session starts. Defaults to returning `handle`.
	startSession: (userId: number, shouldCancel: () -> boolean) -> SessionManager.ProfileHandle?,
	handle: FakeHandle,
	present: boolean,
	now: number,
	loadOutcome: SessionManager.LoadOutcome?,
}

local function harness(): Harness
	local h: Harness
	local function defaultStartSession(_userId: number, _shouldCancel: () -> boolean): SessionManager.ProfileHandle?
		return h.handle
	end
	h = {
		events = {},
		handle = fakeHandle({ schemaVersion = 1, coins = 0 }),
		present = true,
		now = 0,
		loadOutcome = nil,
		startSession = defaultStartSession,
		-- Assigned right below; the manager's callbacks need `h` to exist first.
		manager = nil :: any,
	} :: Harness
	h.manager = SessionManager.new({
		port = {
			startSession = function(userId, shouldCancel)
				return h.startSession(userId, shouldCancel)
			end,
		},
		loadData = function(saved)
			return h.loadOutcome or { ok = true, data = { schemaVersion = saved.schemaVersion, coins = 100 } }
		end,
		clock = function()
			return h.now
		end,
		loadTimeout = LOAD_TIMEOUT,
		onStateChanged = function(_, state, reason)
			table.insert(h.events, { state = state, reason = reason })
		end,
	})
	return h
end

local function load(h: Harness)
	h.manager.load(USER_ID, function()
		return h.present
	end)
end

local function lastEvent(h: Harness): Event
	return h.events[#h.events]
end

describe("SessionManager loading", function()
	it("activates a loaded profile with the prepared data", function()
		local h = harness()
		load(h)

		expect(h.events).toEqual({ { state = "Loading" }, { state = "Active" } })
		expect(h.manager.getState(USER_ID)).toBe("Active")
		expect(h.manager.getData(USER_ID)).toEqual({ schemaVersion = 1, coins = 100 })
	end)

	it("keeps the storage's own data table", function()
		local h = harness()
		local storageTable = h.handle.data
		load(h)
		expect(h.manager.getData(USER_ID)).toBe(storageTable)
	end)

	it("fails without inventing data when storage does not answer", function()
		local h = harness()
		h.startSession = function()
			return nil
		end
		load(h)

		expect(lastEvent(h)).toEqual({ state = "Failed", reason = "LoadFailed" })
		expect(h.manager.getState(USER_ID)).toBeNil()
		expect(h.manager.getData(USER_ID)).toBeNil()
	end)

	it("does not start a session when the player leaves during loading", function()
		local h = harness()
		h.startSession = function()
			h.present = false
			h.manager.release(USER_ID)
			return h.handle
		end
		load(h)

		expect(lastEvent(h)).toEqual({ state = "Closed", reason = "PlayerLeft" })
		expect(h.handle.endCount).toBe(1)
		expect(h.manager.getState(USER_ID)).toBeNil()
	end)

	it("closes the profile when the player is gone before release is called", function()
		local h = harness()
		h.startSession = function()
			h.present = false
			return h.handle
		end
		load(h)

		expect(lastEvent(h)).toEqual({ state = "Closed", reason = "PlayerLeft" })
		expect(h.handle.endCount).toBe(1)
	end)

	it("refuses newer data and leaves it untouched", function()
		local h = harness()
		h.handle.data = { schemaVersion = 99, futureField = true }
		h.loadOutcome = { ok = false, reason = "NewerVersion", detail = "newer" } :: SessionManager.LoadOutcome
		load(h)

		expect(lastEvent(h)).toEqual({ state = "Failed", reason = "NewerVersion" })
		expect(h.handle.data).toEqual({ schemaVersion = 99, futureField = true })
		expect(h.handle.endCount).toBe(1)
	end)

	it("refuses corrupted data and leaves it untouched", function()
		local h = harness()
		h.handle.data = { schemaVersion = 1, coins = "broken" }
		h.loadOutcome = { ok = false, reason = "Corrupted", detail = "bad coins" } :: SessionManager.LoadOutcome
		load(h)

		expect(lastEvent(h)).toEqual({ state = "Failed", reason = "Corrupted" })
		expect(h.handle.data).toEqual({ schemaVersion = 1, coins = "broken" })
	end)

	it("fails when the session was lost while preparing data", function()
		local h = harness()
		h.handle.setActive(false)
		load(h)
		expect(lastEvent(h)).toEqual({ state = "Failed", reason = "LoadFailed" })
	end)

	it("cancels loading after the timeout or when the player leaves", function()
		local h = harness()
		local results: { boolean } = {}
		h.startSession = function(_, shouldCancel)
			table.insert(results, shouldCancel())
			h.now = LOAD_TIMEOUT + 1
			table.insert(results, shouldCancel())
			return nil
		end
		load(h)
		expect(results).toEqual({ false, true })

		local left = harness()
		left.startSession = function(_, shouldCancel)
			left.present = false
			expect(shouldCancel()).toBe(true)
			return nil
		end
		load(left)
	end)

	it("refuses a second session for the same user", function()
		local h = harness()
		load(h)
		expect(function()
			load(h)
		end).toThrow("already exists")
	end)
end)

describe("SessionManager while active", function()
	it("applies updates", function()
		local h = harness()
		load(h)
		local applied = h.manager.update(USER_ID, function(data)
			data.coins += 5
		end)

		expect(applied).toBe(true)
		expect((h.manager.getData(USER_ID) :: any).coins).toBe(105)
	end)

	it("rejects updates before the profile is active", function()
		local h = harness()
		local applied: boolean? = nil
		h.startSession = function()
			applied = h.manager.update(USER_ID, function(data)
				data.coins = 999
			end)
			return h.handle
		end
		load(h)
		expect(applied).toBe(false)
	end)

	it("rejects a mutator that yields", function()
		local h = harness()
		load(h)
		expect(function()
			h.manager.update(USER_ID, function()
				coroutine.yield()
			end)
		end).toThrow("must not yield")
	end)

	it("reports a mutator error with the user id", function()
		local h = harness()
		load(h)
		expect(function()
			h.manager.update(USER_ID, function()
				error("no such alien")
			end)
		end).toThrow(`user {USER_ID} failed`)
	end)

	it("stops accepting changes when another server takes the session", function()
		local h = harness()
		load(h)
		h.handle.loseSession()

		expect(lastEvent(h)).toEqual({ state = "Closed", reason = "SessionLost" })
		expect(h.manager.update(USER_ID, function() end)).toBe(false)
	end)
end)

describe("SessionManager release", function()
	it("ends the profile session once when the player leaves", function()
		local h = harness()
		load(h)
		h.manager.release(USER_ID)

		expect(h.events).toEqual({
			{ state = "Loading" },
			{ state = "Active" },
			{ state = "Closing" },
			{ state = "Closed", reason = "PlayerLeft" },
		})
		expect(h.handle.endCount).toBe(1)
		expect(h.manager.update(USER_ID, function() end)).toBe(false)
	end)

	it("ignores unknown users", function()
		local h = harness()
		h.manager.release(USER_ID)
		expect(#h.events).toBe(0)
	end)

	it("allows a new session after the previous one closed", function()
		local h = harness()
		load(h)
		h.manager.release(USER_ID)
		h.handle = fakeHandle({ schemaVersion = 1, coins = 0 })
		load(h)
		expect(h.manager.getState(USER_ID)).toBe("Active")
	end)
end)
