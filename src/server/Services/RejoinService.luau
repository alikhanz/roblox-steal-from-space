--!strict
-- The rejoin before Roblox's idle kick (decision 146, Domain/Rejoin, RejoinConfig,
-- docs/design/screens/rejoin.md). Roblox disconnects a player with no input for 20 minutes, and
-- training idle on the stand is part of the game; so at 17 minutes the client asks, and this
-- service teleports the player to a server again, which starts Roblox's timer over.
--
-- The client only asks. The server agrees when its own ActivityService sees the player away too
-- and no rejoin started in the last 15 minutes (the time is in the profile, so it holds across
-- servers); otherwise the request is ignored. Before teleporting it writes into the profile when
-- the rejoin started and whether the player stood on the stand, and waits until the store
-- confirms that save: the arriving server reads it from the profile, never from teleport data
-- (that passes through the client), and puts the player back on their stand.
--
-- First the very server the player is on, while others play there (friends and the friend bonus
-- stay); alone, the server closes as they leave, so any server of the place. A private server
-- comes back to itself. A failed teleport tries any server once; failed again, the player stays
-- and the cooldown is given back. Every step is counted (MetricsService: `Rejoin`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Rejoin = require(ReplicatedStorage.Shared.Domain.Rejoin)
local RejoinConfig = require(ReplicatedStorage.Shared.Config.RejoinConfig)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

local IS_STUDIO = RunService:IsStudio()
local METRIC = "Rejoin"

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	waitUntilSaved: (player: Player, isSaved: (saved: { [string]: any }) -> boolean, timeout: number?) -> boolean,
	-- DataService: a profile taken by the server the player goes to is not a lost session.
	setTeleporting: (player: Player, teleporting: boolean) -> (),
	-- The server's own view: the player has not moved or sent a command lately (ActivityService).
	isAway: (player: Player) -> boolean,
	isOnStand: (player: Player) -> boolean,
	placeOnStand: (player: Player) -> boolean,
	-- The developer's tools are open to this player (BenchService.isAllowed).
	isDevAllowed: (player: Player) -> boolean,
	-- Analytics (MetricsService.count).
	count: (player: Player, eventName: string, fields: { string }?) -> (),
}

export type RejoinService = {
	name: string,
	start: () -> (),
	-- The client says the player has had no input for a long while (RemoteRequestRejoin): start
	-- a rejoin if the server agrees, else nothing.
	request: (player: Player) -> (),
	-- The developer's test, shorter idle times (RejoinConfig.TEST_*), on or off; nothing for a
	-- player without the developer's tools.
	setTest: (player: Player, on: boolean) -> (),
}

-- A rejoin under way on this server.
type Flight = {
	target: Rejoin.Target,
	-- The record before this rejoin: back in the profile if it fails, so the cooldown is not
	-- spent on nothing.
	previous: Rejoin.Record,
	-- Counts the teleports tried, so a stale timeout does not end a later one.
	attempt: number,
	-- The options of the teleport under way: Roblox's failure names them, so a late failure of
	-- the first try does not end the second.
	options: TeleportOptions?,
}

local RejoinService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function log(message: string)
	if IS_STUDIO then
		print(`[RejoinService] {message}`)
	end
end

