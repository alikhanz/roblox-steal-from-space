--!strict
-- The thin layer over Zap: sends each player their private data (a snapshot, then the section
-- that changed) and turns client commands into EconomyService calls. Every command passes the
-- rate limit and the active-profile check before it is looked at (CONVENTIONS, section 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EconomyService = require(script.Parent.EconomyService)
local NetConfig = require(ReplicatedStorage.Shared.Config.NetConfig)
local OfflineService = require(script.Parent.OfflineService)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local PvpService = require(script.Parent.PvpService)
local RateLimit = require(ReplicatedStorage.Shared.Domain.RateLimit)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	economy: EconomyService.EconomyService,
	-- Bay events to forward.
	bayChanged: Signal.Signal<Player>,
	coinsChanged: Signal.Signal<Player, BigNum.BigNum>,
	offlineSettled: Signal.Signal<Player, OfflineService.Reward>,
	hatched: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>,
	-- Trainer payouts to forward.
	trained: Signal.Signal<Player, BigNum.BigNum>,
	-- Ability results to forward.
	abilityUsed: Signal.Signal<Player, PvpService.AbilityKind, boolean, boolean>,
}

export type Notice = EconomyService.Notice | PvpService.Notice

export type NetService = {
	name: string,
	start: () -> (),
	-- Tells a player why something was refused (for commands that do not come through a remote).
	notify: (player: Player, notice: Notice) -> (),
}

local NetService = {}

-- A BigNum is read-only; the wire struct is a plain copy of the same two fields.
local function wire(value: BigNum.BigNum): { mantissa: number, exponent: number }
	return { mantissa = value.mantissa, exponent = value.exponent }
end

local function bayOf(data: PlayerData.PlayerData)
	return {
		pods = data.pods,
		inventory = data.inventory,
		floor = data.floor,
		incubator = data.incubator,
	}
end

function NetService.new(dependencies: Dependencies): NetService
	local limiter = RateLimit.new(NetConfig.COMMAND_LIMIT, NetConfig.COMMAND_WINDOW_SECONDS)

	local function upgradesOf(data: PlayerData.PlayerData)
		return { trainerLevel = data.trainerLevel, jetpackLevel = data.jetpackLevel }
	end

	local function sendSnapshot(player: Player)
		local data = dependencies.getData(player)
		if data then
			Remotes.ProfileSnapshot.Fire(
				player,
				{ coins = wire(data.coins), bay = bayOf(data), upgrades = upgradesOf(data) }
			)
		end
	end

	local function sendUpgrades(player: Player)
		local data = dependencies.getData(player)
		if data then
			Remotes.UpgradesChanged.Fire(player, upgradesOf(data))
		end
	end

	local function notify(player: Player, notice: Notice)
		Remotes.NoticeSent.Fire(player, notice)
	end

	-- Wraps a command handler with the rate limit and the profile check; a refusal becomes a
	-- notice on the client.
	local function guarded<T>(handler: (player: Player, value: T) -> EconomyService.Notice?): (Player, T) -> ()
		return function(player: Player, value: T)
			if not limiter.allow(tostring(player.UserId), os.clock()) then
				Remotes.NoticeSent.Fire(player, "TooFast")
				return
			end
			if not dependencies.getData(player) then
				Remotes.NoticeSent.Fire(player, "NoProfile")
				return
			end
			local notice = handler(player, value)
			if notice then
				Remotes.NoticeSent.Fire(player, notice)
			end
		end
	end

	local function start()
		local economy = dependencies.economy

		dependencies.activated.connect(sendSnapshot)
		dependencies.bayChanged.connect(function(player)
			local data = dependencies.getData(player)
			if data then
				Remotes.BayChanged.Fire(player, bayOf(data))
				-- Most bay changes cost or pay coins; the income tick only reports coins while
				-- something earns, so they travel together.
				Remotes.CoinsChanged.Fire(player, wire(data.coins))
			end
		end)
		dependencies.trained.connect(function(player, gain)
			Remotes.Trained.Fire(player, wire(gain))
		end)
		dependencies.abilityUsed.connect(function(player, kind, hit, droppedEgg)
			Remotes.AbilityResult.Fire(player, { kind = kind, hit = hit, droppedEgg = droppedEgg })
		end)
		economy.trainerUpgraded.connect(sendUpgrades)
		economy.jetpackUpgraded.connect(sendUpgrades)
		dependencies.coinsChanged.connect(function(player, coins)
			Remotes.CoinsChanged.Fire(player, wire(coins))
		end)
		dependencies.offlineSettled.connect(function(player, reward)
			Remotes.OfflineReward.Fire(
				player,
				{ coins = wire(reward.coins), speed = wire(reward.speed), seconds = reward.seconds }
			)
			local data = dependencies.getData(player)
			if data then
				Remotes.CoinsChanged.Fire(player, wire(data.coins))
			end
		end)
		dependencies.hatched.connect(function(player, alienId, location)
			Remotes.Hatched.Fire(player, { alienId = alienId, location = location })
		end)
		economy.crossbred.connect(function(player, alienId, location)
			Remotes.Crossbred.Fire(player, { alienId = alienId, location = location })
		end)

		Remotes.RequestSnapshot.SetCallback(guarded(function(player)
			sendSnapshot(player)
			return nil
		end))
		Remotes.AutoPlace.SetCallback(guarded(function(player)
			return economy.autoPlace(player)
		end))
		Remotes.MoveToPod.SetCallback(guarded(function(player, value: { uid: number, pod: number })
			return economy.moveToPod(player, value.uid, value.pod)
		end))
		Remotes.MoveToInventory.SetCallback(guarded(function(player, uid: number)
			return economy.moveToInventory(player, uid)
		end))
		Remotes.Crossbreed.SetCallback(guarded(function(player, uids: { number })
			return economy.crossbreed(player, uids)
		end))
		Remotes.Sell.SetCallback(guarded(function(player, uid: number)
			return economy.sell(player, uid)
		end))
		Remotes.BuyPod.SetCallback(guarded(function(player)
			return economy.buyPod(player)
		end))
		Remotes.UpgradeJetpack.SetCallback(guarded(function(player)
			return economy.upgradeJetpack(player)
		end))

		PlayerEvents.observe(function() end, function(player)
			limiter.forget(tostring(player.UserId))
		end)
	end

	return {
		name = "NetService",
		start = start,
		notify = notify,
	}
end

return table.freeze(NetService)
