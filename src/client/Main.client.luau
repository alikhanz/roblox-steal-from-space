--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityState = require(script.Parent.State.AbilityState)
local AimController = require(script.Parent.Controllers.AimController)
local AlarmSoundController = require(script.Parent.Controllers.AlarmSoundController)
local AlienMotionController = require(script.Parent.Controllers.AlienMotionController)
local AutoLocalizeGuard = require(script.Parent.Controllers.AutoLocalizeGuard)
local BayViewController = require(script.Parent.Controllers.BayViewController)
local BayWindowController = require(script.Parent.Controllers.BayWindowController)
local BenchController = require(script.Parent.Controllers.BenchController)
local CoinBoardController = require(script.Parent.Controllers.CoinBoardController)
local CommunityController = require(script.Parent.Controllers.CommunityController)
local ControlsController = require(script.Parent.Controllers.ControlsController)
local DomeFlightHintController = require(script.Parent.Controllers.DomeFlightHintController)
local EggBeaconController = require(script.Parent.Controllers.EggBeaconController)
local EggEffectsController = require(script.Parent.Controllers.EggEffectsController)
local EggPurchaseController = require(script.Parent.Controllers.EggPurchaseController)
local EggSoundController = require(script.Parent.Controllers.EggSoundController)
local EventController = require(script.Parent.Controllers.EventController)
local FeedbackController = require(script.Parent.Controllers.FeedbackController)
local FlightSoundController = require(script.Parent.Controllers.FlightSoundController)
local GrabPromptController = require(script.Parent.Controllers.GrabPromptController)
local GrabState = require(script.Parent.State.GrabState)
local GuardianViewController = require(script.Parent.Controllers.GuardianViewController)
local HitEffectsController = require(script.Parent.Controllers.HitEffectsController)
local HomeBeaconController = require(script.Parent.Controllers.HomeBeaconController)
local HudController = require(script.Parent.Controllers.HudController)
local IndexController = require(script.Parent.Controllers.IndexController)
local JetpackEffectsController = require(script.Parent.Controllers.JetpackEffectsController)
local JetpackLoadController = require(script.Parent.Controllers.JetpackLoadController)
local KioskController = require(script.Parent.Controllers.KioskController)
local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)
local LoginGiftController = require(script.Parent.Controllers.LoginGiftController)
local MenuState = require(script.Parent.State.MenuState)
local NewbieViewController = require(script.Parent.Controllers.NewbieViewController)
local PlaceGlideController = require(script.Parent.Controllers.PlaceGlideController)
local ProfileState = require(script.Parent.State.ProfileState)
local PromptViewController = require(script.Parent.Controllers.PromptViewController)
local PurchaseState = require(script.Parent.State.PurchaseState)
local PvpEffectsController = require(script.Parent.Controllers.PvpEffectsController)
local PvpViewController = require(script.Parent.Controllers.PvpViewController)
local QuestController = require(script.Parent.Controllers.QuestController)
local SerpentController = require(script.Parent.Controllers.SerpentController)
local ShopController = require(script.Parent.Controllers.ShopController)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)
local SpeedState = require(script.Parent.State.SpeedState)
local StationBorderController = require(script.Parent.Controllers.StationBorderController)
local StoreController = require(script.Parent.Controllers.StoreController)
local ToastState = require(script.Parent.State.ToastState)
local TouchJumpController = require(script.Parent.Controllers.TouchJumpController)
local TrainingViewController = require(script.Parent.Controllers.TrainingViewController)
local TutorialController = require(script.Parent.Controllers.TutorialController)
local UiSoundController = require(script.Parent.Controllers.UiSoundController)
local WindowState = require(script.Parent.State.WindowState)
local ZoneTintController = require(script.Parent.Controllers.ZoneTintController)