function RejoinService.new(dependencies: Dependencies): RejoinService
	-- When this server last tried a rejoin for each player (by UserId).
	local lastTriedAt: { [number]: number } = {}
	local flights: { [Player]: Flight } = {}
	local testing: { [Player]: boolean } = {}

	local function setTest(player: Player, on: boolean)
		if not dependencies.isDevAllowed(player) then
			return
		end
		testing[player] = if on then true else nil
		player:SetAttribute(RejoinConfig.TEST_ATTRIBUTE, if on then true else nil)
		log(`{player.Name}: test {if on then "on" else "off"}`)
	end

	local function optionsFor(player: Player, target: Rejoin.Target): TeleportOptions
		local options = Instance.new("TeleportOptions")
		if target == "SameServer" then
			options.ServerInstanceId = game.JobId
		elseif target == "PrivateServer" then
			options.VipServerId = game.PrivateServerId
		end
		if testing[player] then
			local data: { [string]: boolean } = { [RejoinConfig.TEST_DATA_KEY] = true }
			-- The engine's type names every JSON-like value; a flat table of booleans is one.
			options:SetTeleportData(data :: any)
		end
		return options
	end

	local teleport: (player: Player, target: Rejoin.Target) -> ()

	-- The rejoin's step failed: try the fallback target (`canRetry`), or give the rejoin up.
	local function failed(player: Player, reason: string, canRetry: boolean)
		local flight = flights[player]
		if not flight then
			return
		end
		warn(`[RejoinService] Rejoin failed for {player.Name} ({flight.target}): {reason}`)
		local fallback = if canRetry then Rejoin.fallback(flight.target) else nil
		if fallback and player.Parent == Players then
			teleport(player, fallback)
			return
		end
		flights[player] = nil
		dependencies.update(player, function(data)
			data.rejoin = table.clone(flight.previous)
		end)
		dependencies.setTeleporting(player, false)
		log(`{player.Name}: rejoin given up, stays here`)
	end

	function teleport(player: Player, target: Rejoin.Target)
		local flight = flights[player]
		if not flight then
			return
		end
		flight.target = target
		flight.attempt += 1
		local attempt = flight.attempt
		local options = optionsFor(player, target)
		flight.options = options
		local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if flights[player] ~= flight or flight.attempt ~= attempt then
			return
		end
		if not ok then
			dependencies.count(player, METRIC, { "Failed", `{target} - Error` })
			failed(player, tostring(problem), true)
			return
		end
		dependencies.count(player, METRIC, { "Started", target })
		log(`{player.Name}: teleporting ({target})`)
		task.delay(RejoinConfig.TELEPORT_TIMEOUT_SECONDS, function()
			if flights[player] == flight and flight.attempt == attempt then
				-- It may still be under way: another teleport now would only collide with it.
				dependencies.count(player, METRIC, { "Failed", `{target} - Timeout` })
				failed(player, "the teleport timed out", false)
			end
		end)
	end

	local function request(player: Player)
		local data = dependencies.getData(player)
		if not data or flights[player] then
			return
		end
		-- Whole seconds: the saved copy is compared with it after a round trip through the store.
		local at = math.floor(now())
		local cooldown = if testing[player] then RejoinConfig.TEST_COOLDOWN_SECONDS else RejoinConfig.COOLDOWN_SECONDS
		local refusal = Rejoin.refusal({
			isAway = dependencies.isAway(player),
			now = at,
			record = data.rejoin,
			lastTriedAt = lastTriedAt[player.UserId],
			cooldownSeconds = cooldown,
			retryGapSeconds = RejoinConfig.RETRY_GAP_SECONDS,
		})
		if refusal == "Busy" then
			-- A client asking again each Idled step, or a spammer: not worth counting.
			return
		elseif refusal then
			dependencies.count(player, METRIC, { "Refused", refusal })
			log(`{player.Name}: refused ({refusal})`)
			return
		end

		lastTriedAt[player.UserId] = at
		local flight: Flight = { target = "AnyServer", previous = table.clone(data.rejoin), attempt = 0 }
		flights[player] = flight
		local onStand = dependencies.isOnStand(player)
		dependencies.update(player, function(profile)
			profile.rejoin = Rejoin.started(at, onStand)
		end)
		dependencies.count(player, METRIC, { "Agreed", if onStand then "Stand" else "Free" })
		log(`{player.Name}: agreed{if onStand then ", on the stand" else ""}; saving`)
		dependencies.setTeleporting(player, true)

		local saved = dependencies.waitUntilSaved(player, function(stored)
			local record = stored.rejoin
			return type(record) == "table" and record.at == at
		end, RejoinConfig.SAVE_TIMEOUT_SECONDS)
		if flights[player] ~= flight or player.Parent ~= Players then
			return
		end
		if not saved then
			dependencies.count(player, METRIC, { "Failed", "Save" })
			-- Without a confirmed save the player stays.
			failed(player, "the profile save was not confirmed", false)
			return
		end
		teleport(
			player,
			Rejoin.firstTarget({
				isPrivate = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0,
				hasInstance = game.JobId ~= "",
				othersHere = #Players:GetPlayers() - 1,
			})
		)
	end

	-- A player arriving from a rejoin: back on their stand if they stood on it.
	local function arrived(player: Player)
		local data = dependencies.getData(player)
		if not data then
			return
		end
		if dependencies.isDevAllowed(player) then
			local joinData = player:GetJoinData()
			local teleportData = joinData.TeleportData
			if type(teleportData) == "table" and (teleportData :: any)[RejoinConfig.TEST_DATA_KEY] == true then
				setTest(player, true)
			end
		end
		if not data.rejoin.arriving then
			return
		end
		local arrival = Rejoin.arrival(data.rejoin, now(), RejoinConfig.RESTORE_SECONDS)
		dependencies.update(player, function(profile)
			profile.rejoin = Rejoin.landed(profile.rejoin)
		end)
		if not arrival then
			return
		end
		if arrival == "Free" then
			dependencies.count(player, METRIC, { "Arrived", "Free" })
			log(`{player.Name}: arrived`)
			return
		end
		local giveUpAt = os.clock() + RejoinConfig.RESTORE_WAIT_SECONDS
		while player.Parent == Players and os.clock() < giveUpAt do
			if dependencies.placeOnStand(player) then
				dependencies.count(player, METRIC, { "Arrived", "Stand" })
				log(`{player.Name}: arrived, back on the stand`)
				return
			end
			task.wait(RejoinConfig.RESTORE_POLL_SECONDS)
		end
		if player.Parent == Players then
			dependencies.count(player, METRIC, { "Arrived", "StandMissed" })
			warn(`[RejoinService] {player.Name} arrived from a rejoin, but their stand was not found in time`)
		end
	end

	local function start()
		dependencies.activated.connect(function(player)
			task.spawn(arrived, player)
		end)
		TeleportService.TeleportInitFailed:Connect(function(player, result, message, _placeId, options)
			local flight = flights[player]
			if not flight or (options and flight.options and options ~= flight.options) then
				return
			end
			dependencies.count(player, METRIC, { "Failed", `{flight.target} - {result.Name}` })
			failed(player, `{result.Name}: {message}`, true)
		end)
		PlayerEvents.observe(function() end, function(player)
			flights[player] = nil
			testing[player] = nil
			lastTriedAt[player.UserId] = nil
		end)
	end

	return {
		name = "RejoinService",
		start = start,
		request = request,
		setTest = setTest,
	}
end

return table.freeze(RejoinService)
