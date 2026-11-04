--!strict
-- Server entry point: creates every service, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayService = require(script.Parent.Services.BayService)
local CarryService = require(script.Parent.Services.CarryService)
local DataService = require(script.Parent.Services.DataService)
local DevService = require(script.Parent.Services.DevService)
local EconomyService = require(script.Parent.Services.EconomyService)
local GuardianService = require(script.Parent.Services.GuardianService)
local JetpackService = require(script.Parent.Services.JetpackService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local MetricsService = require(script.Parent.Services.MetricsService)
local NestService = require(script.Parent.Services.NestService)
local NetService = require(script.Parent.Services.NetService)
local OfflineService = require(script.Parent.Services.OfflineService)
local PvpService = require(script.Parent.Services.PvpService)
local QuestService = require(script.Parent.Services.QuestService)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local SpaceService = require(script.Parent.Services.SpaceService)
local SpeedService = require(script.Parent.Services.SpeedService)
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
questDependencies.getNestGrade = nestService.getGrade
questDependencies.publishSpeed = speedService.publish
questDependencies.eggDelivered = carryService.delivered
questDependencies.hatched = bayService.hatched
questDependencies.trained = trainingService.trained
questDependencies.crossbred = economyService.crossbred
questDependencies.abilityUsed = pvpService.abilityUsed

local guardianService = GuardianService.new({
	getNestSites = worldService.getNestSites,
	getNestGrade = nestService.getGrade,
	findCarrier = carryService.findCarrier,
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
	getNestGrade = nestService.getGrade,
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
questService.rewarded.connect(function(player, coins, _trained, shown)
	metricsService.earned(player, "Coins", "Quest", coins)
	metricsService.earned(player, "Speed", "Quest", shown)
end)
questService.completed.connect(function(player, kind)
	metricsService.count(player, "QuestDone", { kind })
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
})

-- Order matters for start: the world is built before nests, bays, guardians and players use it.
Lifecycle.run({
	dataService,
	worldService,
	nestService,
	speedService,
	jetpackService,
	spaceService,
	carryService,
	guardianService,
	bayService,
	economyService,
	netService,
	trainingService,
	pvpService,
	questService,
	leaderboardService,
	-- Before the offline settlement and the first activations, so it hears about them.
	metricsService,
	-- After the net service, so the snapshot goes out before the settlement's deltas.
	offlineService,
	devService,
}, function(callback)
	task.spawn(callback)
end)
