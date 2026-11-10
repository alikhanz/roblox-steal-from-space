--!strict
-- Flight under a dome (decision 096): notes in the profile the first time a player flies under a
-- dome, and keeps that on the player (`FlightConfig.DOME_FLIGHT_LEARNED_ATTRIBUTE`) for the
-- client, which shows the double-jump hint on spawning until then. The flight itself is the
-- simulation's (SpaceSimulation, Domain/JetpackSwitch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

-- How often characters are looked at, seconds.
local CHECK_SECONDS = 1

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
}

export type DomeFlightService = {
	name: string,
	start: () -> (),
}

local DomeFlightService = {}

local function isFlyingUnderDome(player: Player): boolean
	local character = player.Character
	return character ~= nil
		and character:GetAttribute(FlightConfig.JETPACK_ON_ATTRIBUTE) == true
		and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == false
end

function DomeFlightService.new(dependencies: Dependencies): DomeFlightService
	local function publish(player: Player)
		local data = dependencies.getData(player)
		if data then
			player:SetAttribute(FlightConfig.DOME_FLIGHT_LEARNED_ATTRIBUTE, data.domeFlightLearned)
		end
	end

	local function start()
		dependencies.activated.connect(publish)
		dependencies.scheduler.every(CHECK_SECONDS, function()
			for _, player in Players:GetPlayers() do
				if player:GetAttribute(FlightConfig.DOME_FLIGHT_LEARNED_ATTRIBUTE) ~= false then
					-- Learned already, or no profile yet.
					continue
				end
				if isFlyingUnderDome(player) then
					local written = dependencies.update(player, function(data)
						data.domeFlightLearned = true
					end)
					if written then
						publish(player)
					end
				end
			end
		end)
	end

	return {
		name = "DomeFlightService",
		start = start,
	}
end

return table.freeze(DomeFlightService)
