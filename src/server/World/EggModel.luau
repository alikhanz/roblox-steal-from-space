--!strict
-- Builds a space egg (decision 087): a starry shell from the egg kit in its rarity's tint, wearing
-- more the rarer it is (stars, a ring in orbit, glowing cracks, a halo); scaled by its size. Rarer
-- eggs glow, meteor eggs burn with lava in their cracks, lucky ones (the star egg) sparkle.
-- Without the kit in the place (World/EggKit) the egg is the greybox: a stretched ball.
--
-- The egg is one part (the shell) that callers place by its CFrame; what it wears is welded to it
-- and moves with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
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

local function greyboxShell(color: Color3, size: Vector3): BasePart
	local egg = Instance.new("Part")
	egg.Size = size
	egg.Color = color
	egg.Material = EggLooks.SHELL_MATERIAL
	-- A sphere mesh stretched to the part's size gives the egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	return egg
end

-- Puts `part` at `offset` from the shell and welds it there.
local function wear(shell: BasePart, part: BasePart, offset: CFrame, name: string)
	part.Name = name
	part.CFrame = shell.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shell
	weld.Part1 = part
	weld.Parent = part
	part.Parent = shell
end

-- A piece of the kit on the shell where it was modelled, scaled by `k`, in Neon of `color`.
local function wearPiece(shell: BasePart, id: EggKit.PieceId, k: number, color: Color3)
	local piece = EggKit.piece(id)
	if not piece then
		return
	end
	piece.part.Size *= k
	piece.part.Material = Enum.Material.Neon
	piece.part.Color = color
	wear(shell, piece.part, piece.offset.Rotation + piece.offset.Position * k, id)
end

-- A ring from the kit: `radius` studs, at `frame` from the shell's centre.
local function wearRing(
	shell: BasePart,
	name: string,
	radius: number,
	frame: CFrame,
	color: Color3,
	transparency: number
)
	local piece = EggKit.piece("Ring")
	if not piece then
		return
	end
	-- The ring is modelled flat: its width across is X (and Z); its thickness is Y.
	local k = radius * 2 / piece.part.Size.X
	piece.part.Size *= k
	piece.part.Material = Enum.Material.Neon
	piece.part.Color = color
	piece.part.Transparency = transparency
	wear(shell, piece.part, frame, name)
end

function EggModel.build(rarity: EggConfig.RarityId, size: EggConfig.SizeId, options: Options?): BasePart
	local look = EggLooks.RARITIES[rarity]
	local scale = EggConfig.SIZES[size].scale
	local glow = look.glow * (if options and options.glowScale then options.glowScale else 1)
	local variant = if options and options.variant then options.variant else "Normal"
	local meteor = variant == "Meteor"
	local eggSize = EggLooks.EGG_SIZE * scale
	local shellColor = if meteor then EggLooks.METEOR.shell else look.shell

	local kitShell = EggKit.piece("Shell")
	local modelled = EggKit.shellSize()
	local egg: BasePart
	if kitShell and modelled then
		egg = kitShell.part
		egg.Size = eggSize
		egg.Color = shellColor
		egg.Material = EggLooks.SHELL_MATERIAL
	else
		egg = greyboxShell(shellColor, eggSize)
	end
	egg.Name = "Egg"
	setUp(egg)

	if kitShell and modelled then
		-- How much the kit's pieces grow: this egg's height over the shell's as modelled.
		local k = eggSize.Y / modelled.Y
		local accent = (if meteor then EggLooks.METEOR.crackColor else look.color):Lerp(
			Color3.new(1, 1, 1),
			if meteor then 0 else EggLooks.ACCENT_LIGHTEN
		)
		if look.stars and not meteor then
			wearPiece(egg, "Stars", k, EggLooks.STAR_COLOR)
		end
		if look.cracks or meteor then
			wearPiece(egg, "Cracks", k, accent)
		end
		if look.orbit and not meteor then
			local orbit = EggLooks.ORBIT
			wearRing(egg, "Orbit", orbit.radius * scale, orbit.tilt, accent, orbit.transparency)
		end
		if look.halo and not meteor then
			local halo = EggLooks.HALO
			local above = CFrame.new(0, eggSize.Y / 2 + halo.gap * scale, 0)
			wearRing(egg, "Halo", halo.radius * scale, above, halo.color, 0)
		end
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
