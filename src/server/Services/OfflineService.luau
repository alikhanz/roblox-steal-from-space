--!strict
-- Progress while the player was away, paid once when their profile activates: the pods' income
-- and the trainer's gain, each with its own cap, in one profile update, and the eggs that
-- became ready in the meantime (decision 059: they wait for the player). Owns the profile's
-- clock: once a second while the player is online it moves the last-seen mark and adds to
-- their play time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Offline = require(ReplicatedStorage.Shared.Domain.Offline)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

local MARK_INTERVAL_SECONDS = 1
local LOG = RunService:IsStudio()

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	-- What the player's pods earn per second right now.
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- Re-publishes the speed stat after the trained speed changed.
	publishSpeed: (player: Player) -> (),
}

-- What one settlement paid: coins, speed stat gained (as the player sees it), the time away
-- and the eggs ready to hatch.
export type Reward = {
	coins: BigNum.BigNum,
	speed: BigNum.BigNum,
	seconds: number,
	readyEggs: number,
	-- "Collect x2" can pay this time away once more.
	canDouble: boolean,
}

export type OfflineService = {
	name: string,
	start: () -> (),
	-- Pays for the time since the last-seen mark and restarts the clock (done on activation;
	-- exposed for playtests of the welcome-back screen).
	settle: (player: Player) -> (),
	-- Fires after a settlement that paid something.
	settled: Signal.Signal<Player, Reward>,
}

local OfflineService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function OfflineService.new(dependencies: Dependencies): OfflineService
	local settled = Signal.new() :: Signal.Signal<Player, Reward>

	local function settle(player: Player)
		local reward: Reward? = nil
		dependencies.update(player, function(data)
			local current = now()
			-- Night shift lengthens both caps, Double training doubles the rate (decision 061).
			local effects = Purchases.passEffects(data.passes, MonetizationConfig.PASS_TUNING)
			local incomeSeconds = Offline.seconds(data.lastSeenAt, current, effects.offlineIncomeCapSeconds)
			local trainingSeconds = Offline.seconds(data.lastSeenAt, current, effects.offlineTrainingCapSeconds)
			local earned = Offline.income(dependencies.getIncomePerSecond(player), incomeSeconds)
			local rate = Purchases.trainerRate(data.trainerLevel, effects.trainerMultiplier, UpgradeConfig.TUNING)
			local gained = Upgrades.trainingGain(rate, trainingSeconds, UpgradeConfig.OFFLINE_TRAINING_FACTOR)

			Wallet.earn(data, earned)
			data.trained = BigNum.add(data.trained, gained)
			-- "Collect x2" pays this time away once more; a new time away replaces the last one.
			if not BigNum.isZero(earned) or not BigNum.isZero(gained) then
				Purchases.setPendingDouble(data, earned, gained)
			end
			-- Whole seconds: the screen says "1 hour", not "1.1 hours", for an hour and a moment.
			local awaySeconds = if data.lastSeenAt > 0 then math.max(math.floor(current - data.lastSeenAt), 0) else 0
			data.lastSeenAt = current
			local readyEggs = Bay.readyCount(data, current)
			if not BigNum.isZero(earned) or not BigNum.isZero(gained) or readyEggs > 0 then
				reward = {
					coins = earned,
					speed = BigNum.mul(gained, Upgrades.jetpackMultiplier(data.jetpackLevel, UpgradeConfig.TUNING)),
					seconds = awaySeconds,
					readyEggs = readyEggs,
					canDouble = Purchases.hasPendingDouble(data),
				}
			end
		end)
		if not reward then
			return
		end
		local paid = reward :: Reward
		dependencies.publishSpeed(player)
		if LOG then
			print(
				`[OfflineService] {player.Name} was away {math.floor(paid.seconds)}s: `
					.. `{BigNum.format(paid.coins)} coins, +{BigNum.format(paid.speed)} speed, {paid.readyEggs} eggs ready`
			)
		end
		settled.fire(player, paid)
	end

	-- Moves every online player's mark forward and counts their play time.
	local function mark(deltaTime: number)
		local current = now()
		for _, player in game:GetService("Players"):GetPlayers() do
			if dependencies.getData(player) then
				dependencies.update(player, function(data)
					data.lastSeenAt = current
					data.playSeconds += deltaTime
				end)
			end
		end
	end

	local function start()
		dependencies.activated.connect(settle)
		dependencies.scheduler.every(MARK_INTERVAL_SECONDS, mark)
	end

	return {
		name = "OfflineService",
		start = start,
		settle = settle,
		settled = settled,
	}
end

return table.freeze(OfflineService)
