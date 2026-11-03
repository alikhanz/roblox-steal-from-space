--!strict
-- Owns each player's speed stat and publishes it: the stat itself as player attributes (for the
-- HUD and for anyone looking at a player) and the flight speed derived from it as a character
-- attribute (for the simulation, which never touches BigNum). Lives in memory until profiles
-- hold the stat (stage 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)

export type SpeedService = {
	name: string,
	start: () -> (),
	getSpeed: (player: Player) -> BigNum.BigNum,
	setSpeed: (player: Player, speed: BigNum.BigNum) -> (),
}

local SpeedService = {}

function SpeedService.new(): SpeedService
	local speeds: { [Player]: BigNum.BigNum } = {}

	local function getSpeed(player: Player): BigNum.BigNum
		return speeds[player] or SpeedConfig.STARTING_SPEED
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

	local function setSpeed(player: Player, speed: BigNum.BigNum)
		speeds[player] = speed
		publish(player)
	end

	local function onPlayerAdded(player: Player)
		speeds[player] = SpeedConfig.STARTING_SPEED
		player.CharacterAdded:Connect(function()
			publish(player)
		end)
		publish(player)
	end

	local function start()
		PlayerEvents.observe(onPlayerAdded, function(player: Player)
			speeds[player] = nil
		end)
	end

	return {
		name = "SpeedService",
		start = start,
		getSpeed = getSpeed,
		setSpeed = setSpeed,
	}
end

return table.freeze(SpeedService)
