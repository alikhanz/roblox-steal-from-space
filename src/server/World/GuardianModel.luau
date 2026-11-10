--!strict
-- Builds a guardian as the server has it: a greybox body in its kind's shape with two glowing eyes
-- at the front and the physics movers the service steers. Each client dresses it in its post's
-- model (World/GuardianVisual, GuardianLooks.MODELS) and hides the greybox; the greybox shows
-- only where the place has no model for the post.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)

local GuardianModel = {}

local EYE_SIZE = Vector3.new(0.8, 0.8, 0.4)

-- Ghost parts: guardians catch by distance, never by contact, so nothing collides or is queried.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function addEye(body: BasePart, side: number, model: Model)
	local eye = Instance.new("Part")
	eye.Name = GuardianConfig.EYE_NAME
	eye.Size = EYE_SIZE
	eye.Material = Enum.Material.Neon
	eye.Color = GuardianLooks.EYE_COLORS.Sleep
	eye.Massless = true
	ghost(eye)
	eye.CFrame = body.CFrame * CFrame.new(side * body.Size.X * 0.2, body.Size.Y * 0.15, -body.Size.Z / 2)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = eye
	weld.Parent = eye
	eye.Parent = model
end

local function addMovers(body: BasePart)
	local attachment = Instance.new("Attachment")

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = GuardianConfig.VELOCITY_NAME
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = GuardianConfig.MAX_FORCE
	velocity.VectorVelocity = Vector3.zero

	local align = Instance.new("AlignOrientation")
	align.Name = GuardianConfig.ALIGN_NAME
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = GuardianConfig.ALIGN_RESPONSIVENESS
	align.MaxTorque = GuardianConfig.MAX_FORCE

	attachment.Parent = body
	velocity.Parent = body
	align.Parent = body
end

function GuardianModel.build(kind: GuardianLooks.KindLook, look: GuardianLooks.PostLook): Model
	local model = Instance.new("Model")
	model.Name = "Guardian"

	local body = Instance.new("Part")
	body.Name = GuardianConfig.BODY_NAME
	body.Shape = kind.bodyShape
	body.Size = kind.bodySize * look.scale
	body.Color = look.color
	body.Material = Enum.Material.SmoothPlastic
	ghost(body)
	body.Parent = model

	addEye(body, -1, model)
	addEye(body, 1, model)
	addMovers(body)

	model.PrimaryPart = body
	return model
end

-- In Studio: warns about posts whose model the place lacks or holds out of date against the repo
-- (src/server/World/GuardianModels.json, written by lune/guardians.luau), with how to bring them
-- in. Quiet while the repo has no models yet.
function GuardianModel.checkPlace(manifest: { [string]: string })
	if not RunService:IsStudio() then
		return
	end
	local models = GuardianLooks.MODELS
	local folder = ReplicatedStorage:FindFirstChild(models.FOLDER_NAME)
	local missing, stale = {}, {}
	for _, post in GuardianConfig.POSTS do
		local expected = manifest[post.id]
		local model = folder and folder:FindFirstChild(post.id)
		if not expected then
			continue
		elseif not model then
			table.insert(missing, post.id)
		elseif model:GetAttribute(models.HASH_ATTRIBUTE) ~= expected then
			table.insert(stale, post.id)
		end
	end
	if #missing + #stale == 0 then
		return
	end
	warn(
		`[GuardianModel] The place's guardian models differ from the repo (missing: {table.concat(missing, ", ")};`
			.. ` out of date: {table.concat(stale, ", ")}). Bring them in: delete ReplicatedStorage.{models.FOLDER_NAME},`
			.. ` select ReplicatedStorage, File → Import Roblox Model → out/Guardians.rbxm (lune run guardians).`
	)
end

return table.freeze(GuardianModel)
