--!strict
-- Builds a space egg (decision 088): a ceramic capsule from the egg kit, wearing more the rarer it
-- is (a lit seam, a lit window, an antenna and a ring in orbit, a gold cap and a halo; World/EggKit
-- holds the shapes with their colours baked in), scaled by its size. The rarest eggs carry a faint
-- light, meteor eggs are scorched with lava in their seams and burn, lucky ones (the star egg)
-- sparkle. Without the kit in the place the egg is the greybox: a stretched ball.
--
-- The egg is one part that callers place by its CFrame and size: with the kit an invisible box the
-- egg's size, the capsule welded to it (one plastic body, one Neon piece, a gold cap: one part per
-- material, for phones). Its look vector is where the window faces.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggKit = require(script.Parent.EggKit)
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
	-- Luck on top of its own (the star egg); an egg with some sparkles.
	luck: number?,
}

local function setUp(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
end

-- Puts the kit's piece `id` on the egg where a medium egg wears it, grown by `scale`, and welds it
-- there. A Weld, not a WeldConstraint: callers set the egg's CFrame before it enters the
-- workspace, and a WeldConstraint would switch on with whatever offset the parts have then; a Weld
-- holds its C0 whenever it switches on.
local function wear(egg: BasePart, id: string, scale: number, color: Color3, material: Enum.Material): MeshPart?
	local piece = EggKit.piece(id)
	if not piece then
		return nil
	end
	local part = piece.part
	local offset = piece.offset.Rotation + piece.offset.Position * scale
	part.Name = id
	part.Size *= scale
	part.Color = color
	part.Material = material
	part.CFrame = egg.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = egg
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = egg
	return part
end

-- Keeps the capsule on the egg while the egg is out of the workspace. Callers place an egg by its
-- CFrame before parenting it (a nest, a capsule, a thief's chest), and out of the workspace no
-- joint moves the pieces along: when it then enters, the solver may pull the egg back to its
-- pieces instead (a carried egg ended up welded to its thief hundreds of studs away, at the nest
-- it came from, 2026-11-10). In the workspace the welds carry the pieces.
local function follow(egg: BasePart)
	egg:GetPropertyChangedSignal("CFrame"):Connect(function()
		if egg:IsDescendantOf(workspace) then
			return
		end
		for _, child in egg:GetChildren() do
			local weld = child:FindFirstChildWhichIsA("Weld")
			if child:IsA("BasePart") and weld and weld.Part0 == egg then
				child.CFrame = egg.CFrame * weld.C0
			end
		end
	end)
end

local function capsule(egg: BasePart, rarity: EggConfig.RarityId, scale: number, meteor: boolean)
	local kind: EggKit.Kind = if meteor then "Meteor" else rarity
	-- White: the body's colours are baked in its vertices.
	wear(egg, `Body{kind}`, scale, Color3.new(1, 1, 1), EggLooks.SHELL_MATERIAL)
	local glow = if meteor then EggLooks.METEOR.lava else EggLooks.RARITIES[rarity].color
	if kind ~= "Common" then
		wear(egg, `Glow{kind}`, scale, glow, Enum.Material.Neon)
	end
	if kind == "Legendary" then
		local cap = wear(egg, "CapGold", scale, EggLooks.GOLD, EggLooks.SHELL_MATERIAL)
		-- Polished gold, as the pets' (AlienDress): the metal variant, if the place has it.
		local variant = AlienLooks.MODELS.METAL_VARIANT
		if cap and MaterialService:FindFirstChild(variant) then
			cap.MaterialVariant = variant
		end
	end
end

function EggModel.build(rarity: EggConfig.RarityId, size: EggConfig.SizeId, options: Options?): BasePart
	local look = EggLooks.RARITIES[rarity]
	local scale = EggConfig.SIZES[size].scale
	local glow = look.glow * (if options and options.glowScale then options.glowScale else 1)
	local variant = if options and options.variant then options.variant else "Normal"
	local meteor = variant == "Meteor"

	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = EggLooks.EGG_SIZE * scale
	setUp(egg)
	if EggKit.present() then
		-- The capsule shows the egg; this box only holds it, the light and the tags.
		egg.Transparency = 1
		capsule(egg, rarity, scale, meteor)
		follow(egg)
	else
		egg.Color = if meteor then EggLooks.METEOR.lava else look.color
		egg.Material = EggLooks.SHELL_MATERIAL
		-- A sphere mesh stretched to the part's size gives the egg shape.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = egg
	end

	if glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Range = GLOW_RANGE * glow
		light.Brightness = GLOW_BRIGHTNESS * glow
		light.Shadows = false
		light.Parent = egg
	end

	if meteor then
		local fire = Instance.new("Fire")
		fire.Color = EggLooks.METEOR.fireColor
		fire.SecondaryColor = EggLooks.METEOR.fireSecondaryColor
		fire.Size = EggLooks.METEOR.fireSize * scale
		fire.Heat = EggLooks.METEOR.fireHeat
		fire.Parent = egg
	end

	local luck = if options then options.luck else nil
	if luck and luck > 0 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = EggLooks.LUCKY_SPARKLE_COLOR
		sparkles.Parent = egg
	end

	egg:SetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE, rarity)
	egg:SetAttribute(EggConfig.LOOSE_EGG_SIZE_ATTRIBUTE, size)
	egg:SetAttribute(EggConfig.EGG_VARIANT_ATTRIBUTE, variant)
	return egg
end

return table.freeze(EggModel)
