--!strict
-- The client side of guardians: the sign with the name over each one, coloured by how the player
-- stands against the guardian's recommended speed (red, white, green: GuardianLooks.standingColor),
-- and its look: its post's model on the server's greybox body (World/GuardianVisual: moving by its
-- state, its eyes in the state's colour, a lunge when it catches someone), or, where the place has
-- no model for its post, the greybox with eyes that light up with its state. Guardians stream in
-- and out, so everything is keyed by the model and torn down when it goes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local GuardianBrain = require(ReplicatedStorage.Shared.Domain.GuardianBrain)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLabel = require(script.Parent.Parent.UI.GuardianLabel)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local GuardianVisual = require(script.Parent.Parent.World.GuardianVisual)
local Mount = require(script.Parent.Parent.UI.Mount)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)

-- The greybox's strike: the body swells and snaps back.
local STRIKE_SCALE = 1.35
local STRIKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)
-- A frame longer than this (a hitch) moves the guardians as if it were this long.
local MAX_FRAME_SECONDS = 0.1

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
	visual: GuardianVisual.Visual?,
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

local function stateOf(model: Model): GuardianBrain.State
	local state = model:GetAttribute(GuardianConfig.STATE_ATTRIBUTE)
	return if GuardianLooks.EYE_COLORS[state :: any] then state :: GuardianBrain.State else "Sleep"
end

-- The model's state (its eyes, pace, jaw), or the greybox's eyes in the state's colour.
local function showState(model: Model, visual: GuardianVisual.Visual?)
	local state = stateOf(model)
	if visual then
		GuardianVisual.setState(visual, state)
		return
	end
	local color = GuardianLooks.EYE_COLORS[state]
	for _, child in model:GetChildren() do
		if child.Name == GuardianConfig.EYE_NAME and child:IsA("BasePart") then
			child.Color = color
		end
	end
end

-- The greybox part hidden on this client under the model (the server's body still moves and
-- catches; its sign hangs on it).
local function hide(part: Instance)
	if part:IsA("BasePart") then
		part.Transparency = 1
	end
end

-- Where this client keeps its guardians' models.
local function lookFolder(): Folder
	local found = workspace:FindFirstChild(GuardianLooks.MODELS.CLIENT_FOLDER)
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = GuardianLooks.MODELS.CLIENT_FOLDER
	folder.Parent = workspace
	return folder
end

function GuardianViewController.new(dependencies: Dependencies): GuardianViewController
	local views: { [Instance]: View } = {}
	-- The models in this client's view, carried and moved every frame.
	local visuals: { [Instance]: GuardianVisual.Visual } = {}
	-- Body watchers of every tagged guardian, present body or not.
	local tracked: { [Instance]: { RBXScriptConnection } } = {}

	local function forget(instance: Instance)
		local view = views[instance]
		if view then
			views[instance] = nil
			visuals[instance] = nil
			for _, connection in view.connections do
				connection:Disconnect()
			end
			view.unmount()
			if view.visual then
				GuardianVisual.detach(view.visual)
			end
		end
	end

	-- Builds the sign and the look for a guardian whose body is present.
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
		-- Each guardian keeps a rhythm of its own, the same every time it streams in.
		local seed = math.floor(body.Position.X * 7 + body.Position.Z * 13)
		local visual = GuardianVisual.attach(body, post, lookFolder(), seed)
		local connections = {
			instance:GetAttributeChangedSignal(GuardianConfig.STATE_ATTRIBUTE):Connect(function()
				showState(instance, visual)
			end),
		}
		local restSize = body.Size
		if visual then
			visuals[instance] = visual
			for _, child in instance:GetChildren() do
				hide(child)
			end
			-- The greybox's eyes may stream in after its body.
			table.insert(connections, instance.ChildAdded:Connect(hide))
			table.insert(
				connections,
				instance:GetAttributeChangedSignal(GuardianConfig.LAST_CATCH_ATTRIBUTE):Connect(function()
					GuardianVisual.strike(visual, os.clock())
				end)
			)
		else
			table.insert(
				connections,
				instance:GetAttributeChangedSignal(GuardianConfig.LAST_CATCH_ATTRIBUTE):Connect(function()
					TweenService:Create(body, STRIKE_TWEEN, { Size = restSize * STRIKE_SCALE }):Play()
				end)
			)
		end
		showState(instance, visual)
		views[instance] = {
			unmount = unmount,
			visual = visual,
			connections = connections,
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

	local last = os.clock()
	local function step()
		local now = os.clock()
		local dt = math.min(now - last, MAX_FRAME_SECONDS)
		last = now
		local camera = workspace.CurrentCamera
		if camera and next(visuals) then
			GuardianVisual.step(visuals, now, dt, camera.CFrame.Position)
		end
	end

	local function start()
		local locale = Text.localeOf(Players.LocalPlayer)
		CollectionService:GetInstanceAddedSignal(GuardianConfig.TAG):Connect(function(instance)
			watch(instance, locale)
		end)
		CollectionService:GetInstanceRemovedSignal(GuardianConfig.TAG):Connect(untrack)
		for _, instance in CollectionService:GetTagged(GuardianConfig.TAG) do
			watch(instance, locale)
		end
		RunService.RenderStepped:Connect(step)
	end

	return {
		name = "GuardianViewController",
		start = start,
	}
end

return table.freeze(GuardianViewController)
