--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JetpackSimulation = require(ReplicatedStorage.Shared.Flight.JetpackSimulation)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)

Lifecycle.run({
	{
		-- Spike: client-side prediction of jetpack flight.
		name = "JetpackPrediction",
		start = JetpackSimulation.start,
	},
}, function(callback)
	task.spawn(callback)
end)
