--!strict
-- The thin layer over Zap: sends each player their private data (a snapshot, then the section
-- that changed) and turns client commands into EconomyService calls. Every command passes the
-- rate limit and the active-profile check before it is looked at (CONVENTIONS, section 5), and
-- counts as the player being at the keyboard (ActivityService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CoachService = require(script.Parent.CoachService)
local CommunityService = require(script.Parent.CommunityService)
local EconomyService = require(script.Parent.EconomyService)
local IndexService = require(script.Parent.IndexService)
local LoginGiftService = require(script.Parent.LoginGiftService)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local NetConfig = require(ReplicatedStorage.Shared.Config.NetConfig)
local OfflineService = require(script.Parent.OfflineService)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local PurchaseService = require(script.Parent.PurchaseService)
local PvpService = require(script.Parent.PvpService)
local QuestService = require(script.Parent.QuestService)
local RateLimit = require(ReplicatedStorage.Shared.Domain.RateLimit)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StormService = require(script.Parent.StormService)
local TutorialService = require(script.Parent.TutorialService)

-- The quest kinds the wire knows; a saved quest of another kind is not sent.
local QUEST_KINDS: { [string]: Remotes.QuestKind } = {
	DeliverEggs = "DeliverEggs",
	DeliverFromZone = "DeliverFromZone",
	HatchAliens = "HatchAliens",
	Train = "Train",
	Crossbreed = "Crossbreed",
	KnockEgg = "KnockEgg",
}

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
	trained: Signal.Signal<Player, BigNum.BigNum, number>,
	-- Ability results to forward.
	abilityUsed: Signal.Signal<Player, PvpService.AbilityKind, boolean, boolean>,
	-- The harpoon's and the bomb's looks, for every client to draw.
	harpoonShot: Signal.Signal<PvpService.Shot>,
	bombThrown: Signal.Signal<PvpService.Throw>,
	bombExploded: Signal.Signal<PvpService.Blast>,
	quests: QuestService.QuestService,
	loginGift: LoginGiftService.LoginGiftService,
	index: IndexService.IndexService,
	tutorial: TutorialService.TutorialService,
	coach: CoachService.CoachService,
	-- The community gift (decision 098).
	community: CommunityService.CommunityService,
	-- Granted Robux purchases: what they gave goes to the client.
	purchased: Signal.Signal<Player, PurchaseService.Granted>,
	-- A purchase prompt the client is about to show (PurchaseService.notePrompt).
	notePrompt: (
		player: Player,
		item: MonetizationConfig.ShopItem,
		source: MonetizationConfig.ShopSource,
		egg: number?
	) -> PurchaseService.Notice?,
	-- Every command a player sends counts as them playing (ActivityService).
	markActive: (player: Player) -> (),
	-- The pet bench: fill the island or clear it (BenchService.run; checks who may).
	bench: (player: Player, fill: boolean) -> (),
	-- The guardian bench or gallery: set it round the player or take it away (Off;
	-- BenchService.showGuardians).
	benchGuardians: (player: Player, display: "Off" | "Bench" | "Gallery") -> (),
	-- "Don't show again" in the controls window (ControlsService.setHidden).
	setControlsHidden: (player: Player, hidden: boolean) -> (),
}

export type Notice =
	EconomyService.Notice
	| PvpService.Notice
	| QuestService.Notice
	| LoginGiftService.Notice
	| IndexService.Notice
	| StormService.Notice
	| PurchaseService.Notice
	| CommunityService.Notice

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
		floor = data.floor,
		incubator = data.incubator,
		incubatorSlots = data.incubatorSlots,
		waiting = data.waiting,
	}
end

local function questsOf(data: PlayerData.PlayerData): Remotes.Quests
	local list = {}
	for _, record in data.quests.list do
		local kind = QUEST_KINDS[record.kind]
		if kind then
			table.insert(list, {
				kind = kind,
				target = record.target,
				progress = record.progress,
				claimed = record.claimed,
				zone = record.zone,
			})
		end
	end
	return { day = data.quests.day, rerolled = data.quests.rerolled, list = list }
