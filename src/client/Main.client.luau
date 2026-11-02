--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimController = require(script.Parent.Controllers.AimController)
local HudController = require(script.Parent.Controllers.HudController)
local JetpackEffectsController = require(script.Parent.Controllers.JetpackEffectsController)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)

Lifecycle.run({
	AimController.new(),
	HudController.new(),
	JetpackEffectsController.new(),
	{
		-- Client-side prediction: the same simulation the server runs.
		name = "SpacePrediction",
		start = SpaceSimulation.start,
	},
}, function(callback)
	task.spawn(callback)
end)
