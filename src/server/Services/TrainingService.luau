--!strict
-- Training online (decision 131): a few times a second the player's trained speed grows by their
-- trainer's rate, all of it while they fly in space, half of it while the jetpack stand on their
-- island holds them (docs/design/screens/jetpack-stand.md; UpgradeConfig.TRAINING_FACTORS). The
-- simulation pulls the owner onto the stand and lets them off (Domain/Stand). The profile holds
-- the trainer's level; the bay model carries it for the trainer's terminal, whose button buys the
-- next level (an UpgradeTrainer command), and the stand wears the look of its level (decision 091).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayModel = require(script.Parent.Parent.World.BayModel)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vitals = require(ReplicatedStorage.Shared.Character.Vitals)

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	-- A player got their bay (its model holds the trainer pad).
	bayAssigned: Signal.Signal<Player, Model>,
	-- Re-publishes the speed stat after the trained speed changed.
	publishSpeed: (player: Player) -> (),
	trainerUpgraded: Signal.Signal<Player>,
}

export type TrainingService = {
	name: string,
	start: () -> (),
	-- Fires once a batch (about a second of training, or less when it stopped or moved): the
	-- player, the speed points gained, the seconds trained and where.
	trained: Signal.Signal<Player, BigNum.BigNum, number, Upgrades.TrainingSource>,
}

type Station = {
	model: Model,
}

local TrainingService = {}

function TrainingService.new(dependencies: Dependencies): TrainingService
	local stations: { [Player]: Station } = {}
	local trained = Signal.new() :: Signal.Signal<Player, BigNum.BigNum, number, Upgrades.TrainingSource>

	-- The level on the bay model (the trainer's terminal reads it), on the stand (its look) and on
	-- the player (the stand's flame grows with it).
	local function describe(player: Player, station: Station)
		local data = dependencies.getData(player)
		local level = if data then data.trainerLevel else 0
		station.model:SetAttribute(BayConfig.TRAINER_LEVEL_ATTRIBUTE, level)
		player:SetAttribute(StandConfig.TRAINER_LEVEL_ATTRIBUTE, level)
		BayModel.dressStand(station.model, level)
	end

	local function onBayAssigned(player: Player, model: Model)
		if not model:FindFirstChild(BayConfig.STAND_NAME) then
			warn(`[TrainingService] {model.Name} has no {BayConfig.STAND_NAME}; no training for {player.Name}`)
			return
		end
		local station: Station = { model = model }
		stations[player] = station
		describe(player, station)
	end

	-- Training already in the profile but not yet told: the speed attributes, the client's pops
	-- and the analytics hear of it once a batch (UpgradeConfig.TRAINING_BATCH_SECONDS, decision
	-- 134). Telling every tick sent the HUD, the pops and the predicted character's FlightSpeed four
	-- updates a second in flight, and the client saw them arrive in jerks.
	type Batch = { gain: BigNum.BigNum, seconds: number, source: Upgrades.TrainingSource }
	local batches: { [Player]: Batch } = {}

	local function flush(player: Player)
		local batch = batches[player]
		if not batch then
			return
		end
		batches[player] = nil
		dependencies.publishSpeed(player)
		trained.fire(player, batch.gain, batch.seconds, batch.source)
	end

	local function release(player: Player)
		stations[player] = nil
		batches[player] = nil
	end

	-- Where the player trains now: in space, alive (oxygen ends a flight within minutes, so no
	-- one trains there idle for long), or held by their own stand (the simulation decides it:
	-- Domain/Stand); nil when nowhere. Flight under a dome is not in space and does not count.
	local function sourceOf(player: Player): Upgrades.TrainingSource?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or not Vitals.isAlive(humanoid) then
			return nil
		end
		if character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true then
			return "Flight"
		end
		local onStand = stations[player] ~= nil
			and Stand.isTraining(Stand.parse(character:GetAttribute(StandConfig.STATE_ATTRIBUTE)))
		return if onStand then "Stand" else nil
	end

	local function tick(deltaTime: number)
		for _, player in Players:GetPlayers() do
			local source = sourceOf(player)
			local batch = batches[player]
			-- Training stopped or moved (stand to flight): what was gathered is told at once.
			if batch and batch.source ~= source then
				flush(player)
				batch = nil
			end
			if not source then
				continue
			end
			local gain: BigNum.BigNum? = nil
			dependencies.update(player, function(data)
				-- Double training doubles it (decision 132).
				local effects = Purchases.effects(data.subscriptions, MonetizationConfig.SUBSCRIPTION_TUNING)
				local rate = Purchases.trainerRate(data.trainerLevel, effects.trainerMultiplier, UpgradeConfig.TUNING)
				gain = Upgrades.trainingGain(rate, deltaTime, UpgradeConfig.TRAINING_FACTORS[source])
				data.trained = BigNum.add(data.trained, gain :: BigNum.BigNum)
			end)
			if not gain then
				continue
			end
			-- In the profile at once (nothing is lost on leaving); told by the batch.
			if batch then
				batch.gain = BigNum.add(batch.gain, gain :: BigNum.BigNum)
				batch.seconds += deltaTime
			else
				batch = { gain = gain :: BigNum.BigNum, seconds = deltaTime, source = source }
				batches[player] = batch
			end
			if (batch :: Batch).seconds >= UpgradeConfig.TRAINING_BATCH_SECONDS - 1e-6 then
				flush(player)
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