end

local function indexOf(data: PlayerData.PlayerData): Remotes.Index
	return { found = data.index.found, sets = data.index.sets }
end

function NetService.new(dependencies: Dependencies): NetService
	local limiter = RateLimit.new(NetConfig.COMMAND_LIMIT, NetConfig.COMMAND_WINDOW_SECONDS)

	local function upgradesOf(data: PlayerData.PlayerData)
		return { trainerLevel = data.trainerLevel, jetpackLevel = data.jetpackLevel }
	end

	local function giftOf(player: Player): Remotes.LoginGift
		local status = dependencies.loginGift.getStatus(player)
		return if status
			then { day = status.day, available = status.available, reset = status.reset, locked = status.locked }
			else { day = 1, available = false, reset = false, locked = false }
	end

	local function sendSnapshot(player: Player)
		local data = dependencies.getData(player)
		if data then
			Remotes.ProfileSnapshot.Fire(player, {
				coins = wire(data.coins),
				bay = bayOf(data),
				upgrades = upgradesOf(data),
				quests = questsOf(data),
				loginGift = giftOf(player),
				index = indexOf(data),
			})
		end
		local hint = dependencies.tutorial.getHint(player)
		if hint then
			Remotes.TutorialChanged.Fire(player, hint)
		end
		Remotes.CoachChanged.Fire(player, dependencies.coach.getTip(player))
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
	local function guarded<T>(handler: (player: Player, value: T) -> Notice?): (Player, T) -> ()
		return function(player: Player, value: T)
			if not limiter.allow(tostring(player.UserId), os.clock()) then
				Remotes.NoticeSent.Fire(player, "TooFast")
				return
			end
			dependencies.markActive(player)
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
		dependencies.harpoonShot.connect(Remotes.HarpoonShot.FireAll)
		dependencies.bombThrown.connect(Remotes.BombThrown.FireAll)
		dependencies.bombExploded.connect(Remotes.BombExploded.FireAll)
		economy.trainerUpgraded.connect(sendUpgrades)
		economy.jetpackUpgraded.connect(sendUpgrades)
		dependencies.coinsChanged.connect(function(player, coins)
			Remotes.CoinsChanged.Fire(player, wire(coins))
		end)
		dependencies.offlineSettled.connect(function(player, reward)
			Remotes.OfflineReward.Fire(player, {
				coins = wire(reward.coins),
				speed = wire(reward.speed),
				seconds = reward.seconds,
				readyEggs = reward.readyEggs,
				doubleTier = reward.doubleTier,
			})
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
		local quests = dependencies.quests
		quests.changed.connect(function(player)
			local data = dependencies.getData(player)
			if data then
				Remotes.QuestsChanged.Fire(player, questsOf(data))
			end
		end)
		local alienIndex = dependencies.index
		alienIndex.changed.connect(function(player)
			local data = dependencies.getData(player)
			if data then
				Remotes.IndexChanged.Fire(player, indexOf(data))
			end
		end)
		alienIndex.rewarded.connect(function(player, coins)
			Remotes.IndexRewarded.Fire(player, wire(coins))
			local data = dependencies.getData(player)
			if data then
				Remotes.CoinsChanged.Fire(player, wire(data.coins))
			end
		end)
		local loginGift = dependencies.loginGift
		loginGift.changed.connect(function(player)
			Remotes.LoginGiftChanged.Fire(player, giftOf(player))
		end)
		dependencies.tutorial.changed.connect(function(player, hint)
			Remotes.TutorialChanged.Fire(player, hint)
		end)
		dependencies.coach.changed.connect(function(player, tip)
			Remotes.CoachChanged.Fire(player, tip)
		end)
		loginGift.rewarded.connect(function(player, reward)
			Remotes.LoginGiftRewarded.Fire(player, {
				day = reward.day,
				coins = wire(reward.paid.coins),
				speed = wire(reward.paid.speed),
				egg = reward.egg,
			})
			local data = dependencies.getData(player)
			if data then
				Remotes.CoinsChanged.Fire(player, wire(data.coins))
			end
		end)
		dependencies.purchased.connect(function(player, granted)
			Remotes.Purchased.Fire(player, {
				kind = granted.kind,
				compensated = granted.compensated,
				hatched = granted.hatched,
				coins = wire(granted.coins),
				speed = wire(granted.speed),
			})
			local data = dependencies.getData(player)
			if data then
				Remotes.CoinsChanged.Fire(player, wire(data.coins))
			end
		end)
		local community = dependencies.community
		community.rewarded.connect(function(player, speed)
			Remotes.CommunityRewarded.Fire(player, wire(speed))
		end)
		quests.rewarded.connect(function(player, paid)
			Remotes.QuestRewarded.Fire(player, { coins = wire(paid.coins), speed = wire(paid.speed) })
			local data = dependencies.getData(player)
			if data then
				Remotes.CoinsChanged.Fire(player, wire(data.coins))
			end
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
		Remotes.MoveToShelf.SetCallback(guarded(function(player, uid: number)
			return economy.moveToShelf(player, uid)
		end))
		Remotes.Crossbreed.SetCallback(guarded(function(player, uids: { number })
			return economy.crossbreed(player, uids)
		end))
		Remotes.Sell.SetCallback(guarded(function(player, uid: number)
			return economy.sell(player, uid)
		end))
		Remotes.SellMany.SetCallback(guarded(function(player, uids: { number })
			return economy.sellMany(player, uids)
		end))
		Remotes.BuyPod.SetCallback(guarded(function(player)
			return economy.buyPod(player)
		end))
		Remotes.BenchGuardians.SetCallback(guarded(function(player, display: "Off" | "Bench" | "Gallery")
			dependencies.benchGuardians(player, display)
			return nil
		end))
		Remotes.Bench.SetCallback(guarded(function(player, fill: boolean)
			dependencies.bench(player, fill)
			return nil
		end))
		Remotes.BuyIncubatorSlot.SetCallback(guarded(function(player)
			return economy.buyIncubatorSlot(player)
		end))
		Remotes.UpgradeJetpack.SetCallback(guarded(function(player)
			return economy.upgradeJetpack(player)
		end))
		Remotes.UpgradeTrainer.SetCallback(guarded(function(player)
			return economy.upgradeTrainer(player)
		end))
		Remotes.ClaimQuest.SetCallback(guarded(function(player, index: number)
			return quests.claim(player, index)
		end))
		Remotes.RerollQuest.SetCallback(guarded(function(player, index: number)
			return quests.reroll(player, index)
		end))
		Remotes.ClaimLoginGift.SetCallback(guarded(function(player)
			return loginGift.claim(player)
		end))
		Remotes.CommunityPrompted.SetCallback(guarded(function(player)
			return community.notePrompt(player)
		end))
		Remotes.CommunityJoined.SetCallback(guarded(function(player)
			return community.joined(player)
		end))
		Remotes.SetControlsHidden.SetCallback(guarded(function(player, hidden: boolean)
			dependencies.setControlsHidden(player, hidden)
			return nil
		end))
		Remotes.ClaimIndexAlien.SetCallback(guarded(function(player, alienId: string)
			return alienIndex.claimAlien(player, alienId)
		end))
		Remotes.ClaimIndexSet.SetCallback(guarded(function(player, setId: string)
			return alienIndex.claimSet(player, setId)
		end))
		Remotes.ClaimIndexAll.SetCallback(guarded(function(player)
			return alienIndex.claimAll(player)
		end))
		Remotes.PurchasePrompted.SetCallback(
			guarded(function(player, value: { item: Remotes.ShopItem, source: Remotes.ShopSource, egg: number? })
				return dependencies.notePrompt(player, value.item, value.source, value.egg)
			end)
		)

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
