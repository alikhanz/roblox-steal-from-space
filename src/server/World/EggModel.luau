--!strict
-- Builds a space egg (decision 122): a cut gem from the egg kit, wearing more the rarer it is (a
-- girdle of light, a tip, fins, an orbit, a gold crown; a meteor egg scorched with lava cracks and
-- a flame, the star egg night blue with a gold star: Domain/EggPieces), each piece one shared mesh
-- painted here (EggLooks.GEM), scaled by its size. The rarest eggs carry a faint light, meteor eggs
-- burn, lucky ones (the star egg) sparkle. Without the kit in the place the egg is the greybox: a
-- stretched ball.
--
-- The egg is one part that callers place by its CFrame and size: with the kit an invisible box the
-- egg's size, the gem's pieces welded to it. Its look vector is where the star egg's star faces.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggKind = require(ReplicatedStorage.Shared.Domain.EggKind)
local EggKit = require(script.Parent.EggKit)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local EggPieces = require(ReplicatedStorage.Shared.Domain.EggPieces)

local EggModel = {}

local GEM = EggLooks.GEM

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

-- The colour and material of a piece painted `paint` on an egg of `rarity` and `kind`.
local function paintOf(paint: EggPieces.Paint, rarity: EggConfig.RarityId, kind: EggKind.Kind): (Color3, Enum.Material)
	local colour = EggLooks.RARITIES[rarity].color
	local plastic = EggLooks.SHELL_MATERIAL
	if paint == "Shell" then
		if kind == "Meteor" then
			return colour:Lerp(GEM.char, GEM.charMix), plastic
		elseif kind == "Star" then
			return GEM.starShell, plastic
		end
		return colour, plastic
	elseif paint == "Line" then
		-- A common egg has no light: its girdle is pale plastic.
		if rarity == "Common" then
			return colour:Lerp(Color3.new(1, 1, 1), GEM.commonLineWhiten), plastic
		end
		return colour, Enum.Material.Neon
	elseif paint == "Fins" then
		return colour:Lerp(GEM.dark, GEM.finMix), plastic
	elseif paint == "Gold" then
		return EggLooks.GOLD, plastic
	elseif paint == "Lava" then
		return EggLooks.METEOR.lava, Enum.Material.Neon
	elseif paint == "Flame" then
		return GEM.flame, Enum.Material.Neon
	end
	return GEM.starGold, Enum.Material.Neon
end

local function gem(egg: BasePart, rarity: EggConfig.RarityId, scale: number, kind: EggKind.Kind)
	for _, piece in EggPieces.of(rarity, kind) do
		local colour, material = paintOf(piece.paint, rarity, kind)
		local part = wear(egg, piece.id, scale, colour, material)
		-- Polished gold, as the pets' (AlienDress): the metal variant, if the place has it.
		local variant = AlienLooks.MODELS.METAL_VARIANT
		if part and piece.paint == "Gold" and MaterialService:FindFirstChild(variant) then
			part.MaterialVariant = variant
		end
	end
end

function EggModel.build(rarity: EggConfig.RarityId, size: EggConfig.SizeId, options: Options?): BasePart
	local look = EggLooks.RARITIES[rarity]
	local scale = EggConfig.SIZES[size].scale
	local glow = look.glow * (if options and options.glowScale then options.glowScale else 1)
	local variant = if options and options.variant then options.variant else "Normal"
	local meteor = variant == "Meteor"
	local luck = if options then options.luck else nil
	local kind = EggKind.of(variant, luck ~= nil and luck > 0)

	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = EggLooks.EGG_SIZE * scale
	setUp(egg)
	if EggKit.present() then
		-- The gem shows the egg; this box only holds it, the light and the tags.
		egg.Transparency = 1
		gem(egg, rarity, scale, kind)
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

	if kind == "Star" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = EggLooks.LUCKY_SPARKLE_COLOR
		sparkles.Parent = egg
		egg:SetAttribute(EggConfig.EGG_LUCKY_ATTRIBUTE, true)
	end

	egg:SetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE, rarity)
	egg:SetAttribute(EggConfig.LOOSE_EGG_SIZE_ATTRIBUTE, size)
	egg:SetAttribute(EggConfig.EGG_VARIANT_ATTRIBUTE, variant)
	return egg
end

return table.freeze(EggModel)
