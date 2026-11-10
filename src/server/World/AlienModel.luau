--!strict
-- Builds an alien for the bay: its kind's model from ServerStorage.Aliens (assets/aliens,
-- lune/aliens.luau), prepared by AlienDress (paint and materials; each client adds the effects
-- itself), at its own size (decision 068). Each kind and variant is prepared once and cloned after.
-- A kind whose model is not in the place stands as the greybox blob (a squat ball in its tier's
-- colour with two eyes): a new kind can be added to the registry before its model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienDress = require(ReplicatedStorage.Shared.World.AlienDress)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)

local AlienModel = {}

local MODELS = AlienLooks.MODELS
local FOLDER_NAME = "Aliens"
-- The fingerprint lune/aliens.luau gives each kind's folder; AlienModels.json lists the repo's.
local HASH_ATTRIBUTE = "ModelHash"
-- On a built alien: its pivot's height above the frame it stands on, studs.
local LIFT_ATTRIBUTE = "StandLift"
local GLOW_RANGE = 10
local GLOW_BRIGHTNESS = 1.5

-- A dressed pet, ready to clone: where its lowest visible point is under the pivot and how wide it
-- stands, studs at the dressing scale.
type Template = {
	model: Model,
	bottom: number,
	width: number,
}

-- Templates by `<kind>-<variant>`; false where the place has no model.
local templates: { [string]: Template | false } = {}
local missingWarned: { [string]: boolean } = {}

-- Decoration only: nothing collides with or queries an alien.
local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- The pet's name in its kind's folder: tiers 0-4, an "m" in front for the meteor ones.
local function petName(alien: AlienConfig.Alien): string
	local tier = AlienConfig.TIER_POSITIONS[alien.tier] - 1
	return `{alien.kind}-{if alien.variant == "Meteor" then "m" else ""}{tier}`
end

-- The lowest point and the widest span of the pet's visible parts, in its pivot's frame.
local function measure(model: Model): (number, number)
	local pivot = model:GetPivot()
	local low = Vector3.one * math.huge
	local high = -low
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") or part.Transparency >= 1 then
			continue
		end
		local frame = pivot:ToObjectSpace(part.CFrame)
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = frame * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	if low.Y == math.huge then
		return 0, 0
	end
	local span = high - low
	return low.Y, math.max(span.X, span.Z)
end

local function templateOf(alien: AlienConfig.Alien): Template?
	local name = petName(alien)
	local cached = templates[name]
	if cached ~= nil then
		return cached or nil
	end
	local folder = ServerStorage:FindFirstChild(FOLDER_NAME)
	local kind = folder and folder:FindFirstChild(alien.kind)
	local source = kind and kind:FindFirstChild(name)
	if not (source and source:IsA("Model")) then
		templates[name] = false
		if not missingWarned[alien.kind] then
			missingWarned[alien.kind] = true
			warn(`[AlienModel] No model for {name} in ServerStorage.{FOLDER_NAME}; the greybox stands in`)
		end
		return nil
	end
	local model = source:Clone()
	AlienDress.prepare(model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local bottom, width = measure(model)
	local template = { model = model, bottom = bottom, width = width }
	templates[name] = template
	return template
end

-- The pet's scale against its Blender model for an alien of `scale` (alien.scale, or the floor's
-- override): the game's growth with the tier's Blender growth taken out.
local function modelScale(alien: AlienConfig.Alien, scale: number): number
	return MODELS.SCALE * scale / MODELS.TIER_GROWTH[AlienConfig.TIER_POSITIONS[alien.tier]]
end

local function addEye(body: BasePart, side: number, scale: number, model: Model)
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = AlienLooks.EYE_SIZE * scale
	eye.Color = AlienLooks.EYE_COLOR
	eye.Material = Enum.Material.SmoothPlastic
	ghost(eye)
	eye.CFrame = body.CFrame * CFrame.new(side * body.Size.X * 0.22, body.Size.Y * 0.15, -body.Size.Z / 2 + 0.1 * scale)
	eye.Parent = model
end

