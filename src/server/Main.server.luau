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
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local NestService = require(script.Parent.Services.NestService)
local NetService = require(script.Parent.Services.NetService)
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
-- The net service needs the training payouts and the trainer needs the net service's notices,
-- so the trainer's own dependencies are bound after both exist.
local trainingDependencies = {} :: TrainingService.Dependencies
local trainingService = TrainingService.new(trainingDependencies)
local netService = NetService.new({
	activated = profile.activated,
	getData = profile.getData,
	economy = economyService,
	bayChanged = bayService.changed,
	coinsChanged = bayService.coinsChanged,
	offlineSettled = bayService.offlineSettled,
	hatched = bayService.hatched,
	trained = trainingService.trained,
})
trainingDependencies.getData = profile.getData
trainingDependencies.update = profile.update
trainingDependencies.scheduler = scheduler
trainingDependencies.bayAssigned = bayService.assigned
trainingDependencies.getBayOrigin = bayService.getOrigin
trainingDependencies.publishSpeed = speedService.publish
trainingDependencies.upgradeTrainer = economyService.upgradeTrainer
trainingDependencies.trainerUpgraded = economyService.trainerUpgraded
trainingDependencies.notify = netService.notify
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
	getNestEggCFrame = nestService.getEggCFrame,
	getNestGrade = nestService.getGrade,
	deliverEgg = bayService.addEgg,
})

local guardianService = GuardianService.new({
	getNestSites = worldService.getNestSites,
	getNestGrade = nestService.getGrade,
	findCarrier = carryService.findCarrier,
	getCarried = carryService.getCarried,
	dropEgg = carryService.dropEgg,
	getSpeed = speedService.getSpeed,
	scheduler = scheduler,
})

-- Studio-only playtest commands; inert in live servers.
local devService = DevService.new({
	spawnLooseEgg = carryService.spawnLooseEgg,
	setSpeed = speedService.setSpeed,
	addAlien = bayService.addAlien,
	addEgg = bayService.addEgg,
	hastenHatching = bayService.hastenHatching,
	settleOffline = bayService.settleOffline,
	getData = dataService.getData,
	update = dataService.update,
	refresh = bayService.refresh,
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
	devService,
}, function(callback)
	task.spawn(callback)
end)
