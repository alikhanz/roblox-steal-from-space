--!strict
-- Owns the lifecycle of player profile sessions:
--
--   Loading ──> Active ──> Closing ──> Closed
--      │          └───────────────────> Closed (session lost to another server)
--      ├──> Closed (player left while loading)
--      └──> Failed (could not load, newer version, corrupted data)
--
-- Only an Active session accepts changes. Storage, the data schema and the clock are injected,
-- so this module is pure Luau and every failure path is covered by tests.

export type SessionState = "Loading" | "Active" | "Closing" | "Closed" | "Failed"
export type EndReason = "PlayerLeft" | "SessionLost" | "LoadFailed" | "NewerVersion" | "Corrupted"

export type ProfileHandle = {
	data: { [string]: any },
	isActive: () -> boolean,
	endSession: () -> (),
	onSessionEnd: (listener: () -> ()) -> (),
}

export type ProfilePort = {
	-- Yields until the profile is loaded; returns nil on failure or once `shouldCancel` returns true.
	startSession: (userId: number, shouldCancel: () -> boolean) -> ProfileHandle?,
}

export type LoadOutcome = { ok: true, data: any } | { ok: false, reason: "NewerVersion" | "Corrupted", detail: string }

export type Config = {
	port: ProfilePort,
	-- Turns saved data into runtime data without modifying `saved`.
	loadData: (saved: { [string]: any }) -> LoadOutcome,
	clock: () -> number,
	loadTimeout: number,
	onStateChanged: (userId: number, state: SessionState, reason: EndReason?) -> (),
}

export type SessionManager = {
	load: (userId: number, isPresent: () -> boolean) -> (),
	release: (userId: number) -> (),
	getState: (userId: number) -> SessionState?,
	getData: (userId: number) -> { [string]: any }?,
	update: (userId: number, mutator: (data: { [string]: any }) -> ()) -> boolean,
}

type Session = {
	state: SessionState,
	handle: ProfileHandle?,
}

local ALLOWED_TRANSITIONS: { [SessionState]: { [SessionState]: boolean } } = {
	Loading = { Active = true, Closed = true, Failed = true },
	Active = { Closing = true, Closed = true },
	Closing = { Closed = true },
	Closed = {},
	Failed = {},
}

local SessionManager = {}

function SessionManager.new(config: Config): SessionManager
	local sessions: { [number]: Session } = {}

	local function transition(userId: number, session: Session, state: SessionState, reason: EndReason?)
		assert(ALLOWED_TRANSITIONS[session.state][state], `Invalid session transition {session.state} -> {state}`)
		session.state = state
		if (state == "Closed" or state == "Failed") and sessions[userId] == session then
			sessions[userId] = nil
		end
		config.onStateChanged(userId, state, reason)
	end

	local function load(userId: number, isPresent: () -> boolean)
		assert(sessions[userId] == nil, `A session for user {userId} already exists`)
		local session: Session = { state = "Loading" }
		sessions[userId] = session
		config.onStateChanged(userId, "Loading", nil)

		local startedAt = config.clock()
		local function shouldCancel(): boolean
			return session.state ~= "Loading" or not isPresent() or config.clock() - startedAt > config.loadTimeout
		end

		local handle = config.port.startSession(userId, shouldCancel)

		if session.state ~= "Loading" then
			-- Released while loading: the late result must not start a session.
			if handle then
				handle.endSession()
			end
			return
		end
		if not isPresent() then
			if handle then
				handle.endSession()
			end
			transition(userId, session, "Closed", "PlayerLeft")
			return
		end
		if not handle then
			transition(userId, session, "Failed", "LoadFailed")
			return
		end

		local outcome = config.loadData(handle.data)
		if not outcome.ok then
			-- The stored data was not modified, so ending the session saves it back unchanged.
			handle.endSession()
			transition(userId, session, "Failed", outcome.reason)
			return
		end
		if not handle.isActive() then
			transition(userId, session, "Failed", "LoadFailed")
			return
		end

		-- Keep ProfileStore's table: it saves whatever Profile.Data references.
		table.clear(handle.data)
		for key, value in outcome.data do
			handle.data[key] = value
		end
		session.handle = handle
		handle.onSessionEnd(function()
			if session.state == "Active" then
				transition(userId, session, "Closed", "SessionLost")
			end
		end)
		transition(userId, session, "Active", nil)
	end

	local function release(userId: number)
		local session = sessions[userId]
		if not session then
			return
		end
		if session.state == "Loading" then
			transition(userId, session, "Closed", "PlayerLeft")
		elseif session.state == "Active" then
			transition(userId, session, "Closing", nil)
			local handle = session.handle :: ProfileHandle
			handle.endSession()
			transition(userId, session, "Closed", "PlayerLeft")
		end
	end

	local function activeHandle(userId: number): ProfileHandle?
		local session = sessions[userId]
		if not session or session.state ~= "Active" then
			return nil
		end
		local handle = session.handle :: ProfileHandle
		return if handle.isActive() then handle else nil
	end

	local function getState(userId: number): SessionState?
		local session = sessions[userId]
		return if session then session.state else nil
	end

	local function getData(userId: number): { [string]: any }?
		local handle = activeHandle(userId)
		return if handle then handle.data else nil
	end

	-- Applies a change to an active profile. The mutator must check everything before writing
	-- and must not yield: ProfileStore only guarantees saving until the code yields.
	local function update(userId: number, mutator: (data: { [string]: any }) -> ()): boolean
		local handle = activeHandle(userId)
		if not handle then
			return false
		end
		local thread = coroutine.create(mutator)
		local ok, err = coroutine.resume(thread, handle.data)
		if not ok then
			error(`Data update for user {userId} failed: {err}`, 0)
		end
		if coroutine.status(thread) ~= "dead" then
			error(`Data update for user {userId} yielded; mutators must not yield`, 0)
		end
		return true
	end

	return {
		load = load,
		release = release,
		getState = getState,
		getData = getData,
		update = update,
	}
end

return table.freeze(SessionManager)
