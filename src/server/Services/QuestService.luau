--!strict
-- Daily quests on the server: gives each player the UTC day's quests (on join and at midnight
-- while online), advances them from what the other services report and pays a claimed quest
-- with minutes of the player's own income and trainer rate (Domain/Quests). All state lives in
-- the profile; this service only listens and writes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CarryService = require(script.Parent.CarryService)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Pvp = require(ReplicatedStorage.Shared.Domain.Pvp)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local PvpService = require(script.Parent.PvpService)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local UtcDay = require(ReplicatedStorage.Shared.Domain.UtcDay)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local LOG = RunService:IsStudio()
-- Progress goes to the client at most this often (the trainer advances a quest 4 times a second).
local SEND_INTERVAL_SECONDS = 1

export type Notice = Quests.ClaimRefusal | Quests.RerollRefusal

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- Re-publishes the speed stat after a reward added speed points.
	publishSpeed: (player: Player) -> (),
	-- What the player did, from the other services.
	eggDelivered: Signal.Signal<Player, CarryService.Carried>,
	hatched: Signal.Signal<Player, string, Bay.Location, number>,
	trained: Signal.Signal<Player, BigNum.BigNum, number, Upgrades.TrainingSource>,
	crossbred: Signal.Signal<Player, string, Bay.Location, number>,
	-- Ability, did it hit, did an egg come loose.
	abilityUsed: Signal.Signal<Player, PvpService.AbilityKind, boolean, boolean>,
}

export type QuestService = {
	name: string,
	start: () -> (),
	-- The player's quests changed (a new day, progress, a claim, a swap).
	changed: Signal.Signal<Player>,
	-- A quest paid out.
	rewarded: Signal.Signal<Player, PlayReward.Paid>,
	-- A quest was finished (before it is claimed): its kind.
	completed: Signal.Signal<Player, string>,
	claim: (player: Player, index: number) -> Notice?,
	reroll: (player: Player, index: number) -> Notice?,
	-- Studio commands: finish every quest; give a fresh set as if a new day began.
	completeAll: (player: Player) -> boolean,
	newDay: (player: Player) -> boolean,
}

local QuestService = {}

local function now(): number
	return os.time()
end

-- The zone of the farthest guardian beaten, or the first zone.
local function frontierZone(data: PlayerData.PlayerData): string
	local post = math.clamp(data.bestPost, 1, ZoneConfig.POST_COUNT)
	return (ZoneConfig.zoneOfPost(post))
end

-- Three aliens that crossbreed together (Domain/Crossbreed) anywhere in the bay.
local function canCrossbreed(data: PlayerData.PlayerData): boolean
	local aliens: { PlayerData.AlienRecord } = table.clone(data.floor)
	for _, pod in data.pods do
		if pod.alien then
			table.insert(aliens, pod.alien)
		end
	end
	local trios = Crossbreed.trios(aliens, function(id: string): Crossbreed.Parent?
		return AlienConfig.ALIENS[id]
	end, function(_alien): number
		return 0
	end, BayConfig.CROSSBREED_COUNT)
	return #trios > 0
end

local function contextOf(data: PlayerData.PlayerData): Quests.Context
	return {
		zone = frontierZone(data),
		canCrossbreed = canCrossbreed(data),
		canFight = not Pvp.isNewbie(data.playSeconds, PvpConfig.RULES),
	}
end

