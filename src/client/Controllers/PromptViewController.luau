--!strict
-- Draws every custom-style ProximityPrompt (pick up an alien, hatch an egg, open the shop) as a
-- neon pill (UI/GrabPrompt, docs/design/screens/buttons.md) in the colour of what it does: hatch
-- and the shop green, hatch for Robux teal, take blue. The prompt itself stays an engine prompt;
-- this only replaces its picture. Touch screens press the whole pill: a press goes through at
-- once, and lifting the finger anywhere ends a hold (a finger slid off the pill used to leave the
-- prompt held).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local GrabPrompt = require(script.Parent.Parent.UI.GrabPrompt)
local Hatch = require(ReplicatedStorage.Shared.Domain.Hatch)
local Mount = require(script.Parent.Parent.UI.Mount)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
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

local ACTION = Theme.NEON.ACTION

-- What a prompt hangs on: a part, or a point on one (the station kiosks' counters); nil for
-- anything else.
local function adorneeOf(prompt: ProximityPrompt): (BasePart | Attachment)?
	local parent = prompt.Parent
	if parent and (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		return parent
	end
	return nil
end

local function positionOf(adornee: BasePart | Attachment): Vector3
	return if adornee:IsA("Attachment") then adornee.WorldPosition else (adornee :: BasePart).Position
end

-- What a prompt does, by the attributes its server gave it.
local function colorOf(prompt: ProximityPrompt): Color3
	if prompt:GetAttribute(BayConfig.READY_NOW_TIER_ATTRIBUTE) ~= nil then
		return ACTION.Robux
	end
	local action = prompt:GetAttribute(BayConfig.PROMPT_ACTION_ATTRIBUTE)
	if action == BayConfig.PROMPT_ACTION_OPEN_BAY or action == BayConfig.PROMPT_ACTION_PLACE_BEST then
		return ACTION.Move
	elseif action == BayConfig.PROMPT_ACTION_SHELF_FULL then
		-- An egg that cannot hatch: red, like the shelf's counter when full (decision 110).
		return ACTION.Sell
	end
	return ACTION.Main
end

-- The hatch odds of the egg a prompt hangs on, when it is an egg in the player's incubator, where
-- "Hatch for R$" is sold (docs/design/screens/egg-odds.md); nil for any other prompt.
local function oddsOf(prompt: ProximityPrompt, locale: Text.Locale): { GrabPrompt.Chance }?
	local part = prompt.Parent
	if not part or not CollectionService:HasTag(part, BayConfig.INCUBATOR_EGG_TAG) then
		return nil
	end
	local rarity = part:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE)
	local size = part:GetAttribute(EggConfig.LOOSE_EGG_SIZE_ATTRIBUTE)
	if not EggConfig.RARITIES[rarity :: any] or not EggConfig.SIZES[size :: any] then
		return nil
	end
	local luck = if part:GetAttribute(EggConfig.EGG_LUCKY_ATTRIBUTE) == true then 1 else nil
	local chances: { GrabPrompt.Chance } = {}
	for _, entry in Hatch.percents(EggConfig.hatchEntries(rarity :: any, size :: any, luck)) do
		table.insert(chances, {
			color = AlienLooks.TIERS[entry.id].color,
			text = Text.get(locale, "egg.oddsChance.hint", { chance = Hatch.percentText(entry.percent) }),
		})
	end
	return chances
end

-- A press on the pill: the prompt goes at once; a hold ends when that finger (or button) lifts,
-- wherever it is by then.
local function bindPress(prompt: ProximityPrompt, button: GuiButton)
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		prompt:InputHoldBegin()
		if prompt.HoldDuration <= 0 then
			task.defer(function()
				prompt:InputHoldEnd()
			end)
			return
		end
		local lifted: RBXScriptConnection
		lifted = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				lifted:Disconnect()
				prompt:InputHoldEnd()
			end
		end)
	end)
end

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
		local adornee = adorneeOf(prompt)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom or views[prompt] then
			return
		end
		-- Another player's bay prompt: only its owner can use it, so it is not drawn here.
		local owner = prompt:GetAttribute(BayConfig.PROMPT_OWNER_ATTRIBUTE)
		if owner ~= nil and owner ~= Players.LocalPlayer.UserId then
			return
		end
		if not adornee then
			return
		end
		local progress = source(0)
		-- Where the prompt hangs over its part: its own height if it sets one (an egg's, below the
		-- chips over the incubator), else the default.
		local ownHeight = prompt:GetAttribute(BayConfig.PROMPT_STUDS_ABOVE_ATTRIBUTE)
		local studsAbove = if type(ownHeight) == "number" then ownHeight else PROMPT_STUDS_ABOVE
		-- The words can change while the prompt is up (a price that arrives later).
		local actionText = source(prompt.ActionText)
		local view: View
		local unmount = Mount.instance(function()
			return GrabPrompt({
				target = function()
					return adornee
				end,
				progress = progress,
				studsAbove = studsAbove,
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
				color = function()
					return colorOf(prompt)
				end,
				onBadge = function(button)
					bindPress(prompt, button)
				end,
				odds = oddsOf(prompt, locale),
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
		locale = Text.localeOf(Players.LocalPlayer)
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
				local adornee = adorneeOf(prompt)
				local gone = not prompt.Enabled
				if adornee then
					if root and root:IsA("BasePart") then
						local reach = prompt.MaxActivationDistance + PROMPT_DISTANCE_SLACK
						gone = gone or (positionOf(adornee) - root.Position).Magnitude > reach
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
