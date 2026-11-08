--!strict
-- The prompt over the egg the grab button is for (docs/design/screens/grab-button.md): it marks
-- the egg the button would grab, and its bar fills with the grab's progress. On a touch screen its
-- badge is pressed like the button (the same grab input). The egg and the progress come from
-- GrabState, so the prompt, the button and the grab always agree.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GrabPrompt = require(script.Parent.Parent.UI.GrabPrompt)
local GrabState = require(script.Parent.Parent.State.GrabState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local TouchBindings = require(script.Parent.Parent.Input.TouchBindings)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- Badge text per input device. The touch badge is pressed itself, so it shows a hand.
local KEYBOARD_BADGE = "E"
local GAMEPAD_BADGE = "X"
local TOUCH_BADGE = "✋"

export type Dependencies = {
	grab: GrabState.GrabState,
}

export type GrabPromptController = {
	name: string,
	start: () -> (),
}

local GrabPromptController = {}

function GrabPromptController.new(dependencies: Dependencies): GrabPromptController
	local grab = dependencies.grab
	local inputMode = source(UserInputService.PreferredInput)

	local function start()
		local player = Players.LocalPlayer
		local locale = Text.localeOf(Players.LocalPlayer)
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[GrabPromptController] PlayerGui did not appear")

		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			inputMode(UserInputService.PreferredInput)
		end)

		Vide.mount(function()
			return GrabPrompt({
				target = function(): BasePart?
					local target = grab.target()
					return if target then target.part else nil
				end,
				progress = grab.progress,
				badgeText = function()
					local mode = inputMode()
					return if mode == Enum.PreferredInput.Touch
						then TOUCH_BADGE
						elseif mode == Enum.PreferredInput.Gamepad then GAMEPAD_BADGE
						else KEYBOARD_BADGE
				end,
				-- Locked on, the bar says it all.
				hint = function()
					if grab.engaged() then
						return ""
					end
					return if inputMode() == Enum.PreferredInput.Touch
						then Text.get(locale, "egg.grabTouch.hint")
						else Text.get(locale, "egg.grab.hint")
				end,
				onBadge = function(badge)
					task.spawn(TouchBindings.bind, player, FlightInputs.GRAB, badge)
				end,
			})
		end, playerGui)
	end

	return {
		name = "GrabPromptController",
		start = start,
	}
end

return table.freeze(GrabPromptController)