-- The greybox blob, for a kind with no model yet.
local function greybox(alien: AlienConfig.Alien, cframe: CFrame, scale: number): Model
	local look = AlienLooks.TIERS[alien.tier]
	local size = AlienLooks.BODY_SIZE * scale
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.Color = look.color
	body.Material = if look.glow > 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	ghost(body)
	body.CFrame = cframe * CFrame.new(0, size.Y / 2, 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	if look.glow > 0 then
		local light = Instance.new("PointLight")
		light.Color = look.color
		-- Not grown with the alien: a giant's light would flood the whole station.
		light.Range = GLOW_RANGE * look.glow
		light.Brightness = GLOW_BRIGHTNESS * look.glow
		light.Parent = body
	end
	body.Parent = model
	addEye(body, -1, scale, model)
	addEye(body, 1, scale, model)
	model.PrimaryPart = body
	return model
end

-- How wide alien `alienId` stands on the floor at `scale` (its own by default), studs: what its
-- place on the island makes room for.
function AlienModel.widthOf(alienId: AlienConfig.AlienId, scaleOverride: number?): number
	local alien = assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
	local scale = scaleOverride or alien.scale
	local template = templateOf(alien)
	if not template then
		return AlienLooks.widthOf(scale)
	end
	return template.width * modelScale(alien, scale) / MODELS.DRESS_SCALE
end

-- `cframe` is where the alien stands: its lowest point at the frame's origin, facing the frame's
-- look direction. `scaleOverride` replaces its own size (aliens with no place stand small on the
-- island's floor).
function AlienModel.build(alienId: AlienConfig.AlienId, uid: number, cframe: CFrame, scaleOverride: number?): Model
	local alien = assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
	-- Bigger with every guardian and tier (decision 068).
	local scale = scaleOverride or alien.scale
	local template = templateOf(alien)
	local model: Model
	if template then
		model = template.model:Clone()
		local factor = modelScale(alien, scale)
		model:ScaleTo(factor)
		local ratio = factor / MODELS.DRESS_SCALE
		model:PivotTo(cframe * CFrame.new(0, -template.bottom * ratio, 0))
	else
		model = greybox(alien, cframe, scale)
	end
	model.Name = `Alien{uid}`
	model:SetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE, alienId)
	model:SetAttribute(BayConfig.ALIEN_UID_ATTRIBUTE, uid)
	-- One standing small on the floor is only its model: no effects, no motion (the client reads
	-- this; user, 2026-11-10).
	model:SetAttribute(BayConfig.ALIEN_PLAIN_ATTRIBUTE, scaleOverride ~= nil)
	-- How far its pivot stands above where it stands, for moving it later (AlienModel.place).
	model:SetAttribute(LIFT_ATTRIBUTE, cframe:PointToObjectSpace(model:GetPivot().Position).Y)
	model:SetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE, model:GetPivot())
	return model
end

-- Stands an alien built by AlienModel.build at `cframe` instead (the bay's layout moved it to
-- another place): a move, not a rebuild, so only its parts' positions go to the clients.
function AlienModel.place(model: Model, cframe: CFrame)
	local lift = tonumber(model:GetAttribute(LIFT_ATTRIBUTE)) or 0
	model:PivotTo(cframe * CFrame.new(0, lift, 0))
	model:SetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE, model:GetPivot())
end

-- In Studio: warns about kinds whose model the place lacks or holds out of date against the repo
-- (src/server/World/AlienModels.json, written by lune/aliens.luau), with how to bring them in.
function AlienModel.checkPlace(manifest: { [string]: string })
	if not RunService:IsStudio() then
		return
	end
	local folder = ServerStorage:FindFirstChild(FOLDER_NAME)
	local missing, stale = {}, {}
	for kindId in AlienConfig.KINDS do
		local expected = manifest[kindId]
		local kind = folder and folder:FindFirstChild(kindId)
		if not kind then
			if expected then
				table.insert(missing, kindId)
			end
		elseif expected and kind:GetAttribute(HASH_ATTRIBUTE) ~= expected then
			table.insert(stale, kindId)
		end
	end
	if #missing + #stale == 0 then
		return
	end
	table.sort(missing)
	table.sort(stale)
	warn(
		`[AlienModel] The place's alien models differ from the repo (missing: {table.concat(missing, ", ")};`
			.. ` out of date: {table.concat(stale, ", ")}). Bring them in from assets/aliens:`
			.. ` File → Import Roblox Model (docs/design/BLENDER_ROBLOX.md, "Into the game").`
	)
end

return table.freeze(AlienModel)
