--!strict
-- The interface's own sounds (docs/design/SOUND.md): a soft swish as a window opens or closes,
-- a chime for good news in a toast and a low "uh-uh" for a refusal. Toasts about something
-- that has its own sound (an egg, a hatch, a reward) stay quiet. Also loads every sound ahead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundPlayer = require(script.Parent.Parent.Audio.SoundPlayer)
local ToastState = require(script.Parent.Parent.State.ToastState)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local TOAST_SOUNDS: { [Toasts.Kind]: SoundPlayer.Name } = {
	Good = "Toast",
	Bad = "Denied",
}

export type Dependencies = {
	windows: WindowState.WindowState,
	toasts: ToastState.ToastState,
}

export type UiSoundController = {
	name: string,
	start: () -> (),
}

local UiSoundController = {}

function UiSoundController.new(dependencies: Dependencies): UiSoundController
	local function start()
		task.spawn(SoundPlayer.preload)

		local openWindow: string? = nil
		local lastToast = 0
		Vide.root(function()
			Vide.effect(function()
				local current = dependencies.windows.current()
				local before = openWindow
				openWindow = current
				if current and current ~= before then
					SoundPlayer.play("WindowOpen")
				elseif before and not current then
					SoundPlayer.play("WindowClose")
				end
			end)
			Vide.effect(function()
				for _, toast in dependencies.toasts.toasts() do
					if toast.id > lastToast then
						lastToast = toast.id
						local sound = TOAST_SOUNDS[toast.kind]
						if sound then
							SoundPlayer.play(sound)
						end
					end
				end
			end)
		end)
	end

	return {
		name = "UiSoundController",
		start = start,
	}
end

return table.freeze(UiSoundController)
