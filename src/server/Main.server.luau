--!strict
-- Server entry point: creates every service, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Services.DataService)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local SpaceService = require(script.Parent.Services.SpaceService)
local WorldService = require(script.Parent.Services.WorldService)

local dataService = DataService.new()
local worldService = WorldService.new()
local spaceService = SpaceService.new({ getSpawn = worldService.getSpawn })

-- WorldService starts first so the spawn exists before players are set up.
Lifecycle.run({ dataService, worldService, spaceService }, function(callback)
	task.spawn(callback)
end)
