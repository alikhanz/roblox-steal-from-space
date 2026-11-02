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
		}
	end

	return { startSession = startSession }
end

return table.freeze(ProfileStoreAdapter)
