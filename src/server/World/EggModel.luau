--!strict
-- Builds the greybox space egg: an elongated sphere in its rarity's color; rarer eggs glow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)

local EggModel = {}

local GLOW_RANGE = 14
local GLOW_BRIGHTNESS = 2

function EggModel.build(rarity: EggConfig.RarityId): Part
	local config = EggConfig.RARITIES[rarity]

	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = EggConfig.EGG_SIZE
	egg.Color = config.color
	egg.Material = if config.glow > 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	egg.CanCollide = false
	egg.CanTouch = false
	egg.CanQuery = false
	egg.Massless = true
	egg.CastShadow = false

	-- A sphere mesh stretched to the part's size gives the egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg

	if config.glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = config.color
		light.Range = GLOW_RANGE * config.glow
		light.Brightness = GLOW_BRIGHTNESS * config.glow
		light.Parent = egg
	end

	egg:SetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE, rarity)
	return egg
end

return table.freeze(EggModel)
