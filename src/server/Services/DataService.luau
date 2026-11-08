--!strict
-- Loads, guards and saves player profiles. The only way to read or change saved player data.
-- A player whose profile cannot be loaded safely is sent back with a message instead of
-- playing on default data that could overwrite their real progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local ProfileStoreAdapter = require(script.Parent.Parent.Data.ProfileStoreAdapter)
local SessionManager = require(script.Parent.Parent.Data.SessionManager)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)

local STORE_NAME = "PlayerData"
local LOAD_TIMEOUT_SECONDS = 30
-- What a new profile starts with; also fills fields that older profiles lack.
local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = SpeedConfig.STARTING_SPEED,
	startingPods = BayConfig.STARTING_PODS,
	startingIncubatorSlots = BayConfig.STARTING_INCUBATOR_SLOTS,
}
-- Every session transition is printed in Studio to make playtests easy to follow.
local LOG_TRANSITIONS = RunService:IsStudio()

local KICK_MESSAGES: { [SessionManager.EndReason]: Text.Key } = {
	LoadFailed = "data.loadFailed.message",
	NewerVersion = "data.newerVersion.message",
	Corrupted = "data.corrupted.message",
	SessionLost = "data.sessionLost.message",
}

export type DataService = {
	name: string,
	init: () -> (),
	start: () -> (),
	-- Fires once a player's profile is active and safe to read and change.
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	-- Applies a change to an active profile. See SessionManager.update for the mutator rules.
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Yields until a save the store confirmed passes `isSaved` (true) or the session ends (false).
	waitUntilSaved: (player: Player, isSaved: (saved: { [string]: any }) -> boolean) -> boolean,
}

local DataService = {}

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

function DataService.new(): DataService
	local activated = Signal.new() :: Signal.Signal<Player>
	local manager: SessionManager.SessionManager? = nil

	local function sendBack(player: Player, reason: SessionManager.EndReason)
		local key = KICK_MESSAGES[reason]
		if not key then
			return
		end
		-- Deferred so the kick never re-enters the session manager mid-transition.
		task.defer(function()
			if isInGame(player) then
				player:Kick(Text.get(Text.localeOf(player), key))
			end
		end)
	end

	local function onStateChanged(userId: number, state: SessionManager.SessionState, reason: SessionManager.EndReason?)
		if LOG_TRANSITIONS then
			print(`[DataService] User {userId}: {state}{if reason then ` ({reason})` else ""}`)
		end
		local player = Players:GetPlayerByUserId(userId)
		if state == "Active" then
			if player then
				activated.fire(player)
			end
		elseif state == "Failed" or (state == "Closed" and reason == "SessionLost") then
			warn(`[DataService] Session for user {userId} ended: {state} ({reason})`)
			if player and reason then
				sendBack(player, reason)
			end
		end
	end

	local function getManager(): SessionManager.SessionManager
		return assert(manager, "DataService used before init")
	end

	local function init()
		manager = SessionManager.new({
			port = ProfileStoreAdapter.new({
				storeName = STORE_NAME,
				template = PlayerData.template(DEFAULTS) :: any,
				keyFor = keyFor,
			}),
			loadData = function(saved)
				return PlayerData.load(saved, DEFAULTS)
			end,
			clock = os.clock,
			sleep = function(seconds)
				task.wait(seconds)
			end,
			loadTimeout = LOAD_TIMEOUT_SECONDS,
			onStateChanged = onStateChanged,
		})
	end

	local function start()
		local sessions = getManager()
		PlayerEvents.observe(function(player)
			sessions.load(player.UserId, function()
				return isInGame(player)
			end)
		end, function(player)
			sessions.release(player.UserId)
		end)
	end

	local function getData(player: Player): PlayerData.PlayerData?
		return getManager().getData(player.UserId) :: any
	end

	local function update(player: Player, mutator: (data: PlayerData.PlayerData) -> ()): boolean
		return getManager().update(player.UserId, mutator :: any)
	end

	local function waitUntilSaved(player: Player, isSaved: (saved: { [string]: any }) -> boolean): boolean
		return getManager().waitUntilSaved(player.UserId, isSaved)
	end

	return {
		name = "DataService",
		init = init,
		start = start,
		activated = activated,
		getData = getData,
		update = update,
		waitUntilSaved = waitUntilSaved,
	}
end

return table.freeze(DataService)
