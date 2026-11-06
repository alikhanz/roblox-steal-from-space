--!strict
-- Connects SessionManager to ProfileStore. The only module that talks to ProfileStore directly.

local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local SessionManager = require(script.Parent.SessionManager)

export type Options = {
	storeName: string,
	template: { [string]: any },
	keyFor: (userId: number) -> string,
}

-- How long `waitForSave` waits for a save before letting its caller check again.
local SAVE_WAIT_SECONDS = 30

local ProfileStoreAdapter = {}

function ProfileStoreAdapter.new(options: Options): SessionManager.ProfilePort
	-- ProfileStore types its template as JSONAcceptable; PlayerData.template() is plain JSON-safe data.
	local store = ProfileStore.New(options.storeName, options.template :: any)

	local function startSession(userId: number, shouldCancel: () -> boolean): SessionManager.ProfileHandle?
		-- `Cancel` is supported by ProfileStore but missing from its published params type.
		local params: any = { Cancel = shouldCancel }
		local profile = store:StartSessionAsync(options.keyFor(userId), params)
		if not profile then
			return nil
		end
		profile:AddUserId(userId)

		return {
			data = profile.Data :: any,
			isActive = function()
				return profile:IsActive()
			end,
			endSession = function()
				profile:EndSession()
			end,
			onSessionEnd = function(listener: () -> ())
				profile.OnSessionEnd:Connect(listener)
			end,
			lastSaved = function()
				return profile.LastSavedData :: any
			end,
			save = function()
				profile:Save()
			end,
			waitForSave = function()
				-- ProfileStore's signal has only Connect in its published type. A save that never
				-- comes (the store is down, the session ended) gives up after a while: the
				-- caller checks again and retries.
				local done = false
				local thread = coroutine.running()
				local connection: { Disconnect: (self: any) -> () }? = nil
				local function resume()
					if done then
						return
					end
					done = true
					if connection then
						connection:Disconnect()
					end
					task.spawn(thread)
				end
				connection = profile.OnAfterSave:Connect(resume)
				task.delay(SAVE_WAIT_SECONDS, resume)
				coroutine.yield()
			end,
		}
	end

	local function isShuttingDown(): boolean
		return ProfileStore.IsClosing
	end

	return {
		startSession = startSession,
		isShuttingDown = isShuttingDown,
	}
end

return table.freeze(ProfileStoreAdapter)
