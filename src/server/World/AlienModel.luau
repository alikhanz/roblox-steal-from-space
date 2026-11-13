--!strict
-- An alien in the bay (decision 068). The server stands only its box (decision 123): an invisible
-- part the size of the pet that the bay's label and prompts hang on, with attributes that tell the
-- clients what to build there. Each client builds the pet itself, only near it (AlienViewController,
-- World/PetTemplate), from copies of the models the server's pets need, which this module puts in
-- ReplicatedStorage.<AlienLooks.VIEW.FOLDER> from ServerStorage.Aliens (assets/aliens,
-- lune/aliens.luau). The server makes the same templates for the box's size and the pet's room.
-- A kind whose model is not in the place stands as the greybox blob (a squat ball in its tier's
-- colour with two eyes), built here: a new kind can be added to the registry before its model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AlienOutfit = require(ReplicatedStorage.Shared.Domain.AlienOutfit)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local PetTemplate = require(ReplicatedStorage.Shared.World.PetTemplate)

local AlienModel = {}

local MODELS = AlienLooks.MODELS
local VIEW = AlienLooks.VIEW
local FOLDER_NAME = "Aliens"
local OUTFIT_NAME = PetTemplate.OUTFIT_NAME
-- The fingerprint lune/aliens.luau gives each kind's folder; AlienModels.json lists the repo's.
local HASH_ATTRIBUTE = "ModelHash"
-- On a built alien: its pivot's height above the frame it stands on, studs.
local LIFT_ATTRIBUTE = BayConfig.ALIEN_LIFT_ATTRIBUTE
local GLOW_RANGE = 10
local GLOW_BRIGHTNESS = 1.5

local missingWarned: { [string]: boolean } = {}

-- A pet's model in the place by its name (`<kind>-<variant>` in its kind's folder), or the kit.
local function placeModel(name: string): Instance?
	local folder = ServerStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		return nil
	end
	if name == OUTFIT_NAME then
		return folder:FindFirstChild(OUTFIT_NAME)
	end
	local kind = folder:FindFirstChild(string.match(name, "^(.+)%-m?%d$") or name)
	return kind and kind:FindFirstChild(name)
end

local templates = PetTemplate.cache(placeModel, true)

-- The clients' copies of the models (VIEW.FOLDER): made on first use.
local shared: Folder? = nil

-- Copies `name`'s model (or the kit) from the place to the clients, once.
local function share(name: string)
	local folder = shared
	if not folder then
		local made = Instance.new("Folder")
		made.Name = VIEW.FOLDER
		made.Parent = ReplicatedStorage
		folder = made
		shared = made
	end
	assert(folder, "the clients' models folder")
	if folder:FindFirstChild(name) then
		return
	end
	local source = placeModel(name)
	if source then
		source:Clone().Parent = folder
	end
end

-- The template of `alien` in `picks`, or nil (the greybox stands in; told once a kind).
local function templateOf(alien: AlienConfig.Alien, picks: AlienOutfit.Picks): PetTemplate.Template?
	local template, kitMissing = PetTemplate.get(templates, alien, picks)
	if template then
		return template
	end
	local key = if kitMissing then OUTFIT_NAME else alien.kind
	if not missingWarned[key] then
		missingWarned[key] = true
		if kitMissing then
			warn(`[AlienModel] No ServerStorage.{FOLDER_NAME}.{OUTFIT_NAME}: low-poly pets stand as the greybox`)
		else
			warn(
				`[AlienModel] No model for {PetTemplate.petName(alien)} in ServerStorage.{FOLDER_NAME}; the greybox stands in`
			)
		end
	end
	return nil
end

-- The outfit a place makes room for: the first pieces of the tier's pools (wings for an epic).
local function roomPicks(alien: AlienConfig.Alien): AlienOutfit.Picks
	return AlienOutfit.first(AlienConfig.TIER_POSITIONS[alien.tier])
end

-- Decoration only: nothing collides with or queries an alien.
local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
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

