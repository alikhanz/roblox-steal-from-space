--!strict
-- The client side of guardians: the sign over each one, its name and how it stands against the
-- player's own ⚡ (UI/GuardianLabel: Speed.challenge against its recommended speed), bigger the
-- nearer it is; and its look. Near the camera (GuardianPose.wears, GuardianLooks.MODELS.ATTACH_*; decision 101)
-- it wears its post's model on the server's greybox body (World/GuardianVisual: moving by its
-- state, its eyes in the state's colour, a lunge when it catches someone) and the greybox is
-- hidden on this client; farther, or where the place has no model for its post, it shows the
-- greybox in its post's colour with eyes that light up with its state. Guardians stream in and
-- out, so everything is keyed by the model and torn down when it goes.

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
local GuardianPose = require(ReplicatedStorage.Shared.Domain.GuardianPose)
local GuardianVisual = require(script.Parent.Parent.World.GuardianVisual)
local Mount = require(script.Parent.Parent.UI.Mount)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)

-- The greybox's strike: the body swells and snaps back.
local STRIKE_SCALE = 1.35
local STRIKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)
-- A frame longer than this (a hitch) moves the guardians as if it were this long.
local MAX_FRAME_SECONDS = 0.1
local MODELS = GuardianLooks.MODELS
local LABEL = GuardianLooks.LABEL

export type Dependencies = {
	-- The player's speed stat: the signs tell how each guardian stands against it.
	speed: () -> BigNum.BigNum,
}

export type GuardianViewController = {
	name: string,
	start: () -> (),
}

