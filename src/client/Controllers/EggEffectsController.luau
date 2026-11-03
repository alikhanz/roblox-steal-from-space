--!strict
-- Client-side visuals for eggs out of their nests: a glowing trail in the egg's color, so a
-- knocked-out egg is easy to follow with the eye as it flies off, and sparks around a carried
-- egg, so a thief seen from behind is clearly holding something (a trail is a ribbon and
-- vanishes edge-on).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)

local TRAIL_LIFETIME = 0.4
local TRAIL_WIDTH_OFFSET = 0.6
-- Sparks around a carried egg.
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARK_RATE = 24
local SPARK_LIFETIME = NumberRange.new(0.5, 0.9)
local SPARK_SPEED = NumberRange.new(1.5, 3)
local SPARK_SIZE = 0.7

export type EggEffectsController = {
	name: string,
	start: () -> (),
}

local EggEffectsController = {}

local function addTrail(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local rarity = instance:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE)
	local config = EggLooks.RARITIES[rarity :: EggConfig.RarityId]
	if not config then
		warn(`[EggEffectsController] {instance:GetFullName()} has no rarity; no trail`)
		return
	end

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, TRAIL_WIDTH_OFFSET, 0)
	top.Parent = instance
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -TRAIL_WIDTH_OFFSET, 0)
	bottom.Parent = instance

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(config.color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = TRAIL_LIFETIME
	trail.LightEmission = 1
	trail.Parent = instance
end

local function addSparks(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local rarity = instance:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE)
	local config = EggLooks.RARITIES[rarity :: EggConfig.RarityId]
	if not config then
		warn(`[EggEffectsController] {instance:GetFullName()} has no rarity; no sparks`)
		return
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(config.color)
	sparks.LightEmission = 1
	sparks.Rate = SPARK_RATE
	sparks.Lifetime = SPARK_LIFETIME
	sparks.Speed = SPARK_SPEED
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, SPARK_SIZE),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Parent = instance
end

function EggEffectsController.new(): EggEffectsController
	local function observe(tag: string, decorate: (Instance) -> ())
		CollectionService:GetInstanceAddedSignal(tag):Connect(decorate)
		for _, instance in CollectionService:GetTagged(tag) do
			decorate(instance)
		end
	end

	local function start()
		observe(EggConfig.LOOSE_EGG_TAG, addTrail)
		observe(EggConfig.CARRIED_EGG_TAG, addSparks)
	end

	return {
		name = "EggEffectsController",
		start = start,
	}
end

return table.freeze(EggEffectsController)
