--!strict
-- Client-side visuals for loose eggs: a glowing trail in the egg's color, so a knocked-out egg
-- is easy to follow with the eye as it flies off.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)

local TRAIL_LIFETIME = 0.4
local TRAIL_WIDTH_OFFSET = 0.6

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
	local config = EggConfig.RARITIES[rarity :: EggConfig.RarityId]
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

function EggEffectsController.new(): EggEffectsController
	local function start()
		CollectionService:GetInstanceAddedSignal(EggConfig.LOOSE_EGG_TAG):Connect(addTrail)
		for _, instance in CollectionService:GetTagged(EggConfig.LOOSE_EGG_TAG) do
			addTrail(instance)
		end
	end

	return {
		name = "EggEffectsController",
		start = start,
	}
end

return table.freeze(EggEffectsController)
