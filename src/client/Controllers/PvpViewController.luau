--!strict
-- What the attacker sees of their own abilities: a toast when an attack lands or knocks an egg
-- loose. A miss says nothing: the attack visibly went nowhere. The victim's side is the hit
-- flash in the HUD.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileState = require(script.Parent.Parent.State.ProfileState)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
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
		local KEYS: { [string]: { egg: Text.Key, hit: Text.Key } } = {
			Strike = { egg = "pvp.strikeEgg.toast", hit = "pvp.strikeHit.toast" },
			-- A harpoon on a creature (the star serpent) may hit without an egg coming loose.
			Harpoon = { egg = "pvp.harpoonEgg.toast", hit = "pvp.harpoonHit.toast" },
			Bomb = { egg = "pvp.bombEgg.toast", hit = "pvp.bombHit.toast" },
		}
		dependencies.profile.abilityResult.connect(function(kind, hit, droppedEgg)
			if kind == "Shield" then
				local seconds = PvpConfig.SHIELD.seconds
				local message = Text.get(locale, "pvp.shieldOn.toast", { seconds = seconds })
				dependencies.toasts.push(message, Theme.TOAST_GOOD)
				return
			end
			local keys = KEYS[kind]
			if not keys then
				return
			end
			if droppedEgg then
				dependencies.toasts.push(Text.get(locale, keys.egg), Theme.TOAST_GOOD)
			elseif hit then
				dependencies.toasts.push(Text.get(locale, keys.hit), Theme.TOAST_GOOD)
			end
		end)
	end

	return {
		name = "PvpViewController",
		start = start,
	}
end

return table.freeze(PvpViewController)
