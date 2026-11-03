--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimController = require(script.Parent.Controllers.AimController)
local BayViewController = require(script.Parent.Controllers.BayViewController)
local BayWindowController = require(script.Parent.Controllers.BayWindowController)
local EggEffectsController = require(script.Parent.Controllers.EggEffectsController)
local GrabPromptController = require(script.Parent.Controllers.GrabPromptController)
local GuardianViewController = require(script.Parent.Controllers.GuardianViewController)
local HitEffectsController = require(script.Parent.Controllers.HitEffectsController)
local HudController = require(script.Parent.Controllers.HudController)
local JetpackEffectsController = require(script.Parent.Controllers.JetpackEffectsController)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local ProfileState = require(script.Parent.State.ProfileState)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)

local profileState = ProfileState.new()

Lifecycle.run({
	profileState,
	AimController.new(),
	HudController.new({ coins = profileState.coins }),
	GrabPromptController.new(),
	GuardianViewController.new(),
	BayViewController.new(),
	BayWindowController.new({ profile = profileState }),
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
