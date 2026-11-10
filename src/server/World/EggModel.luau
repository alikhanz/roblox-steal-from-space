--!strict
-- Builds a space egg (decision 087): a ceramic capsule from the egg kit, a pearl base and a cap in
-- its rarity's colour, wearing more the rarer it is (a lit seam, a lit window, an antenna and a
-- ring in orbit, a gold cap and a halo); scaled by its size. Rarer eggs glow, meteor eggs are
-- scorched with lava in their seams and burn, lucky ones (the star egg) sparkle. Without the kit
-- in the place (World/EggKit) the egg is the greybox: a stretched ball.
--
-- The egg is one part that callers place by its CFrame and size: with the kit an invisible box the
-- egg's size, the capsule's pieces welded to it. Its look vector is where the window faces.

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

-- Puts `part` at `offset` from the egg and welds it there. A Weld, not a WeldConstraint: callers
-- set the egg's CFrame before it enters the workspace, and a WeldConstraint would switch on with
-- whatever offset the parts have then; a Weld holds its C0 whenever it switches on.
local function wear(egg: BasePart, part: BasePart, offset: CFrame, name: string)
	part.Name = name
	part.CFrame = egg.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = egg
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = egg
end

-- A piece of the kit where a medium egg wears it, grown by `scale`.
local function wearPiece(
	egg: BasePart,
	id: EggKit.PieceId,
	scale: number,
	color: Color3,
	material: Enum.Material
): MeshPart?
	local piece = EggKit.piece(id)
	if not piece then
		return nil
	end
	piece.part.Size *= scale
	piece.part.Color = color
	piece.part.Material = material
	wear(egg, piece.part, piece.offset.Rotation + piece.offset.Position * scale, id)
	return piece.part
end

-- A ring from the kit: `radius` studs, at `frame` from the egg's centre.
local function wearRing(egg: BasePart, name: string, radius: number, frame: CFrame, color: Color3, transparency: number)
	local piece = EggKit.piece("Ring")
	if not piece then
		return
	end
	-- The ring is modelled flat: its width across is X (and Z); its thickness is Y.
	piece.part.Size *= radius * 2 / piece.part.Size.X
	piece.part.Material = Enum.Material.Neon
	piece.part.Color = color
	piece.part.Transparency = transparency
	wear(egg, piece.part, frame, name)
end

local function capsule(egg: BasePart, look: EggLooks.RarityLook, scale: number, meteor: boolean)
	local plastic = EggLooks.SHELL_MATERIAL
	local neon = Enum.Material.Neon
	local shell = if meteor then EggLooks.METEOR.shell else EggLooks.PEARL
	local glow = if meteor then EggLooks.METEOR.lava else look.color
	wearPiece(egg, "Base", scale, shell, plastic)
	local cap = wearPiece(egg, "Cap", scale, if meteor then shell else look.cap, plastic)
	if cap and look.gold and not meteor then
		-- Polished gold, as the pets' (AlienDress): the metal variant, if the place has it.
		local variant = AlienLooks.MODELS.METAL_VARIANT
		if MaterialService:FindFirstChild(variant) then
			cap.MaterialVariant = variant
		end
	end
	local seamLit = meteor or look.seamLit
	wearPiece(egg, "Seam", scale, if seamLit then glow else EggLooks.UNLIT, if seamLit then neon else plastic)
	local windowLit = meteor or look.windowLit
	wearPiece(egg, "Window", scale, if windowLit then glow else EggLooks.UNLIT, if windowLit then neon else plastic)
	if meteor then
		wearPiece(egg, "Cracks", scale, glow, neon)
		return
	end
	if look.antenna then
		wearPiece(egg, "Antenna", scale, EggLooks.ANTENNA, plastic)
		wearPiece(egg, "Tip", scale, glow, neon)
	end
	if look.orbit then
		local orbit = EggLooks.ORBIT
		wearRing(egg, "Orbit", orbit.radius * scale, orbit.tilt, glow, orbit.transparency)
	end
	if look.halo then
		local halo = EggLooks.HALO
		local above = CFrame.new(0, (EggLooks.EGG_SIZE.Y / 2 + halo.gap) * scale, 0)
		wearRing(egg, "Halo", halo.radius * scale, above, halo.color, 0)
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
		-- The capsule's pieces show the egg; this box only holds them, the light and the tags.
		egg.Transparency = 1
		capsule(egg, look, scale, meteor)
	else
		egg.Color = if meteor then EggLooks.METEOR.shell else look.cap
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