-- The pet's box, where a client's pet built from `template` at `scale` with its pivot at `pivot`
-- stands: the template's own box (AlienDress's Body), grown with it. The box model's pivot is the
-- pet's.
local function box(template: PetTemplate.Template, alien: AlienConfig.Alien, scale: number, pivot: CFrame): Model
	local source = template.model.PrimaryPart
	assert(source, "a prepared pet has its Body")
	local ratio = PetTemplate.modelScale(alien, scale) / MODELS.DRESS_SCALE
	local offset = template.model:GetPivot():ToObjectSpace(source.CFrame)
	local body = Instance.new("Part")
	body.Name = source.Name
	ghost(body)
	body.Transparency = 1
	body.Size = source.Size * ratio
	body.CFrame = pivot * CFrame.new(offset.Position * ratio) * offset.Rotation
	body.PivotOffset = body.CFrame:ToObjectSpace(pivot)
	local model = Instance.new("Model")
	body.Parent = model
	model.PrimaryPart = body
	return model
end

-- How wide alien `alienId` stands on the floor at `scale` (its own by default), studs: what its
-- place on the island makes room for.
function AlienModel.widthOf(alienId: AlienConfig.AlienId, scaleOverride: number?): number
	local alien = assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
	local scale = scaleOverride or alien.scale
	local template = templateOf(alien, roomPicks(alien))
	if not template then
		return AlienLooks.widthOf(scale)
	end
	return template.width * PetTemplate.modelScale(alien, scale) / MODELS.DRESS_SCALE
end

-- How tall alien `alienId` stands at `scale` (its own by default), studs: what a niche of the
-- shelf makes room for. The greybox ball is as tall as it is wide.
function AlienModel.heightOf(alienId: AlienConfig.AlienId, scaleOverride: number?): number
	local alien = assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
	local scale = scaleOverride or alien.scale
	local template = templateOf(alien, roomPicks(alien))
	if not template then
		return AlienLooks.widthOf(scale)
	end
	return template.height * PetTemplate.modelScale(alien, scale) / MODELS.DRESS_SCALE
end

-- `cframe` is where the alien stands: its lowest point at the frame's origin, facing the frame's
-- look direction. `scaleOverride` replaces its own size (aliens with no place stand small on the
-- island's floor). `outfit` is what a low-poly pet wears (its record's, decision 121); nil: nothing.
-- A pet's box (the clients build the pet in it), or the greybox blob.
function AlienModel.build(
	alienId: AlienConfig.AlienId,
	uid: number,
	cframe: CFrame,
	scaleOverride: number?,
	outfit: AlienOutfit.Picks?
): Model
	local alien = assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
	-- Bigger with every guardian and tier (decision 068).
	local scale = scaleOverride or alien.scale
	local picks: AlienOutfit.Picks = outfit or {}
	local template = templateOf(alien, picks)
	local model: Model
	if template then
		model = box(template, alien, scale, PetTemplate.pivotAt(template, alien, scale, cframe))
		-- What the clients build in it, from the models shared with them (the kit first: a client
		-- builds a dressed pet only once it has both).
		share(OUTFIT_NAME)
		share(PetTemplate.petName(alien))
		model:SetAttribute(VIEW.LOOK_ATTRIBUTE, true)
		model:SetAttribute(VIEW.SCALE_ATTRIBUTE, scale)
		model:SetAttribute(VIEW.OUTFIT_ATTRIBUTE, AlienOutfit.key(picks))
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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
	model:SetAttribute(BayConfig.ALIEN_SHOWN_AT_ATTRIBUTE, workspace:GetServerTimeNow())
	return model
end

-- Stands an alien built by AlienModel.build at `cframe` instead (the bay's layout moved it to
-- another place): a move, not a rebuild, so only its box's position goes to the clients.
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
	local kit = folder and folder:FindFirstChild(OUTFIT_NAME)
	if manifest[OUTFIT_NAME] and not kit then
		table.insert(missing, OUTFIT_NAME)
	elseif kit and manifest[OUTFIT_NAME] and kit:GetAttribute(HASH_ATTRIBUTE) ~= manifest[OUTFIT_NAME] then
		table.insert(stale, OUTFIT_NAME)
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
