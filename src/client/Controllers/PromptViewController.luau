--!strict
-- Draws every custom-style ProximityPrompt (pick up an alien, hatch an egg, open the shop) in
-- the same look
-- as the egg prompt: a key badge, a hold bar and the action's words. The prompt itself stays
-- an engine prompt; this only replaces its picture. Touch screens press the badge.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local GrabPrompt = require(script.Parent.Parent.UI.GrabPrompt)
local Mount = require(script.Parent.Parent.UI.Mount)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local TOUCH_BADGE = "✋"
-- Studs past the prompt's reach where its picture still shows, so it does not blink at the edge.
local PROMPT_DISTANCE_SLACK = 2
-- The prompt sits on the thing itself: its sign (an alien's name and income) is above it.
local PROMPT_STUDS_ABOVE = 0

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
		-- Another player's bay prompt: only its owner can use it, so it is not drawn here.
		local owner = prompt:GetAttribute(BayConfig.PROMPT_OWNER_ATTRIBUTE)
		if owner ~= nil and owner ~= Players.LocalPlayer.UserId then
			return
		end
		if not adornee or not adornee:IsA("BasePart") then
			return
		end
		local progress = source(0)
		-- The words can change while the prompt is up (a price that arrives later).
		local actionText = source(prompt.ActionText)
		local view: View
		local unmount = Mount.instance(function()
			return GrabPrompt({
				target = function()
					return adornee
				end,
				progress = progress,
				studsAbove = PROMPT_STUDS_ABOVE,
				showBar = function()
					return prompt.HoldDuration > 0
				end,
				-- No billboard distance: it counts from the camera, which stands farther back than
				-- the reach, so the badge would vanish while the prompt still works. The picture
				-- goes away with the prompt instead (PromptHidden and the reach check below).
				badgeText = function()
					return badgeFor(prompt)
				end,
				hint = function()
					local _ = inputMode()
					local words = actionText()
					return if words ~= "" then words else Text.get(locale, "egg.grab.hint")
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
			-- Under PlayerGui, not the adornee: a BillboardGui in the world draws, but only one
			-- under PlayerGui receives taps, so on a phone the badge could not be pressed.
		end, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or adornee)
		view = {
			unmount = unmount,
			progress = progress,
			prompt = prompt,
			heldAt = nil :: number?,
			connections = {
				prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
					actionText(prompt.ActionText)
				end),
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
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			for prompt, view in views do
				-- The engine hides a prompt the player walked away from; should that signal be
				-- missed (a respawn, a teleport), the picture must not stay on the wall.
				local adornee = prompt.Parent
				local gone = not prompt.Enabled
				if adornee and adornee:IsA("BasePart") then
					if root and root:IsA("BasePart") then
						local reach = prompt.MaxActivationDistance + PROMPT_DISTANCE_SLACK
						gone = gone or (adornee.Position - root.Position).Magnitude > reach
					end
				else
					gone = true
				end
				if gone then
					hide(prompt)
				elseif view.heldAt then
					local hold = math.max(prompt.HoldDuration, 1e-3)
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
