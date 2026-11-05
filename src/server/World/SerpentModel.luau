--!strict
-- Builds the greybox star serpent's head: a glowing block with two eyes at the front and the
-- physics movers SerpentService steers. Its body is drawn by the clients behind the head
-- (SerpentController). The real model replaces the parts later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentLooks = require(ReplicatedStorage.Shared.Config.SerpentLooks)

local SerpentModel = {}

-- Ghost parts: the serpent catches by distance, never by contact.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function addEye(head: BasePart, side: number, model: Model)
	local looks = SerpentLooks.HEAD
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = looks.eyeSize
	eye.Material = Enum.Material.Neon
	eye.Color = looks.eyeColor
	eye.Massless = true
	ghost(eye)
	eye.CFrame = head.CFrame * CFrame.new(side * head.Size.X * 0.3, head.Size.Y * 0.2, -head.Size.Z / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = eye
	weld.Parent = eye
	eye.Parent = model
end

local function addMovers(head: BasePart)
	local attachment = Instance.new("Attachment")

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = SerpentConfig.VELOCITY_NAME
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = SerpentConfig.MAX_FORCE
	velocity.VectorVelocity = Vector3.zero

	local align = Instance.new("AlignOrientation")
	align.Name = SerpentConfig.ALIGN_NAME
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = SerpentConfig.ALIGN_RESPONSIVENESS
	align.MaxTorque = SerpentConfig.MAX_FORCE

	attachment.Parent = head
	velocity.Parent = head
	align.Parent = head
end

function SerpentModel.build(): Model
	local looks = SerpentLooks.HEAD
	local model = Instance.new("Model")
	model.Name = SerpentConfig.MODEL_NAME
	-- Seen from anywhere on the map, however far it is: its pin is only an arrow.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local head = Instance.new("Part")
	head.Name = SerpentConfig.HEAD_NAME
	head.Size = looks.size
	head.Color = looks.color
	head.Material = Enum.Material.SmoothPlastic
	ghost(head)
	head.Parent = model

	local glow = Instance.new("PointLight")
	glow.Color = looks.glowColor
	glow.Range = looks.glowRange
	glow.Brightness = looks.glowBrightness
	glow.Parent = head

	addEye(head, -1, model)
	addEye(head, 1, model)
	addMovers(head)

	model.PrimaryPart = head
	return model
end

return table.freeze(SerpentModel)
