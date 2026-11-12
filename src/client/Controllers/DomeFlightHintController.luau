--!strict
-- The double-jump hint (decision 096): a jetpack toast a few seconds after spawning, telling a
-- player who has finished the tutorial but never flown under a dome that a double jump starts the
-- jetpack. Once a session at most; never again once they have flown (DomeFlightService keeps that
-- in the profile and on the player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Toasts = require(script.Parent.Parent.UI.Toasts)

-- Seconds after spawning: time to look round the island first.
local DELAY_SECONDS = 4

export type Dependencies = {
	toast: Toasts.Push,
	-- The tutorial is over (TutorialController.isDone).
	tutorialDone: () -> boolean,
}

export type DomeFlightHintController = {
	name: string,
	start: () -> (),
}

local DomeFlightHintController = {}

function DomeFlightHintController.new(dependencies: Dependencies): DomeFlightHintController
	local player = Players.LocalPlayer
	local shown = false

	local function onCharacter(character: Model)
		task.delay(DELAY_SECONDS, function()
			if shown or player.Character ~= character or not dependencies.tutorialDone() then
				return
			end
			-- False, not nil: the profile is loaded and says they have not flown yet.
			if player:GetAttribute(FlightConfig.DOME_FLIGHT_LEARNED_ATTRIBUTE) ~= false then
				return
			end
			if character:GetAttribute(FlightConfig.JETPACK_ON_ATTRIBUTE) == true then
				return
			end
			shown = true
			dependencies.toast(Text.get(Text.localeOf(player), "jetpack.doubleJump.toast"), "Jetpack")
		end)
	end

	local function start()
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end

	return {
		name = "DomeFlightHintController",
		start = start,
	}
end

return table.freeze(DomeFlightHintController)
