--!strict
-- Builds the greybox alien: a squat blob in its tier's color with two eyes; top tiers glow.
-- Real models replace the parts later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)

local AlienModel = {}

local GLOW_RANGE = 10
local GLOW_BRIGHTNESS = 1.5

-- Decoration only: nothing collides with or queries an alien.
local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function addEye(body: BasePart, side: number, model: Model)
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = AlienLooks.EYE_SIZE
	eye.Color = AlienLooks.EYE_COLOR
	eye.Material = Enum.Material.SmoothPlastic
	ghost(eye)
	eye.CFrame = body.CFrame * CFrame.new(side * body.Size.X * 0.22, body.Size.Y * 0.15, -body.Size.Z / 2 + 0.1)
	eye.Parent = model
end

-- `cframe` is where the alien stands: its feet are at the frame's origin.
function AlienModel.build(alienId: AlienConfig.AlienId, uid: number, cframe: CFrame): Model
	local alien = assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
	local look = AlienLooks.TIERS[alien.tier]

	local model = Instance.new("Model")
	model.Name = `Alien{uid}`

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = AlienLooks.BODY_SIZE
	body.Color = look.color
	body.Material = if look.glow > 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	ghost(body)
	body.CFrame = cframe * CFrame.new(0, AlienLooks.BODY_SIZE.Y / 2, 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	if look.glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Range = GLOW_RANGE * look.glow
		light.Brightness = GLOW_BRIGHTNESS * look.glow
		light.Parent = body
	end
	body.Parent = model

	addEye(body, -1, model)
	addEye(body, 1, model)

	model.PrimaryPart = body
	model:SetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE, alienId)
	model:SetAttribute(BayConfig.ALIEN_UID_ATTRIBUTE, uid)
	return model
end

return table.freeze(AlienModel)
