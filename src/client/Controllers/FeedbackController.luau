--!strict
-- Shows how a press ended (docs/design/screens/buttons.md, "Видно, чем кончилось"): a hatched
-- egg bursts in its capsule (a flash of light and stars in the egg's colour) with a pop sound,
-- a crossbreed pops too, and anything bought with coins (a place, a capsule, the trainer, a
-- jetpack) chimes. The buttons' own feel is UI/Press; the toasts still say what happened.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Vide = require(ReplicatedStorage.Packages.Vide)

local STAR_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

export type Dependencies = {
	profile: ProfileState.ProfileState,
}

export type FeedbackController = {
	name: string,
	start: () -> (),
}

local FeedbackController = {}

local LOOK = BayLooks.HATCH_BURST

-- A flash of light and a burst of stars at `position` in `color`, gone in a moment.
local function burst(position: Vector3, color: Color3)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > LOOK.maxDistance then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "HatchBurst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = position
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = STAR_TEXTURE
	stars.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, LOOK.starSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	stars.Lifetime = NumberRange.new(LOOK.seconds * 0.6, LOOK.seconds)
	stars.Speed = NumberRange.new(LOOK.starSpeed * 0.5, LOOK.starSpeed)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Rotation = NumberRange.new(0, 360)
	stars.RotSpeed = NumberRange.new(-180, 180)
	stars.Enabled = false
	stars.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = LOOK.lightRange
	light.Brightness = LOOK.lightBrightness
	light.Parent = holder
	holder.Parent = workspace
	stars:Emit(LOOK.stars)
	TweenService:Create(light, TweenInfo.new(LOOK.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()
	task.delay(LOOK.seconds + 0.2, function()
		holder:Destroy()
	end)
end

function FeedbackController.new(dependencies: Dependencies): FeedbackController
	local profile = dependencies.profile

	local function start()
		profile.hatched.connect(function()
			Sounds.play("Hatch")
		end)
		profile.crossbred.connect(function()
			Sounds.play("Hatch")
		end)

		-- A ready egg leaves its capsule only when it hatches: burst where it lay. (A warming egg
		-- is rebuilt when it becomes ready; that one is not ready yet.)
		CollectionService:GetInstanceRemovedSignal(BayConfig.INCUBATOR_EGG_TAG):Connect(function(instance)
			if not instance:IsA("BasePart") then
				return
			end
			local hatchAt = instance:GetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE)
			if type(hatchAt) ~= "number" or hatchAt > workspace:GetServerTimeNow() then
				return
			end
			burst(instance.Position, instance.Color)
		end)

		-- Bought with coins: one more place, capsule, trainer or jetpack level.
		local last: { number }? = nil
		Vide.root(function()
			Vide.effect(function()
				if not profile.loaded() then
					return
				end
				local bay = profile.bay()
				local upgrades = profile.upgrades()
				local now = { #bay.pods, bay.incubatorSlots, upgrades.trainerLevel, upgrades.jetpackLevel }
				local before = last
				last = now
				if not before then
					return
				end
				for index, value in now do
					if value > before[index] then
						Sounds.play("Buy")
						return
					end
				end
			end)
		end)
	end

	return {
		name = "FeedbackController",
		start = start,
	}
end

return table.freeze(FeedbackController)