local profileState = ProfileState.new()
local toastState = ToastState.new()
local abilityState = AbilityState.new(profileState)
local speedState = SpeedState.new()
-- The egg the grab button offers, the grab's lock and progress (button, egg prompt, tutorial).
local grabState = GrabState.new()
-- One window open at a time: opening one closes the other.
local windowState = WindowState.new()
-- The windows' tiles in the HUD menu row and their keys.
local menuState = MenuState.new()
local purchaseState = PurchaseState.new()
local bayWindowController = BayWindowController.new({
	profile = profileState,
	purchases = purchaseState,
	toasts = toastState,
	windows = windowState,
	menu = menuState,
})
local storeController = StoreController.new({
	profile = profileState,
	purchases = purchaseState,
	toasts = toastState,
	windows = windowState,
	menu = menuState,
})
local eventController = EventController.new()
local tutorialController = TutorialController.new({ speed = speedState.speed, grab = grabState })

Lifecycle.run({
	-- First: every GUI made after it keeps Roblox's auto-translation off (decision 071).
	AutoLocalizeGuard.new(),
	-- Before anything that preloads: the player's own jetpack is asked for first (LoadConfig).
	JetpackLoadController.new(),
	profileState,
	purchaseState,
	abilityState,
	speedState,
	grabState,
	menuState,
	AimController.new(),
	HudController.new({
		coins = profileState.coins,
		toast = toastState.push,
		abilities = abilityState,
		speed = speedState.speed,
		loaded = profileState.loaded,
		menu = menuState,
		tutorialLine = tutorialController.line,
		tutorialStep = tutorialController.step,
		tutorialIcon = tutorialController.icon,
		openStore = if purchaseState.available
			then function()
				storeController.open("Goal")
			end
			else nil,
		grab = grabState,
	}),
	GrabPromptController.new({ grab = grabState }),
	PromptViewController.new(),
	EggPurchaseController.new({ purchases = purchaseState }),
	GuardianViewController.new({ speed = speedState.speed }),
	BayViewController.new({ profile = profileState }),
	AlienMotionController.new(),
	PlaceGlideController.new(),
	FeedbackController.new({ profile = profileState, purchases = purchaseState }),
	AlarmSoundController.new(),
	EggSoundController.new({ profile = profileState }),
	FlightSoundController.new({ profile = profileState }),
	UiSoundController.new({ windows = windowState, toasts = toastState }),
	BenchController.new(),
	bayWindowController,
	TrainingViewController.new({ profile = profileState }),
	ShopController.new({
		profile = profileState,
		windows = windowState,
		toasts = toastState,
		speed = speedState.speed,
	}),
	storeController,
	CoinBoardController.new(),
	QuestController.new({ profile = profileState, toasts = toastState, windows = windowState, menu = menuState }),
	LoginGiftController.new({
		profile = profileState,
		toasts = toastState,
		welcomeOpen = bayWindowController.welcomeOpen,
		windows = windowState,
		menu = menuState,
	}),
	IndexController.new({ profile = profileState, toasts = toastState, windows = windowState, menu = menuState }),
	CommunityController.new({
		profile = profileState,
		toasts = toastState,
		windows = windowState,
		menu = menuState,
		tutorialDone = tutorialController.done,
		tutorialFinished = tutorialController.finished,
	}),
	KioskController.new({ menu = menuState, windows = windowState }),
	ControlsController.new({ windows = windowState, menu = menuState, tutorialStep = tutorialController.step }),
	PvpViewController.new({ profile = profileState, toasts = toastState }),
	PvpEffectsController.new({ abilities = abilityState }),
	NewbieViewController.new(),
	HomeBeaconController.new({ tutorialPointsHome = tutorialController.pointsHome }),
	DomeFlightHintController.new({ toast = toastState.push, tutorialDone = tutorialController.isDone }),
	TouchJumpController.new(),
	tutorialController,
	StationBorderController.new(),
	ZoneTintController.new(),
	eventController,
	SerpentController.new({ events = eventController }),
	EggEffectsController.new(),
	EggBeaconController.new(),
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