function QuestService.new(dependencies: Dependencies): QuestService
	local changed = Signal.new() :: Signal.Signal<Player>
	local rewarded = Signal.new() :: Signal.Signal<Player, PlayReward.Paid>
	local completed = Signal.new() :: Signal.Signal<Player, string>
	local random = Random.new()
	local active: { [Player]: boolean } = {}
	-- Players whose progress changed since it was last sent.
	local unsent: { [Player]: boolean } = {}

	local function roll(): number
		return random:NextNumber()
	end

	-- Gives today's quests if the player does not have them yet.
	local function ensureDay(player: Player, day: number)
		local fresh = false
		dependencies.update(player, function(data)
			local context = contextOf(data)
			fresh = Quests.ensureDay(data.quests, day, QuestConfig.DEFINITIONS, context, QuestConfig.COUNT, roll)
		end)
		if fresh then
			if LOG then
				local data = dependencies.getData(player)
				local kinds = {}
				for _, record in if data then data.quests.list else {} do
					table.insert(kinds, `{record.kind} {record.target}`)
				end
				print(`[QuestService] {player.Name} day {day}: {table.concat(kinds, ", ")}`)
			end
			changed.fire(player)
		end
	end

	local function advance(player: Player, event: Quests.Event)
		if not active[player] then
			return
		end
		local finished: { number } = {}
		local anything = false
		local kinds: { string } = {}
		dependencies.update(player, function(data)
			finished, anything = Quests.advance(data.quests, event)
			for _, index in finished do
				table.insert(kinds, data.quests.list[index].kind)
			end
		end)
		-- A finished quest goes out at once (the claim button lights up); the rest waits.
		if #kinds > 0 then
			unsent[player] = nil
			changed.fire(player)
		elseif anything then
			unsent[player] = true
		end
		for _, kind in kinds do
			completed.fire(player, kind)
		end
	end

	local function sendUnsent()
		for player in unsent do
			if active[player] then
				changed.fire(player)
			end
		end
		table.clear(unsent)
	end

	local function claim(player: Player, index: number): Notice?
		local data = dependencies.getData(player)
		if not data then
			return "NoSuchQuest"
		end
		local record = data.quests.list[index]
		local definition = record and Quests.definition(QuestConfig.DEFINITIONS, record.kind)
		local income = dependencies.getIncomePerSecond(player)
		local notice: Notice? = nil
		local paid: PlayReward.Paid? = nil
		dependencies.update(player, function(current)
			notice = Quests.claim(current.quests, index)
			if notice then
				return
			end
			-- A quest from a pool entry since removed still closes, with the least reward.
			local minutes = if definition then definition.rewardMinutes else 0
			local pace = { income = income, trainerLevel = current.trainerLevel, jetpackLevel = current.jetpackLevel }
			local limit = {
				share = QuestConfig.MAX_SHARE_OF_EARNED,
				trained = current.trained,
				coinsEarned = current.coinsEarned,
			}
			paid = PlayReward.of(minutes, pace, QuestConfig.MIN_REWARD_COINS, true, UpgradeConfig.TUNING, limit)
			PlayReward.pay(current, paid :: PlayReward.Paid)
		end)
		if notice or not paid then
			return notice
		end
		dependencies.publishSpeed(player)
		changed.fire(player)
		rewarded.fire(player, paid)
		return nil
	end

	local function reroll(player: Player, index: number): Notice?
		local notice: Notice? = nil
		dependencies.update(player, function(data)
			notice = Quests.reroll(data.quests, index, QuestConfig.DEFINITIONS, contextOf(data), roll)
		end)
		if not notice then
			changed.fire(player)
		end
		return notice
	end

	local function completeAll(player: Player): boolean
		local written = dependencies.update(player, function(data)
			for _, record in data.quests.list do
				record.progress = record.target
			end
		end)
		if written then
			changed.fire(player)
		end
		return written
	end

	local function newDay(player: Player): boolean
		local data = dependencies.getData(player)
		if not data then
			return false
		end
		-- Any day other than the stored one starts a fresh set.
		ensureDay(player, data.quests.day + 1)
		return true
	end

	local function checkDay()
		local day = UtcDay.of(now())
		for player in active do
			local data = dependencies.getData(player)
			if data and data.quests.day < day then
				ensureDay(player, day)
			end
		end
	end

	local function start()
		dependencies.activated.connect(function(player)
			active[player] = true
			ensureDay(player, UtcDay.of(now()))
		end)
		PlayerEvents.observe(function() end, function(player)
			active[player] = nil
			unsent[player] = nil
		end)
		dependencies.scheduler.every(QuestConfig.DAY_CHECK_SECONDS, checkDay)
		dependencies.scheduler.every(SEND_INTERVAL_SECONDS, sendUnsent)

		dependencies.eggDelivered.connect(function(player, egg)
			local grade = egg.grade
			local known = grade ~= nil and grade >= 1 and grade <= ZoneConfig.POST_COUNT
			local zone = if known then (ZoneConfig.zoneOfPost(grade :: number)) else ""
			advance(player, { kind = "Delivered", zone = zone })
		end)
		dependencies.hatched.connect(function(player)
			advance(player, { kind = "Hatched" })
		end)
		-- "Train on the trainer": time on the stand only (flight trains too, decision 131).
		dependencies.trained.connect(function(player, _gain, seconds, source)
			if source == "Stand" then
				advance(player, { kind = "Trained", seconds = seconds })
			end
		end)
		dependencies.crossbred.connect(function(player)
			advance(player, { kind = "Crossbred" })
		end)
		dependencies.abilityUsed.connect(function(player, _kind, _hit, droppedEgg)
			if droppedEgg then
				advance(player, { kind = "KnockedEgg" })
			end
		end)
	end

	return {
		name = "QuestService",
		start = start,
		changed = changed,
		rewarded = rewarded,
		completed = completed,
		claim = claim,
		reroll = reroll,
		completeAll = completeAll,
		newDay = newDay,
	}
end

return table.freeze(QuestService)
