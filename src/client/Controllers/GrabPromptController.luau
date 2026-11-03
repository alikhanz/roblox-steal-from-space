--!strict
-- Shows the grab prompt over the egg the player can grab right now, with the grab progress.
-- Uses the same target search as the simulation, so the prompt and the grab always agree.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggTargets = require(ReplicatedStorage.Shared.Simulation.EggTargets)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GrabPrompt = require(script.Parent.Parent.UI.GrabPrompt)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local TouchBindings = require(script.Parent.Parent.Input.TouchBindings)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- Badge text per input device. The touch badge is pressed itself, so it shows a hand.
local KEYBOARD_BADGE = "E"
local GAMEPAD_BADGE = "X"
local TOUCH_BADGE = "✋"

export type GrabPromptController = {
	name: string,
	start: () -> (),
}

local GrabPromptController = {}

function GrabPromptController.new(): GrabPromptController
	local target = source(nil :: BasePart?)
	local progress = source(0)
	local inputMode = source(UserInputService.PreferredInput)

	local function update()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local canGrab = character ~= nil
			and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
			and character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE) == nil
		if not canGrab or not root or not root:IsA("BasePart") then
			target(nil)
			progress(0)
			return
		end
		local found = EggTargets.nearest(root.Position)
		target(if found then found.part else nil)
		local value = (character :: Model):GetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE)
		progress(if found and type(value) == "number" then value else 0)
	end

	local function start()
		local player = Players.LocalPlayer
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[GrabPromptController] PlayerGui did not appear")

		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			inputMode(UserInputService.PreferredInput)
		end)

		Vide.mount(function()
			return GrabPrompt({
				target = target,
				progress = progress,
				badgeText = function()
					local mode = inputMode()
					return if mode == Enum.PreferredInput.Touch
						then TOUCH_BADGE
						elseif mode == Enum.PreferredInput.Gamepad then GAMEPAD_BADGE
						else KEYBOARD_BADGE
				end,
				hint = function()
					return if inputMode() == Enum.PreferredInput.Touch
						then Text.get(locale, "egg.grabTouch.hint")
						else Text.get(locale, "egg.grab.hint")
				end,
				onBadge = function(badge)
					task.spawn(TouchBindings.bind, player, FlightInputs.GRAB, badge)
				end,
			})
		end, playerGui)

		RunService.RenderStepped:Connect(update)
	end

	return {
		name = "GrabPromptController",
		start = start,
	}
end

return table.freeze(GrabPromptController)
