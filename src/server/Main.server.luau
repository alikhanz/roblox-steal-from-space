--!strict
-- Server entry point: creates every service, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Services.DataService)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)

local dataService = DataService.new()

Lifecycle.run({ dataService }, function(callback)
	task.spawn(callback)
end)
