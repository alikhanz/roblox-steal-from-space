--!strict
-- The local player's speed stat, as the server publishes it on the player (SpeedConfig
-- MANTISSA_ATTRIBUTE / EXPONENT_ATTRIBUTE): one reactive source for the guardian signs, which
-- colour their names by it, and the goal. The HUD's plaque reads `shown`: the same stat counting up
-- to each new value over a training batch (decision 134), so it climbs smoothly in flight instead
-- of jumping once a second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Ease = require(ReplicatedStorage.Shared.Domain.Ease)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type SpeedState = {
	name: string,
	start: () -> (),
	-- The stat now (reactive); the starting stat until the server publishes one.
	speed: () -> BigNum.BigNum,
	-- The stat as the plaque shows it: walking up to `speed` (reactive).
	shown: () -> BigNum.BigNum,
}

local SpeedState = {}

function SpeedState.new(): SpeedState
	local speed = Vide.source(SpeedConfig.STARTING_SPEED)
	local shown = Vide.source(SpeedConfig.STARTING_SPEED)
	-- The walk under way: from what was shown, since when.
	local walkFrom = SpeedConfig.STARTING_SPEED
	local walkStart = 0
	local walking: RBXScriptConnection? = nil
	local hasValue = false

	local function step()
		local target = Vide.untrack(speed)
		local value = Ease.towards(walkFrom, target, os.clock() - walkStart, UpgradeConfig.TRAINING_BATCH_SECONDS)
		shown(value)
		if BigNum.equals(value, target) and walking then
			walking:Disconnect()
			walking = nil
		end
	end

	local function read(player: Player)
		local value = BigNum.fromSaved({
			mantissa = player:GetAttribute(SpeedConfig.MANTISSA_ATTRIBUTE),
			exponent = player:GetAttribute(SpeedConfig.EXPONENT_ATTRIBUTE),
		}) or SpeedConfig.STARTING_SPEED
		speed(value)
		-- The first value is shown as it is; later ones are walked to from what is on screen.
		if not hasValue then
			hasValue = player:GetAttribute(SpeedConfig.MANTISSA_ATTRIBUTE) ~= nil
			shown(value)
			return
		end
		walkFrom = Vide.untrack(shown)
		walkStart = os.clock()
		if not walking then
			walking = RunService.RenderStepped:Connect(step)
		end
		step()
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
		shown = function(): BigNum.BigNum
			return shown()
		end,
	}
end

return table.freeze(SpeedState)
