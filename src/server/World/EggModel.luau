--!strict
-- Builds the greybox space egg: an elongated sphere in its rarity's color, scaled by its size;
-- rarer eggs glow, meteor eggs burn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)

local EggModel = {}

local GLOW_RANGE = 14
local GLOW_BRIGHTNESS = 2

export type Options = {
	-- Scales the light of a glowing egg (default 1): a pile in an incubator keeps its shine but
	-- not twelve full lights.
	glowScale: number?,
	-- The alien variant it hatches into; a meteor egg burns (EggLooks.METEOR).
	variant: AlienConfig.VariantId?,
}

function EggModel.build(rarity: EggConfig.RarityId, size: EggConfig.SizeId, options: Options?): Part
	local config = EggLooks.RARITIES[rarity]
	local sizeConfig = EggConfig.SIZES[size]
	local glow = config.glow * (if options and options.glowScale then options.glowScale else 1)
	local variant = if options and options.variant then options.variant else "Normal"
	local glows = glow > 0

	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = EggLooks.EGG_SIZE * sizeConfig.scale
	egg.Color = config.color
	egg.Material = if glows then Enum.Material.Neon else Enum.Material.SmoothPlastic
	egg.CanCollide = false
	egg.CanTouch = false
	egg.CanQuery = false
	egg.Massless = true
	egg.CastShadow = false

	-- A sphere mesh stretched to the part's size gives the egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg

	if glows then
		local light = Instance.new("PointLight")
		light.Color = config.color
		light.Range = GLOW_RANGE * glow
		light.Brightness = GLOW_BRIGHTNESS * glow
		light.Parent = egg
	end

	if variant == "Meteor" then
		local fire = Instance.new("Fire")
		fire.Color = EggLooks.METEOR.fireColor
		fire.SecondaryColor = EggLooks.METEOR.fireSecondaryColor
		fire.Size = EggLooks.METEOR.fireSize * sizeConfig.scale
		fire.Heat = EggLooks.METEOR.fireHeat
		fire.Parent = egg
	end

	egg:SetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE, rarity)
	egg:SetAttribute(EggConfig.LOOSE_EGG_SIZE_ATTRIBUTE, size)
	egg:SetAttribute(EggConfig.EGG_VARIANT_ATTRIBUTE, variant)
	return egg
end

return table.freeze(EggModel)
