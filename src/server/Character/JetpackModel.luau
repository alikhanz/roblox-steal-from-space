--!strict
-- Builds the greybox jetpack and attaches it to an R15 character: twin tanks on the back,
-- nozzles with flame emitters, and grips in both hands linked to the tanks by hoses.
-- Sizes follow the character's UpperTorso, so scaled avatars get a fitting pack.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)

local JetpackModel = {}

-- Fractions of the UpperTorso size.
local TANK_HEIGHT = 0.95
local TANK_DIAMETER = 0.34
local TANK_SPACING = 0.27
local PLATE_THICKNESS = 0.12
local NOZZLE_LENGTH = 0.2
local NOZZLE_DIAMETER = 0.27
-- Absolute sizes, studs.
local GRIP_LENGTH = 1.25
local GRIP_DIAMETER = 0.3
local HOSE_WIDTH = 0.12
local HOSE_SAG = 1.2

local SIDES = { -1, 1 }

-- Decorative part: welded, weightless, invisible to physics queries.
local function decor(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = to
	constraint.Part1 = part
	constraint.Parent = part
end

-- A vertical cylinder at `offset` (Roblox cylinders run along X, so rotate them upright).
local function upright(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function addFlame(nozzle: BasePart, exitOffset: Vector3)
	local exit = Instance.new("Attachment")
	exit.Name = JetpackConfig.NOZZLE_ATTACHMENT_NAME
	-- The nozzle's axis is its local X (pointing up once upright). Turning the attachment 90° about Z
	-- maps its +Y onto the nozzle's -X, so the emitter's Top direction fires down out of the nozzle.
	exit.CFrame = CFrame.new(exitOffset) * CFrame.Angles(0, 0, math.rad(90))
	exit.Parent = nozzle

	local flame = Instance.new("ParticleEmitter")
	flame.Name = JetpackConfig.FLAME_NAME
	flame.Texture = JetpackConfig.FLAME_TEXTURE
	flame.Color = ColorSequence.new(JetpackConfig.FLAME_COLOR_START, JetpackConfig.FLAME_COLOR_END)
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Lifetime = NumberRange.new(0.12, 0.25)
	flame.Speed = NumberRange.new(10, 16)
	flame.SpreadAngle = Vector2.new(8, 8)
	flame.EmissionDirection = Enum.NormalId.Top
	flame.Rate = 0
	flame.Enabled = false
	flame.Parent = exit

	local light = Instance.new("PointLight")
	light.Name = JetpackConfig.FLAME_LIGHT_NAME
	light.Color = JetpackConfig.FLAME_LIGHT_COLOR
	light.Brightness = 0
	light.Range = JetpackConfig.FLAME_LIGHT_RANGE
	light.Enabled = false
	light.Parent = exit
end

local function buildPack(model: Model, torso: BasePart): { [number]: Attachment }
	local size = torso.Size
	local backZ = size.Z / 2
	local plateZ = backZ + size.Z * PLATE_THICKNESS / 2
	local tankDiameter = size.X * TANK_DIAMETER
	local tankZ = backZ + size.Z * PLATE_THICKNESS + tankDiameter / 2
	local tankHeight = size.Y * TANK_HEIGHT
	local hoseAnchors: { [number]: Attachment } = {}

	local plate = decor(
		"Plate",
		Enum.PartType.Block,
		Vector3.new(size.X * 0.75, size.Y * 0.8, size.Z * PLATE_THICKNESS),
		JetpackConfig.FRAME_COLOR,
		Enum.Material.Metal
	)
	weld(plate, torso, CFrame.new(0, 0, plateZ))
	plate.Parent = model

	for _, side in SIDES do
		local x = side * size.X * TANK_SPACING

		local tank = decor(
			"Tank",
			Enum.PartType.Cylinder,
			Vector3.new(tankHeight, tankDiameter, tankDiameter),
			JetpackConfig.BODY_COLOR,
			Enum.Material.Metal
		)
		weld(tank, torso, upright(Vector3.new(x, 0, tankZ)))
		tank.Parent = model

		local cap =
			decor("Cap", Enum.PartType.Ball, Vector3.one * tankDiameter, JetpackConfig.BODY_COLOR, Enum.Material.Metal)
		weld(cap, torso, CFrame.new(x, tankHeight / 2, tankZ))
		cap.Parent = model

		local stripe = decor(
			"Stripe",
			Enum.PartType.Cylinder,
			Vector3.new(tankHeight * 0.08, tankDiameter * 1.04, tankDiameter * 1.04),
			JetpackConfig.ACCENT_COLOR,
			Enum.Material.Neon
		)
		weld(stripe, torso, upright(Vector3.new(x, tankHeight * 0.2, tankZ)))
		stripe.Parent = model

		local nozzleLength = size.Y * NOZZLE_LENGTH
		local nozzle = decor(
			"Nozzle",
			Enum.PartType.Cylinder,
			Vector3.new(nozzleLength, size.X * NOZZLE_DIAMETER, size.X * NOZZLE_DIAMETER),
			JetpackConfig.FRAME_COLOR,
			Enum.Material.Metal
		)
		weld(nozzle, torso, upright(Vector3.new(x, -tankHeight / 2 - nozzleLength / 2, tankZ)))
		-- In the nozzle's own frame its axis is X; the exit is the end pointing down (-X after the upright turn).
		addFlame(nozzle, Vector3.new(-nozzleLength / 2, 0, 0))
		nozzle.Parent = model

		-- On the outer side of the tank, low down. In the upright tank's frame local X points up and
		-- local Y points to the character's left, hence the minus sign for the outward offset.
		local hoseAnchor = Instance.new("Attachment")
		hoseAnchor.Name = "HoseAnchor"
		hoseAnchor.Position = Vector3.new(-tankHeight * 0.3, -side * tankDiameter / 2, 0)
		hoseAnchor.Parent = tank
		hoseAnchors[side] = hoseAnchor
	end
	return hoseAnchors
end

local function buildGrip(model: Model, hand: BasePart, hoseAnchor: Attachment)
	local grip = decor(
		"Grip",
		Enum.PartType.Cylinder,
		Vector3.new(GRIP_LENGTH, GRIP_DIAMETER, GRIP_DIAMETER),
		JetpackConfig.GRIP_COLOR,
		Enum.Material.SmoothPlastic
	)
	-- A joystick through the fist: along the hand's thumb axis (Z), so with the forearm held forward
	-- it stands upright with the button on top (grip +X = hand -Z = thumb side).
	weld(grip, hand, CFrame.new(0, -hand.Size.Y * 0.2, 0) * CFrame.Angles(0, math.rad(90), 0))
	grip.Parent = model

	local button = decor(
		"Button",
		Enum.PartType.Ball,
		Vector3.one * GRIP_DIAMETER * 0.7,
		JetpackConfig.BUTTON_COLOR,
		Enum.Material.Neon
	)
	weld(button, grip, CFrame.new(GRIP_LENGTH / 2, 0, 0))
	button.Parent = model

	local hoseEnd = Instance.new("Attachment")
	hoseEnd.Name = "HoseEnd"
	hoseEnd.Position = Vector3.new(-GRIP_LENGTH / 2, 0, 0)
	hoseEnd.Parent = grip

	local hose = Instance.new("Beam")
	hose.Name = "Hose"
	hose.Attachment0 = hoseEnd
	hose.Attachment1 = hoseAnchor
	hose.Width0 = HOSE_WIDTH
	hose.Width1 = HOSE_WIDTH
	hose.CurveSize0 = -HOSE_SAG
	hose.CurveSize1 = HOSE_SAG
	hose.Segments = 12
	hose.FaceCamera = true
	hose.Color = ColorSequence.new(JetpackConfig.HOSE_COLOR)
	hose.LightInfluence = 1
	hose.Parent = grip
end

-- Attaches a jetpack to `character`. Returns nil (with a warning) for rigs it cannot fit.
function JetpackModel.attach(character: Model): Model?
	local torso = character:FindFirstChild("UpperTorso")
	local rightHand = character:FindFirstChild("RightHand")
	local leftHand = character:FindFirstChild("LeftHand")
	if
		not (
			torso
			and torso:IsA("BasePart")
			and rightHand
			and rightHand:IsA("BasePart")
			and leftHand
			and leftHand:IsA("BasePart")
		)
	then
		warn(`[JetpackModel] {character.Name} is not an R15 rig; no jetpack attached`)
		return nil
	end

	local model = Instance.new("Model")
	model.Name = JetpackConfig.MODEL_NAME
	local hoseAnchors = buildPack(model, torso)
	-- Right hand hoses to the right tank (+X side), left hand to the left one.
	buildGrip(model, rightHand, hoseAnchors[1])
	buildGrip(model, leftHand, hoseAnchors[-1])
	model.Parent = character
	return model
end

return table.freeze(JetpackModel)
