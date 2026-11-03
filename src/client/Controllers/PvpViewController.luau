--!strict
-- What the attacker sees of their own abilities: a toast when a strike lands, knocks an egg
-- loose or whiffs. The victim's side is the hit flash in the HUD.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
}

export type PvpViewController = {
	name: string,
	start: () -> (),
}

local PvpViewController = {}

function PvpViewController.new(dependencies: Dependencies): PvpViewController
	local function start()
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		dependencies.profile.abilityResult.connect(function(kind, hit, droppedEgg)
			if kind ~= "Strike" then
				return
			end
			if droppedEgg then
				dependencies.toasts.push(Text.get(locale, "pvp.strikeEgg.toast"), Theme.TOAST_GOOD)
			elseif hit then
				dependencies.toasts.push(Text.get(locale, "pvp.strikeHit.toast"), Theme.TOAST_GOOD)
			else
				dependencies.toasts.push(Text.get(locale, "pvp.strikeMiss.toast"), Theme.TOAST_BAD)
			end
		end)
	end

	return {
		name = "PvpViewController",
		start = start,
	}
end

return table.freeze(PvpViewController)
