--!strict
-- Server entry point: creates every service, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActivityService = require(script.Parent.Services.ActivityService)
local BayService = require(script.Parent.Services.BayService)
local CarryService = require(script.Parent.Services.CarryService)
local DataService = require(script.Parent.Services.DataService)
local DevService = require(script.Parent.Services.DevService)
local EconomyService = require(script.Parent.Services.EconomyService)
local EventService = require(script.Parent.Services.EventService)
local GuardianService = require(script.Parent.Services.GuardianService)
local IndexService = require(script.Parent.Services.IndexService)
local JetpackService = require(script.Parent.Services.JetpackService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local LoginGiftService = require(script.Parent.Services.LoginGiftService)
local MeteorService = require(script.Parent.Services.MeteorService)
local MetricsService = require(script.Parent.Services.MetricsService)
local NestService = require(script.Parent.Services.NestService)
local NetService = require(script.Parent.Services.NetService)
local OfflineService = require(script.Parent.Services.OfflineService)
local PvpService = require(script.Parent.Services.PvpService)
local QuestService = require(script.Parent.Services.QuestService)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local SpaceService = require(script.Parent.Services.SpaceService)
local SpeedService = require(script.Parent.Services.SpeedService)
local StormService = require(script.Parent.Services.StormService)
local TrainingService = require(script.Parent.Services.TrainingService)
local WorldService = require(script.Parent.Services.WorldService)

-- One Heartbeat drives every periodic server job (see CONVENTIONS, performance).
local scheduler = Scheduler.new()
RunService.Heartbeat:Connect(scheduler.step)

local dataService = DataService.new()
local worldService = WorldService.new()
local nestService = NestService.new({ getNestSites = worldService.getNestSites, scheduler = scheduler })
local profile = {
	activated = dataService.activated,
	getData = dataService.getData,
	update = dataService.update,
}
local speedService = SpeedService.new(profile)
local bayService = BayService.new({
	activated = profile.activated,
	getData = profile.getData,
	update = profile.update,
	scheduler = scheduler,
})
local economyService = EconomyService.new({
	getData = profile.getData,
	update = profile.update,
	refresh = bayService.refresh,
})
local offlineService = OfflineService.new({
	activated = profile.activated,
	getData = profile.getData,
	update = profile.update,
	scheduler = scheduler,
	getIncomePerSecond = bayService.getIncomePerSecond,
	publishSpeed = speedService.publish,
})
-- The net service forwards the trainer's payouts and the abilities' results, and both of those
-- services send notices through the net service, so their dependencies are bound after it exists.
local trainingDependencies = {} :: TrainingService.Dependencies
local trainingService = TrainingService.new(trainingDependencies)
local pvpDependencies = {} :: PvpService.Dependencies
local pvpService = PvpService.new(pvpDependencies)
local eventService = EventService.new({ scheduler = scheduler })
local activityService = ActivityService.new({ scheduler = scheduler })
local indexService = IndexService.new({
	getData = profile.getData,
	update = profile.update,
	getIncomePerSecond = bayService.getIncomePerSecond,
	hatched = bayService.hatched,
	crossbred = economyService.crossbred,
})
local loginGiftService = LoginGiftService.new({
	activated = profile.activated,
	getData = profile.getData,
	update = profile.update,
	scheduler = scheduler,
	getIncomePerSecond = bayService.getIncomePerSecond,
	publishSpeed = speedService.publish,
	refreshBay = bayService.refresh,
})
-- Quests hear from services made after the net service (carrying), so they are bound later too.
local questDependencies = {} :: QuestService.Dependencies
local questService = QuestService.new(questDependencies)
local netService = NetService.new({
	activated = profile.activated,
	getData = profile.getData,
	economy = economyService,
	bayChanged = bayService.changed,
	coinsChanged = bayService.coinsChanged,
	offlineSettled = offlineService.settled,
	hatched = bayService.hatched,
	trained = trainingService.trained,
	abilityUsed = pvpService.abilityUsed,
	quests = questService,
	loginGift = loginGiftService,
	index = indexService,
	markActive = activityService.touch,
})
trainingDependencies.getData = profile.getData
trainingDependencies.update = profile.update
trainingDependencies.scheduler = scheduler
trainingDependencies.bayAssigned = bayService.assigned
trainingDependencies.getBayOrigin = bayService.getOrigin
trainingDependencies.publishSpeed = speedService.publish
trainingDependencies.trainerUpgraded = economyService.trainerUpgraded
local jetpackService = JetpackService.new({
	activated = profile.activated,
	getData = profile.getData,
	jetpackUpgraded = economyService.jetpackUpgraded,
	publishSpeed = speedService.publish,
})
local spaceService = SpaceService.new({
	getSpawn = worldService.getSpawn,
	getJetpackLooks = jetpackService.getLooks,
})
local carryService = CarryService.new({
	takeNestEgg = nestService.takeEgg,
	returnNestEgg = nestService.returnEgg,
	nestEggDelivered = nestService.eggDelivered,
	getNestEggCFrame = nestService.getEggCFrame,
	getNestGrade = nestService.getGrade,
	deliverEgg = bayService.addEgg,
})

pvpDependencies.getData = profile.getData
pvpDependencies.getSpeed = speedService.getSpeed
pvpDependencies.isCarrying = function(player: Player): boolean
	return carryService.getCarried(player) ~= nil
end
pvpDependencies.dropEgg = carryService.dropEgg
pvpDependencies.notify = netService.notify
pvpDependencies.scheduler = scheduler

questDependencies.activated = profile.activated
questDependencies.getData = profile.getData
questDependencies.update = profile.update
questDependencies.scheduler = scheduler
questDependencies.getIncomePerSecond = bayService.getIncomePerSecond
questDependencies.publishSpeed = speedService.publish
questDependencies.eggDelivered = carryService.delivered
questDependencies.hatched = bayService.hatched
questDependencies.trained = trainingService.trained
questDependencies.crossbred = economyService.crossbred
questDependencies.abilityUsed = pvpService.abilityUsed

local stormService = StormService.new({
	eventChanged = eventService.changed,
	returnEgg = carryService.returnEgg,
	setHatchRate = bayService.setHatchRate,
	notify = netService.notify,
})

local meteorService = MeteorService.new({
	eventChanged = eventService.changed,
	placeOf = eventService.placeOf,
	setPlacer = eventService.setPlacer,
	showSpot = eventService.showSpot,
	hideSpot = eventService.hideSpot,
	getNestSites = nestService.getSites,
	buildCrater = worldService.buildCrater,
	addCrater = nestService.addCrater,
	retireCrater = nestService.retireCrater,
	activePlayers = activityService.activeCount,
})

local guardianService = GuardianService.new({
	getNestSites = worldService.getNestSites,
	getNestGrade = nestService.getGrade,
	nestAdded = nestService.added,
	nestRemoved = nestService.removed,
	findCarriers = carryService.findCarriers,
	findLooseEggs = carryService.findLooseEggs,
	getCarried = carryService.getCarried,
	dropEgg = carryService.dropEgg,
	getSpeed = speedService.getSpeed,
	scheduler = scheduler,
})

-- The coin board: the player list column and the board at the station.
local leaderboardService = LeaderboardService.new({
	getData = profile.getData,
	getCoinBoard = worldService.getCoinBoard,
	scheduler = scheduler,
})

-- Analytics: listens to what the other services report.
local metricsService = MetricsService.new({
	activated = profile.activated,
	getData = profile.getData,
	update = profile.update,
	getSpeed = speedService.getSpeed,
	scheduler = scheduler,
	incomePaid = bayService.incomePaid,
	coinsTraded = economyService.coinsTraded,
	offlineSettled = offlineService.settled,
	trained = trainingService.trained,
	hatched = bayService.hatched,
	crossbred = economyService.crossbred,
	eggGrabbed = carryService.grabbed,
	eggReachedStation = carryService.reachedStation,
	eggDelivered = carryService.delivered,
	eggLost = carryService.lost,
	suffocated = spaceService.suffocated,
	abilityUsed = pvpService.abilityUsed,
})
questService.rewarded.connect(function(player, paid)
	metricsService.earned(player, "Coins", "Quest", paid.coins)
	metricsService.earned(player, "Speed", "Quest", paid.speed)
end)
questService.completed.connect(function(player, kind)
	metricsService.count(player, "QuestDone", { kind })
end)
eventService.changed.connect(function(id, phase)
	if phase == "Active" then
		metricsService.serverEvent(id)
	end
end)
indexService.discovered.connect(function(player, alienId)
	metricsService.found(player, alienId)
end)
indexService.rewarded.connect(function(player, coins, what)
	metricsService.earned(player, "Coins", if what == "Set" then "IndexSet" else "IndexAlien", coins)
end)
loginGiftService.rewarded.connect(function(player, reward)
	metricsService.earned(player, "Coins", "LoginGift", reward.paid.coins)
	metricsService.earned(player, "Speed", "LoginGift", reward.paid.speed)
	metricsService.count(player, "LoginGift", { `Day {reward.day}` })
end)

-- Studio-only playtest commands; inert in live servers.
local devService = DevService.new({
	spawnLooseEgg = carryService.spawnLooseEgg,
	setSpeed = speedService.setSpeed,
	addAlien = bayService.addAlien,
	addEgg = bayService.addEgg,
	hastenHatching = bayService.hastenHatching,
	settleOffline = offlineService.settle,
	getData = dataService.getData,
	update = dataService.update,
	refresh = bayService.refresh,
	addDummy = pvpService.addDummy,
	getPvpUsage = pvpService.getUsage,
	completeQuests = questService.completeAll,
	newQuestDay = questService.newDay,
	shiftLoginDays = loginGiftService.shiftDays,
	discoverAlien = indexService.discover,
	activateEvent = eventService.activate,
	idleSeconds = activityService.idleSeconds,
	queueEvent = eventService.queue,
	stopEvent = eventService.stop,
})

-- Order matters for start: the world is built before nests, bays, guardians and players use it.
Lifecycle.run({
	dataService,
	worldService,
	eventService,
	activityService,
	nestService,
	speedService,
	jetpackService,
	spaceService,
	carryService,
	guardianService,
	stormService,
	meteorService,
	bayService,
	economyService,
	netService,
	trainingService,
	pvpService,
	questService,
	loginGiftService,
	indexService,
	leaderboardService,
	-- Before the offline settlement and the first activations, so it hears about them.
	metricsService,
	-- After the net service, so the snapshot goes out before the settlement's deltas.
	offlineService,
	devService,
}, function(callback)
	task.spawn(callback)
end)
