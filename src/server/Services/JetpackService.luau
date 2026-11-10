--!strict
-- The jetpack level as the world sees it: a player attribute for every client's flame effects
-- and the attached jetpack model. The profile holds the level; the speed stat
-- that it multiplies is published by SpeedService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JetpackModel = require(script.Parent.Parent.Character.JetpackModel)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	jetpackUpgraded: Signal.Signal<Player>,
	-- Re-publishes the speed stat after the multiplier changed.
	publishSpeed: (player: Player) -> (),
}

export type JetpackService = {
	name: string,
	start: () -> (),
	getLevel: (player: Player) -> number,
	refresh: (player: Player) -> (),
}

local JetpackService = {}

function JetpackService.new(dependencies: Dependencies): JetpackService
	local function getLevel(player: Player): number
		local data = dependencies.getData(player)
		return if data then data.jetpackLevel else 0
	end

	local function publish(player: Player)
		player:SetAttribute(UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE, getLevel(player))
		local character = player.Character
		if character then
			JetpackModel.update(character, getLevel(player))
		end
	end

	-- After the level changed: the model, the attribute and the speed it multiplies.
	local function refresh(player: Player)
		publish(player)
		dependencies.publishSpeed(player)
	end

	local function start()
		dependencies.activated.connect(publish)
		dependencies.jetpackUpgraded.connect(refresh)
	end

	return {
		name = "JetpackService",
		start = start,
		getLevel = getLevel,
		refresh = refresh,
	}
end

return table.freeze(JetpackService)
