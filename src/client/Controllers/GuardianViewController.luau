--!strict
-- The client side of guardians: the sign with the name and recommended speed over each one, and
-- eyes that light up with the guardian's state. Guardians stream in and out, so everything is
-- keyed by the model and torn down when it goes.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLabel = require(script.Parent.Parent.UI.GuardianLabel)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

local BODY_WAIT_TIMEOUT = 10
-- The strike: the body swells and snaps back.
local STRIKE_SCALE = 1.35
local STRIKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)

export type GuardianViewController = {
	name: string,
	start: () -> (),
}

type View = {
	unmount: () -> (),
	connections: { RBXScriptConnection },
}

local GuardianViewController = {}

local function recommendedText(model: Model): string
	local value = BigNum.fromSaved({
		mantissa = model:GetAttribute(GuardianConfig.RECOMMENDED_MANTISSA_ATTRIBUTE),
		exponent = model:GetAttribute(GuardianConfig.RECOMMENDED_EXPONENT_ATTRIBUTE),
	})
	return if value then BigNum.format(value) else "?"
end

local function paintEyes(model: Model)
	local state = model:GetAttribute(GuardianConfig.STATE_ATTRIBUTE)
	local color = GuardianLooks.EYE_COLORS[state :: any] or GuardianLooks.EYE_COLORS.Sleep
	for _, child in model:GetChildren() do
		if child.Name == GuardianConfig.EYE_NAME and child:IsA("BasePart") then
			child.Color = color
		end
	end
end

function GuardianViewController.new(): GuardianViewController
	local views: { [Instance]: View } = {}

	-- The model's parts may replicate after its tag; wait for the body before building the sign.
	local function watch(instance: Instance, locale: Text.Locale)
		local body = instance:WaitForChild(GuardianConfig.BODY_NAME, BODY_WAIT_TIMEOUT)
		if views[instance] or not instance:IsDescendantOf(workspace) then
			return
		end
		local postId = instance:GetAttribute(GuardianConfig.POST_ATTRIBUTE)
		local post = GuardianConfig.POSTS_BY_ID[postId :: GuardianConfig.PostId]
		if not instance:IsA("Model") or not body or not body:IsA("BasePart") or not post then
			warn(`[GuardianViewController] {instance:GetFullName()} is not a complete guardian; no sign`)
			return
		end

		local unmount = Vide.mount(function()
			return GuardianLabel({
				adornee = body,
				name = Text.get(locale, post.nameKey),
				recommended = recommendedText(instance),
			})
		end, instance)
		paintEyes(instance)
		local restSize = body.Size
		views[instance] = {
			unmount = unmount,
			connections = {
				instance:GetAttributeChangedSignal(GuardianConfig.STATE_ATTRIBUTE):Connect(function()
					paintEyes(instance)
				end),
				instance:GetAttributeChangedSignal(GuardianConfig.LAST_CATCH_ATTRIBUTE):Connect(function()
					TweenService:Create(body, STRIKE_TWEEN, { Size = restSize * STRIKE_SCALE }):Play()
				end),
			},
		}
	end

	local function forget(instance: Instance)
		local view = views[instance]
		if view then
			views[instance] = nil
			for _, connection in view.connections do
				connection:Disconnect()
			end
			view.unmount()
		end
	end

	local function start()
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		CollectionService:GetInstanceAddedSignal(GuardianConfig.TAG):Connect(function(instance)
			task.spawn(watch, instance, locale)
		end)
		CollectionService:GetInstanceRemovedSignal(GuardianConfig.TAG):Connect(forget)
		for _, instance in CollectionService:GetTagged(GuardianConfig.TAG) do
			task.spawn(watch, instance, locale)
		end
	end

	return {
		name = "GuardianViewController",
		start = start,
	}
end

return table.freeze(GuardianViewController)
