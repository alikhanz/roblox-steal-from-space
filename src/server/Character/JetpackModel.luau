--!strict
-- Attaches the jetpack to an R15 character (decision 089): the body of its jetpack from the place's
-- templates (ServerStorage.Jetpacks, one model per jetpack, colours baked in its meshes), grips in
-- both hands linked to the pack by hoses, and an attachment at each nozzle's exit for the flame,
-- which every client adds itself (JetpackEffectsController). Sizes follow the character's
-- UpperTorso, so scaled avatars get a fitting pack. Without the templates (a place that lags the
-- repo) a greybox of twin tanks stands in.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)

local JetpackModel = {}

-- Greybox, fractions of the UpperTorso size.
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

local warned = false

-- Weightless and invisible to physics queries: the jetpack is decoration.
local function quiet(part: BasePart)
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function decor(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.CastShadow = false
	quiet(part)
	return part
end

local function weldInPlace(part: BasePart, to: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = to
	constraint.Part1 = part
	constraint.Parent = part
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	weldInPlace(part, to)
end

-- A vertical cylinder at `position` (Roblox cylinders run along X, so rotate them upright).
local function upright(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function template(jetpack: number): Model?
	local folder = ServerStorage:FindFirstChild(JetpackConfig.MODELS_FOLDER)
	local found = folder and folder:FindFirstChild(JetpackConfig.TEMPLATE_PREFIX .. jetpack)
	if found and found:IsA("Model") then
		return found
	end
	if not warned then
		warned = true
		warn(
			`[JetpackModel] ServerStorage.{JetpackConfig.MODELS_FOLDER}.{JetpackConfig.TEMPLATE_PREFIX}{jetpack} is missing; the greybox jetpack stands in (docs/plans/JETPACKS.md)`
		)
	end
	return nil
end

-- Paints a template's part by its name (JetpackLooks.PARTS): white, so its baked colours show.
local function dress(part: BasePart)
	quiet(part)
	-- Templates are stored anchored; on the character the welds hold the parts.
	part.Anchored = false
	part.Color = Color3.new(1, 1, 1)
	local look = JetpackLooks.PARTS[part.Name]
	if not look then
		return
	end
	part.Material = look.material
	part.Reflectance = look.reflectance
	part.Transparency = look.transparency
	part.CastShadow = look.shadow
	if look.metal and MaterialService:FindFirstChild(JetpackLooks.METAL_VARIANT) then
		part.MaterialVariant = JetpackLooks.METAL_VARIANT
	end
end

-- The template's body on the torso. Returns the hose anchors by side (+1 right, −1 left).
local function buildFromTemplate(model: Model, torso: BasePart, source: Model): { [number]: Attachment }
	local pack = source:Clone()
	local scale = torso.Size.X / JetpackConfig.TEMPLATE_TORSO_WIDTH
	-- ScaleTo is absolute: keep whatever scale the template was stored at.
	pack:ScaleTo(pack:GetScale() * scale)
	-- The template's back meets the torso's back, whatever the torso's depth.
	local shift = torso.Size.Z / 2 - JetpackConfig.TEMPLATE_BACK * scale
	pack:PivotTo(torso.CFrame * CFrame.new(0, 0, shift))
	local first: BasePart? = nil
	for _, part in pack:GetChildren() do
		if part:IsA("BasePart") then
			dress(part)
			weldInPlace(part, torso)
			part.Parent = model
			first = first or part
		end
	end
	pack:Destroy()
	local anchors: { [number]: Attachment } = {}
	if first then
		local at = JetpackConfig.TEMPLATE_HOSE_ANCHOR
		for _, side in SIDES do
			local anchor = Instance.new("Attachment")
			anchor.Name = JetpackConfig.HOSE_ANCHOR_NAME
			anchor.Parent = first
			anchor.WorldPosition = (torso.CFrame * CFrame.new(side * at.X * scale, at.Y * scale, shift + at.Z * scale)).Position
			anchors[side] = anchor
		end
	end
	return anchors
end

-- The greybox: twin tanks on a back plate, a nozzle under each. Returns the hose anchors.
local function buildGreybox(model: Model, torso: BasePart, looks: JetpackLooks.Looks): { [number]: Attachment }
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
			looks.bodyColor,
			Enum.Material.Metal
		)
		weld(tank, torso, upright(Vector3.new(x, 0, tankZ)))
		tank.Parent = model

		local cap = decor("Cap", Enum.PartType.Ball, Vector3.one * tankDiameter, looks.bodyColor, Enum.Material.Metal)
		weld(cap, torso, CFrame.new(x, tankHeight / 2, tankZ))
		cap.Parent = model

		local stripe = decor(
			"Stripe",
			Enum.PartType.Cylinder,
			Vector3.new(tankHeight * 0.08, tankDiameter * 1.04, tankDiameter * 1.04),
			looks.accentColor,
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
		-- The nozzle's axis is its local X (up once upright); the exit is its −X end. Turned −90°
		-- about Z, the attachment's +Y lies along the nozzle's +X, so its −Y — the flame — points down.
		local exit = Instance.new("Attachment")
		exit.Name = JetpackConfig.NOZZLE_ATTACHMENT_NAME
		exit.CFrame = CFrame.new(-nozzleLength / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
		exit.Parent = nozzle
		nozzle.Parent = model

		-- On the outer side of the tank, low down. In the upright tank's frame local X points up and
		-- local Y points to the character's left, hence the minus sign for the outward offset.
		local hoseAnchor = Instance.new("Attachment")
		hoseAnchor.Name = JetpackConfig.HOSE_ANCHOR_NAME
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
	hose.Segments = 8
	hose.FaceCamera = true
	hose.Color = ColorSequence.new(JetpackConfig.HOSE_COLOR)
	hose.LightInfluence = 1
	hose.Parent = grip
end

-- Attaches the jetpack of `level` to `character`. Returns nil (with a warning) for rigs it
-- cannot fit.
function JetpackModel.attach(character: Model, level: number): Model?
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

	local jetpack = JetpackLooks.jetpackOf(level)
	local model = Instance.new("Model")
	model.Name = JetpackConfig.MODEL_NAME
	model:SetAttribute(JetpackConfig.JETPACK_ATTRIBUTE, jetpack)
	local source = template(jetpack)
	local hoseAnchors = if source
		then buildFromTemplate(model, torso, source)
		else buildGreybox(model, torso, JetpackLooks.forLevel(level))
	-- Right hand hoses to the right side of the pack (+X), left hand to the left one.
	local right, left = hoseAnchors[1], hoseAnchors[-1]
	if right and left then
		buildGrip(model, rightHand, right)
		buildGrip(model, leftHand, left)
	end
	model.Parent = character
	return model
end

-- Puts the jetpack of `level` on `character` in place of the one it wears, if that is another
-- jetpack (both marks of a jetpack look the same).
function JetpackModel.update(character: Model, level: number)
	local current = character:FindFirstChild(JetpackConfig.MODEL_NAME)
	if not current or not current:IsA("Model") then
		return
	end
	if current:GetAttribute(JetpackConfig.JETPACK_ATTRIBUTE) == JetpackLooks.jetpackOf(level) then
		return
	end
	current:Destroy()
	JetpackModel.attach(character, level)
end

return table.freeze(JetpackModel)
