--!strict
-- Builds one of the station's capsule kiosks (decision 087): three meshes by material from the kit
-- (World/StationKit) — the pearl egg-shell open at the front with its antennae and counter, the
-- dark base and inside, and everything glowing in the kiosk's colour (the ring under the base, the
-- band, the counter's strip, the antennae's tips, the badge's ring, the plate's frame) — plus the
-- name plate, the badge's disc and the hologram plate in the opening, which each client draws on
-- (KioskController), and a point at the counter holding the prompt. Without the kit the kiosk
-- stands in greybox: base, glowing ring, counter, plate.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local StationKit = require(script.Parent.StationKit)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local StationShape = require(ReplicatedStorage.Shared.Config.StationShape)

local SCALE = StationShape.SCALE
local KIOSK = StationLooks.KIOSK

local KioskModel = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = material
	return result
end

-- Static: anchored, never touched or queried; only the bulk collides, and only the shell casts a
-- shadow (decoration stays cheap on slow devices).
local function settle(item: BasePart, collides: boolean, shadow: boolean, model: Model)
	item.Anchored = true
	item.CanTouch = false
	item.CanQuery = false
	item.CanCollide = collides
	item.CastShadow = shadow
	item.Parent = model
end

-- A flat disc on the floor at `frame`, `height` high.
local function disc(
	name: string,
	frame: CFrame,
	radius: number,
	height: number,
	color: Color3,
	material: Enum.Material
): Part
	local result = part(
		name,
		Vector3.new(height, radius * 2, radius * 2),
		frame * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	result.Shape = Enum.PartType.Cylinder
	return result
end

-- The kit piece `id` for the kiosk at `frame`, named and coloured; nil without the kit.
local function mesh(id: StationKit.PieceId, frame: CFrame, color: Color3, material: Enum.Material): MeshPart?
	local piece = StationKit.piece(id, SCALE)
	if piece then
		piece.Name = id
		piece.CFrame = StationKit.place(id, frame, SCALE)
		piece.Color = color
		piece.Material = material
	end
	return piece
end

-- The kiosk `kiosk` standing at `frame` (on the floor, its front along the frame's -Z).
function KioskModel.build(kiosk: StationLooks.Kiosk, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `Kiosk{kiosk.id}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- The bulk the prompt's point hangs on: the pearl, or the greybox counter.
	local holder: BasePart
	local pearl = mesh("KioskPearl", frame, StationLooks.PEARL_COLOR, StationLooks.PEARL_MATERIAL)
	if pearl then
		settle(pearl, true, true, model)
		holder = pearl
	else
		local counter = part(
			"Counter",
			KIOSK.counterSize,
			frame * CFrame.new(KIOSK.counterCenter),
			StationLooks.PEARL_COLOR,
			StationLooks.PEARL_MATERIAL
		)
		settle(counter, true, false, model)
		holder = counter
	end
	local dark: BasePart = mesh("KioskDark", frame, StationLooks.NAVY_COLOR, Enum.Material.SmoothPlastic)
		or disc("Base", frame, KIOSK.baseRadius, KIOSK.baseHeight, StationLooks.NAVY_COLOR, Enum.Material.SmoothPlastic)
	settle(dark, true, false, model)
	local glow: BasePart = mesh("KioskGlow", frame, kiosk.color, Enum.Material.Neon)
		or disc("Glow", frame, KIOSK.glowRadius, KIOSK.glowHeight, kiosk.color, Enum.Material.Neon)
	settle(glow, false, false, model)

	-- The prompt, on a point over the counter's front edge. Its texts are set by each client in its
	-- own language, and the client draws it in the same style as the egg prompt
	-- (PromptViewController).
	local point = Instance.new("Attachment")
	point.Name = ShopConfig.PROMPT_POINT_NAME
	point.Parent = holder
	point.WorldCFrame = frame
		* CFrame.new(
			KIOSK.counterCenter
				+ Vector3.new(0, KIOSK.counterSize.Y / 2 + KIOSK.promptAboveCounter, -KIOSK.counterSize.Z / 2)
		)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.MaxActivationDistance = StationLooks.KIOSK_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = point

	-- The hologram in the opening, lit in the kiosk's colour.
	local holo = part(
		StationLooks.KIOSK_HOLO_NAME,
		KIOSK.holoSize,
		frame * CFrame.new(KIOSK.holoCenter),
		kiosk.color,
		Enum.Material.SmoothPlastic
	)
	holo.Transparency = KIOSK.holoTransparency
	settle(holo, false, false, model)
	local light = Instance.new("PointLight")
	light.Color = kiosk.color
	light.Range = KIOSK.lightRange
	light.Brightness = KIOSK.lightBrightness
	light.Shadows = false
	light.Parent = holo

	-- The badge's disc inside its glowing ring. A cylinder runs along X: turned a quarter about Y,
	-- its Right face looks out of the front.
	local badge = part(
		StationLooks.KIOSK_BADGE_NAME,
		Vector3.new(KIOSK.badgeThickness, KIOSK.badgeRadius * 2, KIOSK.badgeRadius * 2),
		frame
			* CFrame.new(KIOSK.badgeCenter + Vector3.new(0, 0, KIOSK.badgeThickness))
			* CFrame.Angles(0, math.rad(90), 0),
		StationLooks.NAVY_COLOR,
		Enum.Material.SmoothPlastic
	)
	badge.Shape = Enum.PartType.Cylinder
	settle(badge, false, false, model)

	-- The name plate in front of its glowing frame.
	local plateFrame = frame * CFrame.new(KIOSK.plateCenter)
	local plate: BasePart = mesh("LabelPlate", plateFrame, StationLooks.NAVY_COLOR, Enum.Material.SmoothPlastic)
		or part("LabelPlate", KIOSK.plateSize, plateFrame, StationLooks.NAVY_COLOR, Enum.Material.SmoothPlastic)
	plate.Name = StationLooks.KIOSK_PLATE_NAME
	settle(plate, false, false, model)

	model.PrimaryPart = holder
	model:SetAttribute(StationLooks.KIOSK_ATTRIBUTE, kiosk.id)
	CollectionService:AddTag(model, StationLooks.KIOSK_TAG)
	return model
end

-- Where kiosk place `slot` stands: on the platform's circle, its front looking in at the middle.
function KioskModel.frameAt(center: Vector3, slot: number): CFrame
	local angle = StationShape.kioskAngle(slot)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local position = center + direction * StationShape.KIOSK_CIRCLE_RADIUS
	return CFrame.lookAt(position, center)
end

return table.freeze(KioskModel)
