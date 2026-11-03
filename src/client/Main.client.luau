--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimController = require(script.Parent.Controllers.AimController)
local EggEffectsController = require(script.Parent.Controllers.EggEffectsController)
local GrabPromptController = require(script.Parent.Controllers.GrabPromptController)
local GuardianViewController = require(script.Parent.Controllers.GuardianViewController)
local HitEffectsController = require(script.Parent.Controllers.HitEffectsController)
local HudController = require(script.Parent.Controllers.HudController)
local JetpackEffectsController = require(script.Parent.Controllers.JetpackEffectsController)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)

Lifecycle.run({
	AimController.new(),
	HudController.new(),
	GrabPromptController.new(),
	GuardianViewController.new(),
	EggEffectsController.new(),
	HitEffectsController.new(),
	JetpackEffectsController.new(),
	{
		-- Client-side prediction: the same simulation the server runs.
		name = "SpacePrediction",
		start = SpaceSimulation.start,
	},
}, function(callback)
	task.spawn(callback)
end)
