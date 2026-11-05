--!strict
-- The client side of guardians: the sign with the name over each one, coloured by how the player
-- stands against the guardian's recommended speed (red, white, green: GuardianLooks.standingColor),
-- and
-- eyes that light up with the guardian's state. Guardians stream in and out, so everything is
-- keyed by the model and torn down when it goes.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLabel = require(script.Parent.Parent.UI.GuardianLabel)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local Mount = require(script.Parent.Parent.UI.Mount)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)

-- The strike: the body swells and snaps back.
local STRIKE_SCALE = 1.35
local STRIKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)

export type Dependencies = {
	-- The player's speed stat: the names are coloured by it.
	speed: () -> BigNum.BigNum,
}

export type GuardianViewController = {
	name: string,
	start: () -> (),
}

type View = {
	unmount: () -> (),
	connections: { RBXScriptConnection },
}

local GuardianViewController = {}

local function recommendedOf(model: Model): BigNum.BigNum?
	return BigNum.fromSaved({
		mantissa = model:GetAttribute(GuardianConfig.RECOMMENDED_MANTISSA_ATTRIBUTE),
		exponent = model:GetAttribute(GuardianConfig.RECOMMENDED_EXPONENT_ATTRIBUTE),
	})
end

-- Debug only, Studio only (DevConfig.STUDIO_GUARDIAN_SPEED): the guardian's own speed stat and
-- its recommended one under its name. Nil in a live game, where players never see numbers there.
local function debugTextOf(post: GuardianConfig.Post, recommended: BigNum.BigNum?): string?
	if not RunService:IsStudio() or not DevConfig.STUDIO_GUARDIAN_SPEED then
		return nil
	end
	local rec = if recommended then BigNum.format(recommended) else "?"
	return `⚡ {BigNum.format(post.speed)} · rec {rec}`
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

function GuardianViewController.new(dependencies: Dependencies): GuardianViewController
	local views: { [Instance]: View } = {}
	-- Body watchers of every tagged guardian, present body or not.
	local tracked: { [Instance]: { RBXScriptConnection } } = {}

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

	-- Builds the sign and eye painting for a guardian whose body is present.
	local function show(instance: Instance, body: Instance, locale: Text.Locale)
		if views[instance] then
			return
		end
		local postId = instance:GetAttribute(GuardianConfig.POST_ATTRIBUTE)
		local post = GuardianConfig.POSTS_BY_ID[postId :: GuardianConfig.PostId]
		if not instance:IsA("Model") or not body:IsA("BasePart") or not post then
			warn(`[GuardianViewController] {instance:GetFullName()} is not a complete guardian; no sign`)
			return
		end

		-- The key is checked at the config; it passes through `any` because the union of every
		-- string key is too much for the type checker here.
		local nameKey: any = post.nameKey
		local recommended = recommendedOf(instance)
		local unmount = Mount.instance(function()
			return GuardianLabel({
				adornee = body,
				name = Text.get(locale, nameKey),
				nameColor = function(): Color3
					if not recommended then
						return GuardianLooks.standingColor(0)
					end
					local standing = Speed.standing(
						dependencies.speed(),
						recommended,
						SpeedConfig.CHASE,
						SpeedConfig.STANDING_GREEN_DECADES
					)
					return GuardianLooks.standingColor(standing)
				end,
				maxDistance = ZoneLooks.GUARDIAN_SIGN_DISTANCE[post.zone],
				debugText = debugTextOf(post, recommended),
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

	-- Far guardians stream in as a model whose parts follow by distance, and stream out part by
	-- part: the sign is built whenever the body is there and dropped whenever it leaves.
	local function watch(instance: Instance, locale: Text.Locale)
		if tracked[instance] then
			return
		end
		tracked[instance] = {
			instance.ChildAdded:Connect(function(child)
				if child.Name == GuardianConfig.BODY_NAME then
					forget(instance)
					show(instance, child, locale)
				end
			end),
			instance.ChildRemoved:Connect(function(child)
				if child.Name == GuardianConfig.BODY_NAME then
					forget(instance)
				end
			end),
		}
		local body = instance:FindFirstChild(GuardianConfig.BODY_NAME)
		if body then
			show(instance, body, locale)
		end
	end

	local function untrack(instance: Instance)
		local connections = tracked[instance]
		if connections then
			tracked[instance] = nil
			for _, connection in connections do
				connection:Disconnect()
			end
		end
		forget(instance)
	end

	local function start()
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		CollectionService:GetInstanceAddedSignal(GuardianConfig.TAG):Connect(function(instance)
			watch(instance, locale)
		end)
		CollectionService:GetInstanceRemovedSignal(GuardianConfig.TAG):Connect(untrack)
		for _, instance in CollectionService:GetTagged(GuardianConfig.TAG) do
			watch(instance, locale)
		end
	end

	return {
		name = "GuardianViewController",
		start = start,
	}
end

return table.freeze(GuardianViewController)
