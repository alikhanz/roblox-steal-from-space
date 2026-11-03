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
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local NestService = require(script.Parent.Services.NestService)
local NetService = require(script.Parent.Services.NetService)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local SpaceService = require(script.Parent.Services.SpaceService)
local SpeedService = require(script.Parent.Services.SpeedService)
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
local netService = NetService.new({
	activated = profile.activated,
	getData = profile.getData,
	economy = economyService,
	bayChanged = bayService.changed,
	coinsChanged = bayService.coinsChanged,
	offlineSettled = bayService.offlineSettled,
	hatched = bayService.hatched,
})
local spaceService = SpaceService.new({ getSpawn = worldService.getSpawn })
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
	getData = dataService.getData,
})

-- Order matters for start: the world is built before nests, bays, guardians and players use it.
Lifecycle.run({
	dataService,
	worldService,
	nestService,
	speedService,
	spaceService,
	carryService,
	guardianService,
	bayService,
	economyService,
	netService,
	devService,
}, function(callback)
	task.spawn(callback)
end)
