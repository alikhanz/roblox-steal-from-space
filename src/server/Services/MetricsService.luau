--!strict
-- Analytics: the new player's funnel, progression through the guardians, the coin and speed
-- economy, each theft as a funnel, and counted gameplay events. Other services only report
-- facts through their signals; this is the one place that knows Roblox's AnalyticsService.
--
-- Frequent facts (pod income every second, trainer payouts, ability uses) are summed per player
-- and sent every few minutes and when the player leaves, to stay well inside the rate limit
-- (120 + 20 x CCU requests a minute). Field values never hold player names: their combinations
-- are capped. Studio cannot send events, so there every event is printed instead.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CarryService = require(script.Parent.CarryService)
local EconomyService = require(script.Parent.EconomyService)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local OfflineService = require(script.Parent.OfflineService)
local Onboarding = require(ReplicatedStorage.Shared.Domain.Onboarding)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local PvpService = require(script.Parent.PvpService)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local IS_STUDIO = RunService:IsStudio()
-- How often summed facts are sent, seconds (sooner in Studio, to see them while testing).
local FLUSH_SECONDS = if IS_STUDIO then 30 else 300
-- How often the "left the station" funnel step is looked for, seconds.
local WATCH_SECONDS = 1

local COINS = "Coins"
local SPEED = "Speed"
local GUARDIAN_PATH = "Guardians"
local THEFT_FUNNEL = "Theft"
local THEFT_STEPS = { Grabbed = 1, ReachedStation = 2, Delivered = 3 }
-- The tutorial (decision 065): one funnel session per account; step n + 1 is progress n
-- (Domain/Tutorial), so a step is never logged twice.
local TUTORIAL_FUNNEL = "Tutorial"
local TUTORIAL_STEPS = { "Started", "Delivered", "Hatched", "Trained", "Done" }

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

export type Currency = "Coins" | "Speed"
export type Flow = "Source" | "Sink"

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	getSpeed: (player: Player) -> BigNum.BigNum,
	scheduler: Scheduler.Scheduler,
	-- The facts reported.
	incomePaid: Signal.Signal<Player, BigNum.BigNum, BigNum.BigNum>,
	coinsTraded: Signal.Signal<Player, EconomyService.CoinTrade, BigNum.BigNum, BigNum.BigNum>,
	offlineSettled: Signal.Signal<Player, OfflineService.Reward>,
	trained: Signal.Signal<Player, BigNum.BigNum, number>,
	hatched: Signal.Signal<Player, string, Bay.Location>,
	crossbred: Signal.Signal<Player, string, Bay.Location>,
	eggGrabbed: Signal.Signal<Player, CarryService.Carried, CarryService.GrabSource>,
	eggReachedStation: Signal.Signal<Player, CarryService.Carried>,
	eggDelivered: Signal.Signal<Player, CarryService.Carried>,
	eggLost: Signal.Signal<Player, CarryService.Carried, CarryService.LossReason>,
	suffocated: Signal.Signal<Player, Vector3>,
	abilityUsed: Signal.Signal<Player, PvpService.AbilityKind, boolean, boolean>,
}

export type MetricsService = {
	name: string,
	start: () -> (),
	-- For rewards added later (quests, daily gifts): coins or speed the player got, and from what.
	earned: (player: Player, currency: Currency, sku: string, amount: BigNum.BigNum) -> (),
	-- Counts a gameplay event; up to three field values (no player names).
	count: (player: Player, eventName: string, fields: { string }?) -> (),
	-- An alien entered the player's index for the first time.
	found: (player: Player, alienId: string) -> (),
	-- A server event began: counted for every player on the server (events are per server, and
	-- analytics events belong to a player).
	serverEvent: (eventId: string) -> (),
	-- The player reached tutorial progress `progress` (0: it started).
	tutorialStep: (player: Player, progress: number) -> (),
}

-- Summed facts of one player, waiting to be sent.
type Pending = {
	-- "<currency>|<flow>|<sku>" -> amount.
	economy: { [string]: BigNum.BigNum },
	-- "<event>|<field>|<field>|<field>" -> count.
	counts: { [string]: number },
}

local MetricsService = {}

local function fieldsOf(values: { string }?): { [string]: any }?
	if not values or #values == 0 then
		return nil
	end
	local fields: { [string]: any } = {}
	for index, value in values do
		local key = FIELD_KEYS[index]
		if key then
			fields[key] = value
		end
	end
	return fields
end

local function describe(values: { string }?): string
	return if values and #values > 0 then ` [{table.concat(values, ", ")}]` else ""
end

local function zoneOfGrade(grade: number?): string
	if not grade or grade < 1 or grade > ZoneConfig.POST_COUNT then
		return "Unknown"
	end
	return (ZoneConfig.zoneOfPost(grade))
end

-- An alien's fields for an event: its tier and its guardian's zone.
local function alienFields(alienId: string): { string }
	local alien = AlienConfig.ALIENS[alienId]
	return { if alien then `Tier - {alien.tier}` else "Tier - Unknown", zoneOfGrade(alien and alien.grade) }
