--!strict
-- Server entry point: creates every service, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Services.DataService)
local FlightService = require(script.Parent.Services.FlightService)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)

local dataService = DataService.new()
local flightService = FlightService.new()

Lifecycle.run({ dataService, flightService }, function(callback)
	task.spawn(callback)
end)