type View = {
	instance: Model,
	body: BasePart,
	post: GuardianConfig.Post,
	-- Keeps its rhythm its own each time it puts its model on.
	seed: number,
	-- How near the camera it wears its model (GuardianPose.wearReach), and how far it was at the
	-- last check.
	reach: number,
	distance: number,
	-- False once the place turned out to have no model for its post: the greybox for good.
	hasModel: boolean,
	-- How far its sign shows, and its sign's held size and fade now
	-- (GuardianPose.labelPixelsPerStud, labelFade), followed every frame by its distance.
	signDistance: number,
	labelPixels: Vide.Source<number?>,
	labelFade: Vide.Source<number>,
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

-- Shows or hides a greybox part on this client only (under the model; the server's body still
-- moves and catches, and its sign hangs on it). LocalTransparencyModifier leaves the part's own
-- Transparency alone, so showing it again needs nothing remembered.
local function showPart(part: Instance, shown: boolean)
	if part:IsA("BasePart") then
		part.LocalTransparencyModifier = if shown then 0 else 1
	end
end

local function showGreybox(instance: Instance, shown: boolean)
	for _, child in instance:GetChildren() do
		showPart(child, shown)
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
	-- Guardians to put their model on, nearest first (from the last check), one a frame.
	local pending: { View } = {}
	local nextPending = 1
	local checkAt = 0

	local function wear(view: View)
		local visual = GuardianVisual.attach(view.body, view.post, lookFolder(), view.seed)
		if not visual then
			view.hasModel = false
			return
		end
		view.visual = visual
		visuals[view.instance] = visual
		showGreybox(view.instance, false)
		showState(view.instance, visual)
	end

	local function unwear(view: View)
		local visual = view.visual
		if not visual then
			return
		end
		view.visual = nil
		visuals[view.instance] = nil
		GuardianVisual.detach(visual)
		showGreybox(view.instance, true)
		-- Its eyes were not painted while it wore the model.
		showState(view.instance, nil)
	end

	local function forget(instance: Instance)
		local view = views[instance]
		if view then
			views[instance] = nil
			for _, connection in view.connections do
				connection:Disconnect()
			end
			view.unmount()
			-- Parts that stay (an eye streaming out after the body) are shown again.
			unwear(view)
		end
	end

	-- The words of the signs' pills, in the player's language (set at start).
	local words: { [Speed.Challenge]: string } = {}

	-- How a guardian recommending `recommended` stands against the player now.
	local function challengeOf(recommended: BigNum.BigNum?): Speed.Challenge?
		if not recommended then
			return nil
		end
		return Speed.challenge(dependencies.speed(), recommended, SpeedConfig.CHASE, SpeedConfig.CHALLENGE_WEAK_DECADES)
	end

	-- Builds the sign for a guardian whose body is present; its model comes when it is near (check).
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
		if not recommended then
			warn(`[GuardianViewController] {instance:GetFullName()} has no recommended speed; its sign has no pill`)
		end
		local labelPixels = Vide.source(nil :: number?)
		local labelFade = Vide.source(0)
		local signDistance = ZoneLooks.GUARDIAN_SIGN_DISTANCE[post.zone]
		local unmount = Mount.instance(function()
			return GuardianLabel({
				adornee = body,
				name = Text.get(locale, nameKey),
				challenge = function(): Speed.Challenge?
					return challengeOf(recommended)
				end,
				words = words,
				pixelsPerStud = labelPixels :: () -> number?,
				fade = labelFade,
				studsAbove = body.Size.Y / 2 + LABEL.STUDS_ABOVE,
				maxDistance = signDistance,
				debugText = debugTextOf(post, recommended),
			})
		end, instance)
		-- The model is fitted to the kind's box times the post's scale (GuardianVisual.attach).
		local box = GuardianLooks.KINDS[post.kind].bodySize
		local length = math.max(box.X, box.Z) * GuardianLooks.POSTS[post.id].scale
		local view: View = {
			instance = instance,
			body = body,
			post = post,
			-- Each guardian keeps a rhythm of its own, the same every time it streams in.
			seed = math.floor(body.Position.X * 7 + body.Position.Z * 13),
			reach = GuardianPose.wearReach(length, MODELS.ATTACH_DISTANCE, MODELS.ATTACH_LENGTHS),
			distance = math.huge,
			hasModel = true,
			signDistance = signDistance,
			labelPixels = labelPixels,
			labelFade = labelFade,
			unmount = unmount,
			connections = {},
			visual = nil,
		}
		local restSize = body.Size
		view.connections = {
			instance:GetAttributeChangedSignal(GuardianConfig.STATE_ATTRIBUTE):Connect(function()
				showState(instance, view.visual)
			end),
			instance:GetAttributeChangedSignal(GuardianConfig.LAST_CATCH_ATTRIBUTE):Connect(function()
				local visual = view.visual
				if visual then
					GuardianVisual.strike(visual, os.clock())
				else
					TweenService:Create(body, STRIKE_TWEEN, { Size = restSize * STRIKE_SCALE }):Play()
				end
			end),
			-- The greybox's eyes may stream in after its body.
			instance.ChildAdded:Connect(function(child)
				if view.visual then
					showPart(child, false)
				end
			end),
		}
		showState(instance, nil)
		views[instance] = view
		-- Checked at once: a guardian put next to the player (the bench) dresses without waiting.
		checkAt = 0
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

	-- Which guardians wear their model, by their distance from the camera at `eye`: those gone far
	-- take it off at once (cheap), those come near queue to put it on.
	local function check(eye: Vector3)
		table.clear(pending)
		nextPending = 1
		for _, view in views do
			view.distance = (view.body.Position - eye).Magnitude
			local wearing = view.visual ~= nil
			local wanted = view.hasModel
				and GuardianPose.wears(wearing, view.distance, view.reach, MODELS.ATTACH_MARGIN)
			if wearing and not wanted then
				unwear(view)
			elseif wanted and not wearing then
				table.insert(pending, view)
			end
		end
		table.sort(pending, function(a: View, b: View): boolean
			return a.distance < b.distance
		end)
	end

	-- Puts the model on the nearest guardian still waiting for it: one a frame, a copy is ~25
	-- MeshParts.
	local function wearNext()
		while nextPending <= #pending do
			local view = pending[nextPending]
			nextPending += 1
			if views[view.instance] == view and not view.visual and view.hasModel then
				wear(view)
				return
			end
		end
	end

	local last = os.clock()
	local function step()
		local now = os.clock()
		local dt = math.min(now - last, MAX_FRAME_SECONDS)
		last = now
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		if now >= checkAt then
			checkAt = now + MODELS.ATTACH_CHECK_SECONDS
			check(eye)
		end
		wearNext()
		for _, view in views do
			local distance = (view.body.Position - eye).Magnitude
			local pixels = GuardianPose.labelPixelsPerStud(
				distance,
				LABEL.NEAR_DISTANCE,
				LABEL.FAR_DISTANCE,
				camera.ViewportSize.Y,
				camera.FieldOfView
			)
			-- Changes only as the sign crosses an edge or the view changes.
			if pixels ~= (view.labelPixels :: () -> number?)() then
				view.labelPixels(pixels)
			end
			local fade = GuardianPose.labelFade(distance, LABEL.FADE_START, view.signDistance, LABEL.FADE_MAX)
			-- Only a visible change wakes the sign up.
			if math.abs(fade - view.labelFade()) > LABEL.FADE_STEP then
				view.labelFade(fade)
			end
		end
		if next(visuals) then
			GuardianVisual.step(visuals, now, dt, eye)
		end
	end

	local function start()
		local locale = Text.localeOf(Players.LocalPlayer)
		for challenge, look in GuardianLooks.CHALLENGES do
			-- Checked at the config; through `any`, as the union of every key is too much here.
			local key: any = look.textKey
			words[challenge] = Text.get(locale, key)
		end
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
