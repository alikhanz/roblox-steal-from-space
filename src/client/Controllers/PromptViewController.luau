--!strict
-- Draws every custom-style ProximityPrompt (pick up an alien, open the shop) in the same look
-- as the egg prompt: a key badge, a hold bar and the action's words. The prompt itself stays
-- an engine prompt; this only replaces its picture. Touch screens press the badge.

local LocalizationService = game:GetService("LocalizationService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GrabPrompt = require(script.Parent.Parent.UI.GrabPrompt)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local TOUCH_BADGE = "✋"

export type PromptViewController = {
	name: string,
	start: () -> (),
}

type View = {
	unmount: () -> (),
	connections: { RBXScriptConnection },
	heldAt: number?,
	progress: Vide.Source<number>,
	prompt: ProximityPrompt,
}

local PromptViewController = {}

function PromptViewController.new(): PromptViewController
	local views: { [ProximityPrompt]: View } = {}
	local inputMode = source(UserInputService.PreferredInput)
	local locale: Text.Locale = "en"

	local function badgeFor(prompt: ProximityPrompt): string
		local mode = inputMode()
		if mode == Enum.PreferredInput.Touch then
			return TOUCH_BADGE
		elseif mode == Enum.PreferredInput.Gamepad then
			return prompt.GamepadKeyCode.Name
		end
		return prompt.KeyboardKeyCode.Name
	end

	local function hide(prompt: ProximityPrompt)
		local view = views[prompt]
		if not view then
			return
		end
		views[prompt] = nil
		for _, connection in view.connections do
			connection:Disconnect()
		end
		view.unmount()
	end

	local function show(prompt: ProximityPrompt)
		local adornee = prompt.Parent
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom or views[prompt] then
			return
		end
		if not adornee or not adornee:IsA("BasePart") then
			return
		end
		local progress = source(0)
		local view: View
		local unmount = Vide.mount(function()
			return GrabPrompt({
				target = function()
					return adornee
				end,
				progress = progress,
				badgeText = function()
					return badgeFor(prompt)
				end,
				hint = function()
					local _ = inputMode()
					return if prompt.ActionText ~= "" then prompt.ActionText else Text.get(locale, "egg.grab.hint")
				end,
				onBadge = function(badge)
					badge.MouseButton1Down:Connect(function()
						prompt:InputHoldBegin()
					end)
					badge.MouseButton1Up:Connect(function()
						prompt:InputHoldEnd()
					end)
				end,
			})
		end, adornee)
		view = {
			unmount = unmount,
			progress = progress,
			prompt = prompt,
			heldAt = nil :: number?,
			connections = {
				prompt.PromptButtonHoldBegan:Connect(function()
					view.heldAt = os.clock()
				end),
				prompt.PromptButtonHoldEnded:Connect(function()
					view.heldAt = nil
					progress(0)
				end),
			},
		}
		views[prompt] = view
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			inputMode(UserInputService.PreferredInput)
		end)
		ProximityPromptService.PromptShown:Connect(show)
		ProximityPromptService.PromptHidden:Connect(hide)
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			for _, view in views do
				if view.heldAt then
					local hold = math.max(view.prompt.HoldDuration, 1e-3)
					view.progress(math.clamp((now - view.heldAt) / hold, 0, 1))
				end
			end
		end)
	end

	return {
		name = "PromptViewController",
		start = start,
	}
end

return table.freeze(PromptViewController)
