--!strict
-- What the attacker sees of their own abilities: a toast when an attack lands or knocks an egg
-- loose. A miss says nothing: the attack visibly went nowhere. The victim's side is the hit
-- flash in the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
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
		local locale = Text.localeOf(Players.LocalPlayer)
		local KEYS: { [string]: { egg: Text.Key, hit: Text.Key } } = {
			Strike = { egg = "pvp.strikeEgg.toast", hit = "pvp.strikeHit.toast" },
			-- A harpoon on a creature (the star serpent) may hit without an egg coming loose.
			Harpoon = { egg = "pvp.harpoonEgg.toast", hit = "pvp.harpoonHit.toast" },
			Bomb = { egg = "pvp.bombEgg.toast", hit = "pvp.bombHit.toast" },
		}
		dependencies.profile.abilityResult.connect(function(kind, hit, droppedEgg)
			local keys = KEYS[kind]
			if not keys then
				return
			end
			if droppedEgg then
				dependencies.toasts.push(Text.get(locale, keys.egg), "Good")
			elseif hit then
				dependencies.toasts.push(Text.get(locale, keys.hit), "Good")
			end
		end)
	end

	return {
		name = "PvpViewController",
		start = start,
	}
end

return table.freeze(PvpViewController)
