--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityState = require(script.Parent.State.AbilityState)
local AimController = require(script.Parent.Controllers.AimController)
local BayViewController = require(script.Parent.Controllers.BayViewController)
local BayWindowController = require(script.Parent.Controllers.BayWindowController)
local CoinBoardController = require(script.Parent.Controllers.CoinBoardController)
local EggEffectsController = require(script.Parent.Controllers.EggEffectsController)
local EggPurchaseController = require(script.Parent.Controllers.EggPurchaseController)
local EventController = require(script.Parent.Controllers.EventController)
local GrabPromptController = require(script.Parent.Controllers.GrabPromptController)
local GuardianViewController = require(script.Parent.Controllers.GuardianViewController)
local HitEffectsController = require(script.Parent.Controllers.HitEffectsController)
local HudController = require(script.Parent.Controllers.HudController)
local IndexController = require(script.Parent.Controllers.IndexController)
local JetpackEffectsController = require(script.Parent.Controllers.JetpackEffectsController)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local LoginGiftController = require(script.Parent.Controllers.LoginGiftController)
local NewbieViewController = require(script.Parent.Controllers.NewbieViewController)
local ProfileState = require(script.Parent.State.ProfileState)
local PromptViewController = require(script.Parent.Controllers.PromptViewController)
local PurchaseState = require(script.Parent.State.PurchaseState)
local PvpViewController = require(script.Parent.Controllers.PvpViewController)
local QuestController = require(script.Parent.Controllers.QuestController)
local SerpentController = require(script.Parent.Controllers.SerpentController)
local ShopController = require(script.Parent.Controllers.ShopController)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)
local SpeedState = require(script.Parent.State.SpeedState)
local StationBeaconController = require(script.Parent.Controllers.StationBeaconController)
local StationBorderController = require(script.Parent.Controllers.StationBorderController)
local StoreController = require(script.Parent.Controllers.StoreController)
local ToastState = require(script.Parent.State.ToastState)
local TrainingViewController = require(script.Parent.Controllers.TrainingViewController)
local TutorialController = require(script.Parent.Controllers.TutorialController)
local WindowState = require(script.Parent.State.WindowState)

local profileState = ProfileState.new()
local toastState = ToastState.new()
local abilityState = AbilityState.new(profileState)
local speedState = SpeedState.new()
-- One window open at a time: opening one closes the other.
local windowState = WindowState.new()
local purchaseState = PurchaseState.new()
local bayWindowController = BayWindowController.new({
	profile = profileState,
	purchases = purchaseState,
	toasts = toastState,
	windows = windowState,
})
local storeController = StoreController.new({
	profile = profileState,
	purchases = purchaseState,
	toasts = toastState,
	windows = windowState,
})
local eventController = EventController.new()

Lifecycle.run({
	profileState,
	purchaseState,
	abilityState,
	speedState,
	AimController.new(),
	HudController.new({
		coins = profileState.coins,
		toast = toastState.push,
		abilities = abilityState,
		speed = speedState.speed,
		loaded = profileState.loaded,
		openStore = if purchaseState.available
			then function()
				storeController.open("Goal")
			end
			else nil,
	}),
	GrabPromptController.new(),
	PromptViewController.new(),
	EggPurchaseController.new({ purchases = purchaseState }),
	GuardianViewController.new({ speed = speedState.speed }),
	BayViewController.new({ profile = profileState }),
	bayWindowController,
	TrainingViewController.new({ profile = profileState }),
	ShopController.new({ profile = profileState, windows = windowState }),
	storeController,
	CoinBoardController.new(),
	QuestController.new({ profile = profileState, toasts = toastState, windows = windowState }),
	LoginGiftController.new({
		profile = profileState,
		toasts = toastState,
		welcomeOpen = bayWindowController.welcomeOpen,
		windows = windowState,
	}),
	IndexController.new({ profile = profileState, toasts = toastState, windows = windowState }),
	PvpViewController.new({ profile = profileState, toasts = toastState }),
	NewbieViewController.new(),
	StationBeaconController.new(),
	TutorialController.new(),
	StationBorderController.new(),
	eventController,
	SerpentController.new({ events = eventController }),
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
