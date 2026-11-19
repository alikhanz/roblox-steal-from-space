--!strict
-- How many of the local player's Roblox friends play on this server (decision 128): the server
-- counts them and says so in a player attribute (FriendConfig.FRIENDS_ATTRIBUTE). The HUD shows
-- the bonus from it, FriendController the toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FriendConfig = require(ReplicatedStorage.Shared.Config.FriendConfig)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type FriendState = {
	name: string,
	start: () -> (),
	-- Friends here now (reactive); 0 until the server has counted.
	friends: () -> number,
	-- The count changed after the first one (that one is no news): now, before.
	changed: Signal.Signal<number, number>,
}

local FriendState = {}

function FriendState.new(): FriendState
	local friends = Vide.source(0)
	local changed = Signal.new() :: Signal.Signal<number, number>
	local counted = false

	local function start()
		local player = Players.LocalPlayer
		local function read()
			local value = player:GetAttribute(FriendConfig.FRIENDS_ATTRIBUTE)
			if type(value) ~= "number" then
				return
			end
			local before = Vide.untrack(friends)
			friends(value)
			local first = not counted
			counted = true
			if not first and value ~= before then
				changed.fire(value, before)
			end
		end
		player:GetAttributeChangedSignal(FriendConfig.FRIENDS_ATTRIBUTE):Connect(read)
		read()
	end

	return {
		name = "FriendState",
		start = start,
		friends = function()
			return friends()
		end,
		changed = changed,
	}
end

return table.freeze(FriendState)
