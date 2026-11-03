--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityState = require(script.Parent.State.AbilityState)
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
local PromptViewController = require(script.Parent.Controllers.PromptViewController)
local PvpViewController = require(script.Parent.Controllers.PvpViewController)
local ShopController = require(script.Parent.Controllers.ShopController)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)
local ToastState = require(script.Parent.State.ToastState)
local TrainingViewController = require(script.Parent.Controllers.TrainingViewController)

local profileState = ProfileState.new()
local toastState = ToastState.new()
local abilityState = AbilityState.new(profileState)

Lifecycle.run({
	profileState,
	abilityState,
	AimController.new(),
	HudController.new({ coins = profileState.coins, toast = toastState.push, abilities = abilityState }),
	GrabPromptController.new(),
	PromptViewController.new(),
	GuardianViewController.new(),
	BayViewController.new({ profile = profileState }),
	BayWindowController.new({ profile = profileState, toasts = toastState }),
	TrainingViewController.new({ profile = profileState }),
	ShopController.new({ profile = profileState }),
	PvpViewController.new({ profile = profileState, toasts = toastState }),
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
