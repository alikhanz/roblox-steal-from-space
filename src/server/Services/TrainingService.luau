--!strict
-- The trainer pad in every bay: while the owner stands on it, their trained speed grows once
-- a second; an engine prompt on the pad buys the next trainer level. The profile holds the
-- level; the bay model carries it as an attribute for the sign over the pad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EconomyService = require(script.Parent.EconomyService)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Trainer = require(ReplicatedStorage.Shared.Domain.Trainer)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)

-- The prompt is held briefly so a passing tap does not spend coins.
local PROMPT_HOLD_SECONDS = 0.4

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	-- A player got their bay (its model holds the trainer pad).
	bayAssigned: Signal.Signal<Player, Model>,
	getBayOrigin: (player: Player) -> CFrame?,
	-- Re-publishes the speed stat after the trained speed changed.
	publishSpeed: (player: Player) -> (),
	upgradeTrainer: (player: Player) -> EconomyService.Notice?,
	trainerUpgraded: Signal.Signal<Player>,
	-- Tells the player why the prompt refused.
	notify: (player: Player, notice: EconomyService.Notice) -> (),
}

export type TrainingService = {
	name: string,
	start: () -> (),
	-- Fires on every payout: the player and the speed points gained.
	trained: Signal.Signal<Player, BigNum.BigNum>,
}

type Station = {
	model: Model,
	prompt: ProximityPrompt,
	locale: Text.Locale,
}

local TrainingService = {}

function TrainingService.new(dependencies: Dependencies): TrainingService
	local stations: { [Player]: Station } = {}
	local trained = Signal.new() :: Signal.Signal<Player, BigNum.BigNum>

	local function describe(player: Player, station: Station)
		local data = dependencies.getData(player)
		local level = if data then data.trainerLevel else 0
		local price = Upgrades.trainerPrice(level, UpgradeConfig.TUNING)
		station.model:SetAttribute(BayConfig.TRAINER_LEVEL_ATTRIBUTE, level)
		station.prompt.ObjectText = Text.get(station.locale, "trainer.level.hint", { level = level })
		station.prompt.ActionText = Text.get(station.locale, "trainer.upgrade.button", { price = BigNum.format(price) })
	end

	local function onBayAssigned(player: Player, model: Model)
		local pad = model:FindFirstChild(BayConfig.TRAINER_NAME)
		if not pad or not pad:IsA("BasePart") then
			warn(`[TrainingService] {model.Name} has no {BayConfig.TRAINER_NAME}; no training for {player.Name}`)
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.MaxActivationDistance = BayConfig.TRAINER_PROMPT_DISTANCE
		prompt.HoldDuration = PROMPT_HOLD_SECONDS
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(who)
			if who ~= player then
				return
			end
			local notice = dependencies.upgradeTrainer(player)
			if notice then
				dependencies.notify(player, notice)
			end
		end)
		local station: Station = { model = model, prompt = prompt, locale = Text.resolveLocale(player.LocaleId) }
		stations[player] = station
		describe(player, station)
		prompt.Parent = pad
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
				local rate = Upgrades.trainerRate(data.trainerLevel, UpgradeConfig.TUNING)
				gain = Upgrades.trainingGain(rate, deltaTime, 1)
				data.trained = BigNum.add(data.trained, gain :: BigNum.BigNum)
			end)
			if gain then
				dependencies.publishSpeed(player)
				trained.fire(player, gain :: BigNum.BigNum)
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
