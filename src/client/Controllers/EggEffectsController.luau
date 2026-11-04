--!strict
-- Client-side visuals for eggs out of their nests, in the egg's color: a glowing ribbon behind
-- every egg on the move (a knocked-out egg flying off, an egg in a thief's hands), so it is easy
-- to follow with the eye, and sparks around a carried egg, so a thief is clearly holding
-- something. The ribbon faces the camera, so it does not vanish edge-on from behind. Looks are
-- in EggLooks.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type TrailLook = typeof(EggLooks.CARRIED_TRAIL)

export type EggEffectsController = {
	name: string,
	start: () -> (),
}

local EggEffectsController = {}

local function colorOf(instance: Instance, what: string): Color3?
	local rarity = instance:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE)
	local config = EggLooks.RARITIES[rarity :: EggConfig.RarityId]
	if not config then
		warn(`[EggEffectsController] {instance:GetFullName()} has no rarity; no {what}`)
		return nil
	end
	return config.color
end

local function addTrail(part: BasePart, color: Color3, look: TrailLook)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, look.width / 2, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -look.width / 2, 0)
	bottom.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(look.startTransparency, 1)
	-- Full width at the egg, thinning towards the end.
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Lifetime = look.lifetime
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = look.brightness
	trail.Parent = part
end

local function addSparks(part: BasePart, color: Color3)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Rate = EggLooks.SPARK_RATE
	sparks.Lifetime = EggLooks.SPARK_LIFETIME
	sparks.Speed = EggLooks.SPARK_SPEED
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, EggLooks.SPARK_SIZE),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Parent = part
end

local function decorateLoose(instance: Instance)
	local color = instance:IsA("BasePart") and colorOf(instance, "trail")
	if color then
		addTrail(instance :: BasePart, color, EggLooks.LOOSE_TRAIL)
	end
end

local function decorateCarried(instance: Instance)
	local color = instance:IsA("BasePart") and colorOf(instance, "trail")
	if color then
		addTrail(instance :: BasePart, color, EggLooks.CARRIED_TRAIL)
		addSparks(instance :: BasePart, color)
	end
end

function EggEffectsController.new(): EggEffectsController
	local function observe(tag: string, decorate: (Instance) -> ())
		CollectionService:GetInstanceAddedSignal(tag):Connect(decorate)
		for _, instance in CollectionService:GetTagged(tag) do
			decorate(instance)
		end
	end

	local function start()
		observe(EggConfig.LOOSE_EGG_TAG, decorateLoose)
		observe(EggConfig.CARRIED_EGG_TAG, decorateCarried)
	end

	return {
		name = "EggEffectsController",
		start = start,
	}
end

return table.freeze(EggEffectsController)
