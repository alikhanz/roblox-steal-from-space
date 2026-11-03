--!strict
-- The jetpack level as the world sees it: a player attribute for every client's flame effects
-- and the colors of the attached jetpack model. The profile holds the level; the speed stat
-- that it multiplies is published by SpeedService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
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
	getLooks: (player: Player) -> JetpackLooks.Looks,
}

local JetpackService = {}

function JetpackService.new(dependencies: Dependencies): JetpackService
	local function getLevel(player: Player): number
		local data = dependencies.getData(player)
		return if data then data.jetpackLevel else 0
	end

	local function getLooks(player: Player): JetpackLooks.Looks
		return JetpackLooks.forLevel(getLevel(player))
	end

	local function publish(player: Player)
		player:SetAttribute(UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE, getLevel(player))
		local character = player.Character
		local model = character and character:FindFirstChild(JetpackConfig.MODEL_NAME)
		if model and model:IsA("Model") then
			JetpackModel.applyLooks(model, getLooks(player))
		end
	end

	local function start()
		dependencies.activated.connect(publish)
		dependencies.jetpackUpgraded.connect(function(player)
			publish(player)
			dependencies.publishSpeed(player)
		end)
	end

	return {
		name = "JetpackService",
		start = start,
		getLooks = getLooks,
	}
end

return table.freeze(JetpackService)
