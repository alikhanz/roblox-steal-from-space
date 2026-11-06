--!strict
-- The trainer pad in every bay: while the owner stands on it, their trained speed grows a few
-- times a second. The profile holds the level; the bay model carries it as an attribute for
-- the sign over the pad, whose button buys the next level (an UpgradeTrainer command).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Trainer = require(ReplicatedStorage.Shared.Domain.Trainer)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	-- A player got their bay (its model holds the trainer pad).
	bayAssigned: Signal.Signal<Player, Model>,
	getBayOrigin: (player: Player) -> CFrame?,
	-- Re-publishes the speed stat after the trained speed changed.
	publishSpeed: (player: Player) -> (),
	trainerUpgraded: Signal.Signal<Player>,
}

export type TrainingService = {
	name: string,
	start: () -> (),
	-- Fires on every payout: the player, the speed points gained and the seconds trained.
	trained: Signal.Signal<Player, BigNum.BigNum, number>,
}

type Station = {
	model: Model,
}

local TrainingService = {}

function TrainingService.new(dependencies: Dependencies): TrainingService
	local stations: { [Player]: Station } = {}
	local trained = Signal.new() :: Signal.Signal<Player, BigNum.BigNum, number>

	-- The level on the bay model: the sign over the pad reads it.
	local function describe(player: Player, station: Station)
		local data = dependencies.getData(player)
		station.model:SetAttribute(BayConfig.TRAINER_LEVEL_ATTRIBUTE, if data then data.trainerLevel else 0)
	end

	local function onBayAssigned(player: Player, model: Model)
		if not model:FindFirstChild(BayConfig.TRAINER_NAME) then
			warn(`[TrainingService] {model.Name} has no {BayConfig.TRAINER_NAME}; no training for {player.Name}`)
			return
		end
		local station: Station = { model = model }
		stations[player] = station
		describe(player, station)
	end

	local function release(player: Player)
		stations[player] = nil
	end

	-- True while the owner's character stands on their pad (not flying, not jumping over it).
	local function isTraining(player: Player): boolean
		local origin = dependencies.getBayOrigin(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not origin or not character or not root or not root:IsA("BasePart") then
			return false
		end
		if character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true then
			return false
		end
		local local_ = origin:PointToObjectSpace(root.Position)
		return Trainer.isOnPad(local_.X, local_.Y, local_.Z, BayConfig.TRAINER_PAD, BayConfig.TRAINER_TOLERANCE)
	end

	local function tick(deltaTime: number)
		for player in stations do
			if not isTraining(player) then
				continue
			end
			local gain: BigNum.BigNum? = nil
			dependencies.update(player, function(data)
				-- Double training doubles it (decision 061).
				local effects = Purchases.passEffects(data.passes, MonetizationConfig.PASS_TUNING)
				local rate = Purchases.trainerRate(data.trainerLevel, effects.trainerMultiplier, UpgradeConfig.TUNING)
				gain = Upgrades.trainingGain(rate, deltaTime, 1)
				data.trained = BigNum.add(data.trained, gain :: BigNum.BigNum)
			end)
			if gain then
				dependencies.publishSpeed(player)
				trained.fire(player, gain :: BigNum.BigNum, deltaTime)
			end
		end
	end

	local function start()
		dependencies.bayAssigned.connect(onBayAssigned)
		dependencies.trainerUpgraded.connect(function(player)
			local station = stations[player]
			if station then
				describe(player, station)
			end
		end)
		Players.PlayerRemoving:Connect(release)
		dependencies.scheduler.every(UpgradeConfig.TRAINING_TICK_SECONDS, tick)
	end

	return {
		name = "TrainingService",
		start = start,
		trained = trained,
	}
end

return table.freeze(TrainingService)
