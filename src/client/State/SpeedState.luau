--!strict
-- The local player's speed stat, as the server publishes it on the player (SpeedConfig
-- MANTISSA_ATTRIBUTE / EXPONENT_ATTRIBUTE): one reactive source for the HUD and for the guardian
-- signs, which colour their names by it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type SpeedState = {
	name: string,
	start: () -> (),
	-- The stat now (reactive); the starting stat until the server publishes one.
	speed: () -> BigNum.BigNum,
}

local SpeedState = {}

function SpeedState.new(): SpeedState
	local speed = Vide.source(SpeedConfig.STARTING_SPEED)

	local function read(player: Player)
		local value = BigNum.fromSaved({
			mantissa = player:GetAttribute(SpeedConfig.MANTISSA_ATTRIBUTE),
			exponent = player:GetAttribute(SpeedConfig.EXPONENT_ATTRIBUTE),
		})
		speed(value or SpeedConfig.STARTING_SPEED)
	end

	local function start()
		local player = Players.LocalPlayer
		-- Mantissa and exponent arrive separately; reading both on either change is harmless.
		player:GetAttributeChangedSignal(SpeedConfig.MANTISSA_ATTRIBUTE):Connect(function()
			read(player)
		end)
		player:GetAttributeChangedSignal(SpeedConfig.EXPONENT_ATTRIBUTE):Connect(function()
			read(player)
		end)
		read(player)
	end

	return {
		name = "SpeedState",
		start = start,
		speed = function(): BigNum.BigNum
			return speed()
		end,
	}
end

return table.freeze(SpeedState)
