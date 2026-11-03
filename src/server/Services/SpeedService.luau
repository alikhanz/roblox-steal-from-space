--!strict
-- Publishes each player's speed stat from their profile: the stat itself as player attributes
-- (for the HUD and for anyone looking at a player) and the flight speed derived from it as a
-- character attribute (for the simulation, which never touches BigNum). The stat is the trained
-- speed times the jetpack multiplier (Domain/Upgrades); until the profile is active the player
-- flies at the starting speed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
}

export type SpeedService = {
	name: string,
	start: () -> (),
	-- The stat the player sees.
	getSpeed: (player: Player) -> BigNum.BigNum,
	-- Re-reads the profile and publishes the stat. Call after the trained speed or a level changed.
	publish: (player: Player) -> (),
	-- Sets the trained speed so the stat shows `speed` with the current jetpack (playtests).
	-- False without an active profile.
	setSpeed: (player: Player, speed: BigNum.BigNum) -> boolean,
}

local SpeedService = {}

function SpeedService.new(dependencies: Dependencies): SpeedService
	local function getSpeed(player: Player): BigNum.BigNum
		local data = dependencies.getData(player)
		if not data then
			return SpeedConfig.STARTING_SPEED
		end
		return Upgrades.speed(data.trained, data.jetpackLevel, UpgradeConfig.TUNING)
	end

	local function publish(player: Player)
		local speed = getSpeed(player)
		player:SetAttribute(SpeedConfig.MANTISSA_ATTRIBUTE, speed.mantissa)
		player:SetAttribute(SpeedConfig.EXPONENT_ATTRIBUTE, speed.exponent)
		local character = player.Character
		if character then
			character:SetAttribute(SpeedConfig.FLIGHT_SPEED_ATTRIBUTE, Speed.flightSpeed(speed, SpeedConfig.FLIGHT))
		end
	end

	local function setSpeed(player: Player, speed: BigNum.BigNum): boolean
		local written = dependencies.update(player, function(data)
			data.trained = BigNum.div(speed, Upgrades.jetpackMultiplier(data.jetpackLevel, UpgradeConfig.TUNING))
		end)
		if written then
			publish(player)
		end
		return written
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			publish(player)
		end)
		publish(player)
	end

	local function start()
		PlayerEvents.observe(onPlayerAdded, function() end)
		dependencies.activated.connect(publish)
	end

	return {
		name = "SpeedService",
		start = start,
		getSpeed = getSpeed,
		publish = publish,
		setSpeed = setSpeed,
	}
end

return table.freeze(SpeedService)