end

local function zoneAt(position: Vector3): string
	local distance = (position - StationConfig.PLATFORM_CENTER).Magnitude
	return ZoneConfig.zoneAtDistance(distance) or "NearStation"
end

function MetricsService.new(dependencies: Dependencies): MetricsService
	local pending: { [Player]: Pending } = {}
	-- The theft in progress per player: its funnel session id.
	local thefts: { [Player]: string } = {}
	-- Last known coin balance (the profile may be gone when a leaving player is flushed).
	local coinBalance: { [Player]: BigNum.BigNum } = {}

	local function pendingOf(player: Player): Pending
		local entry = pending[player]
		if not entry then
			entry = { economy = {}, counts = {} }
			pending[player] = entry
		end
		return entry
	end

	local function balanceOf(player: Player, currency: Currency): number
		if currency == SPEED then
			return BigNum.toNumber(dependencies.getSpeed(player))
		end
		local data = dependencies.getData(player)
		local coins = if data then data.coins else coinBalance[player]
		return if coins then BigNum.toNumber(coins) else 0
	end

	-- Sending: AnalyticsService on live servers, the Output in Studio.

	local function sendEconomy(player: Player, currency: Currency, flow: Flow, sku: string, amount: BigNum.BigNum)
		local value = math.abs(BigNum.toNumber(amount))
		if value <= 0 then
			return
		end
		local balance = balanceOf(player, currency)
		local transaction = if sku == "Offline"
			then Enum.AnalyticsEconomyTransactionType.TimedReward.Name
			elseif flow == "Sink" or sku == "Sell" then Enum.AnalyticsEconomyTransactionType.Shop.Name
			else Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		if IS_STUDIO then
			print(`[Metrics] {player.Name} economy {flow} {currency} {sku}: {value} (balance {balance})`)
			return
		end
		local flowType = if flow == "Source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flowType, currency, value, balance, transaction, sku)
	end

	local function sendCount(player: Player, eventName: string, count: number, values: { string }?)
		if IS_STUDIO then
			print(`[Metrics] {player.Name} {eventName} x{count}{describe(values)}`)
			return
		end
		AnalyticsService:LogCustomEvent(player, eventName, count, fieldsOf(values))
	end

	local function sendOnboarding(player: Player, step: Onboarding.Step)
		if IS_STUDIO then
			print(`[Metrics] {player.Name} onboarding {step.number} {step.name}`)
			return
		end
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step.number, step.name)
	end

	local function sendTheftStep(player: Player, session: string, stepName: string, values: { string })
		local step = THEFT_STEPS[stepName]
		if IS_STUDIO then
			print(`[Metrics] {player.Name} theft {step} {stepName}{describe(values)}`)
			return
		end
		AnalyticsService:LogFunnelStepEvent(player, THEFT_FUNNEL, session, step, stepName, fieldsOf(values))
	end

	local function sendProgression(player: Player, grade: number)
		local post = GuardianConfig.POSTS[grade]
		if IS_STUDIO then
			print(`[Metrics] {player.Name} progression {GUARDIAN_PATH} {grade} {post.id}`)
			return
		end
		AnalyticsService:LogProgressionCompleteEvent(player, GUARDIAN_PATH, grade, post.id)
	end

	-- Summing.

	local function add(player: Player, currency: Currency, flow: Flow, sku: string, amount: BigNum.BigNum)
		local entry = pendingOf(player)
		local key = `{currency}|{flow}|{sku}`
		entry.economy[key] = BigNum.add(entry.economy[key] or BigNum.ZERO, amount)
	end

	local function count(player: Player, eventName: string, fields: { string }?)
		local entry = pendingOf(player)
		local parts = { eventName }
		for _, value in fields or {} do
			table.insert(parts, value)
		end
		local key = table.concat(parts, "|")
		entry.counts[key] = (entry.counts[key] or 0) + 1
	end

	local function flush(player: Player)
		local entry = pending[player]
		if not entry then
			return
		end
		pending[player] = nil
		for key, amount in entry.economy do
			local currency, flow, sku = string.match(key, "^(%w+)|(%w+)|(.+)$")
			if currency and flow and sku then
				sendEconomy(player, currency :: Currency, flow :: Flow, sku, amount)
			end
		end
		for key, total in entry.counts do
			local parts = string.split(key, "|")
			local eventName = table.remove(parts, 1) :: string
			sendCount(player, eventName, total, parts)
		end
	end

	-- The new player's funnel: each step once per account, remembered in the profile.
	local function reach(player: Player, stepName: string)
		local data = dependencies.getData(player)
		local step = Onboarding.step(stepName)
		if not data or Onboarding.has(data.onboardingSteps, step) then
			return
		end
		local isNew = false
		dependencies.update(player, function(profile)
			local mask, fresh = Onboarding.mark(profile.onboardingSteps, step)
			profile.onboardingSteps = mask
			isNew = fresh
		end)
		if isNew then
			sendOnboarding(player, step)
		end
	end

	-- A delivery from a post further than ever before.
	local function progress(player: Player, grade: number)
		local data = dependencies.getData(player)
		if not data or grade <= data.bestPost then
			return
		end
		local isBest = false
		dependencies.update(player, function(profile)
			if grade > profile.bestPost then
				profile.bestPost = grade
				isBest = true
			end
		end)
		if isBest then
			sendProgression(player, grade)
		end
	end

	local function watchLeftStation()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true then
				reach(player, "LeftStation")
			end
		end
	end

	local function connect()
		dependencies.activated.connect(function(player)
			reach(player, "Joined")
		end)

		-- Economy.
		dependencies.incomePaid.connect(function(player, amount, balance)
			coinBalance[player] = balance
			add(player, COINS, "Source", "AlienIncome", amount)
		end)
		dependencies.coinsTraded.connect(function(player, trade, paid, balance)
			coinBalance[player] = balance
			if trade == "Sell" then
				sendEconomy(player, COINS, "Source", "Sell", paid)
			else
				sendEconomy(player, COINS, "Sink", trade, paid)
				reach(player, "FirstPurchase")
			end
		end)
		dependencies.offlineSettled.connect(function(player, reward)
			sendEconomy(player, COINS, "Source", "Offline", reward.coins)
			sendEconomy(player, SPEED, "Source", "Offline", reward.speed)
		end)
		dependencies.trained.connect(function(player, gain)
			add(player, SPEED, "Source", "Trainer", gain)
		end)

		-- The bay.
		dependencies.hatched.connect(function(player)
			reach(player, "HatchedAlien")
		end)
		dependencies.crossbred.connect(function(player, alienId)
			count(player, "Crossbreed", alienFields(alienId))
		end)

		-- Thefts: a funnel per egg taken, from the grab to the bay.
		dependencies.eggGrabbed.connect(function(player, egg, source)
			reach(player, "GrabbedEgg")
			local session = HttpService:GenerateGUID(false)
			thefts[player] = session
			sendTheftStep(player, session, "Grabbed", { source, zoneOfGrade(egg.grade), egg.variant })
		end)
		dependencies.eggReachedStation.connect(function(player, egg)
			local session = thefts[player]
			if session then
				sendTheftStep(player, session, "ReachedStation", { zoneOfGrade(egg.grade) })
			end
		end)
		dependencies.eggDelivered.connect(function(player, egg)
			local grade = egg.grade
			local session = thefts[player]
			thefts[player] = nil
			if session then
				sendTheftStep(player, session, "Delivered", { zoneOfGrade(grade) })
			end
			reach(player, "DeliveredEgg")
			if grade then
				for _, step in Onboarding.stealSteps(grade, ZoneConfig.postIndex("IceRings", 1)) do
					reach(player, step.name)
				end
				progress(player, grade)
			end
		end)
		dependencies.eggLost.connect(function(player, egg, reason)
			thefts[player] = nil
			local grade = egg.grade
			count(player, "EggLost", { reason, zoneOfGrade(grade) })
			if reason == "Guardian" then
				count(player, "GuardianCatch", { `Post - {grade or 0}` })
			end
		end)

		-- Dangers and fights.
		dependencies.suffocated.connect(function(player, position)
			count(player, "OxygenDeath", { zoneAt(position) })
		end)
		dependencies.abilityUsed.connect(function(player, kind, hit, droppedEgg)
			local result = if droppedEgg then "EggLoose" elseif hit then "Hit" else "Miss"
			count(player, "Ability", { kind, result })
		end)
	end

	local function start()
		connect()
		PlayerEvents.observe(function() end, function(player)
			flush(player)
			thefts[player] = nil
			coinBalance[player] = nil
		end)
		dependencies.scheduler.every(WATCH_SECONDS, watchLeftStation)
		dependencies.scheduler.every(FLUSH_SECONDS, function()
			for player in pending do
				flush(player)
			end
		end)
	end

	return {
		name = "MetricsService",
		start = start,
		earned = function(player: Player, currency: Currency, sku: string, amount: BigNum.BigNum)
			add(player, currency, "Source", sku, amount)
		end,
		count = count,
		found = function(player: Player, alienId: string)
			count(player, "AlienFound", alienFields(alienId))
		end,
		serverEvent = function(eventId: string)
			for _, player in Players:GetPlayers() do
				count(player, "EventSeen", { eventId })
			end
		end,
		tutorialStep = function(player: Player, reached: number)
			local step = reached + 1
			local stepName = TUTORIAL_STEPS[step]
			if not stepName then
				return
			end
			if IS_STUDIO then
				print(`[Metrics] {player.Name} tutorial {step} {stepName}`)
				return
			end
			local session = `{TUTORIAL_FUNNEL}-{player.UserId}`
			AnalyticsService:LogFunnelStepEvent(player, TUTORIAL_FUNNEL, session, step, stepName)
		end,
	}
end

return table.freeze(MetricsService)
