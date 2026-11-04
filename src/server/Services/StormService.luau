--!strict
-- The solar storm's gameplay, on the storm event's clock (EventService): as it starts, everyone
-- out in space is brought back to the platform (a respawn at the station, not a long move: that
-- tears the character's joints) and their egg goes back to its nest; flight stops at the
-- station border and the incubators speed up until it ends (StormConfig).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryService = require(script.Parent.CarryService)
local EventClock = require(ReplicatedStorage.Shared.Domain.EventClock)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StormConfig = require(ReplicatedStorage.Shared.Config.StormConfig)

export type Notice = "StormTeleport"

export type Dependencies = {
	eventChanged: Signal.Signal<EventConfig.EventId, EventClock.Phase>,
	returnEgg: (player: Player, reason: CarryService.LossReason) -> boolean,
	setHatchRate: (rate: number) -> (),
	notify: (player: Player, notice: Notice) -> (),
}

export type StormService = {
	name: string,
	start: () -> (),
}

local StormService = {}

local function isInSpace(player: Player): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
end

function StormService.new(dependencies: Dependencies): StormService
	local function bringHome(player: Player)
		dependencies.returnEgg(player, "Storm")
		player:LoadCharacterAsync()
		dependencies.notify(player, "StormTeleport")
	end

	local function begin()
		workspace:SetAttribute(FlightConfig.RANGE_LIMIT_ATTRIBUTE, StormConfig.RANGE_RADIUS)
		dependencies.setHatchRate(StormConfig.HATCH_RATE)
		for _, player in Players:GetPlayers() do
			if isInSpace(player) then
				-- Each on its own thread: a respawn yields.
				task.spawn(bringHome, player)
			end
		end
	end

	local function finish()
		workspace:SetAttribute(FlightConfig.RANGE_LIMIT_ATTRIBUTE, nil)
		dependencies.setHatchRate(1)
	end

	local function start()
		dependencies.eventChanged.connect(function(id, phase)
			if id ~= "Storm" then
				return
			end
			if phase == "Active" then
				begin()
			elseif phase == "Idle" then
				finish()
			end
		end)
	end

	return {
		name = "StormService",
		start = start,
	}
end

return table.freeze(StormService)
