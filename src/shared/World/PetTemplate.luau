--!strict
-- A pet ready to clone (decision 081): its kind's model (assets/aliens, lune/aliens.luau) in the
-- outfit it wears (World/OutfitDress, decisions 118, 121), prepared by AlienDress (paint and
-- materials) at the dressing scale, with where it stands and how big it is. The server makes these
-- from ServerStorage.Aliens for each pet's box and its room on the island (World/AlienModel); each
-- client makes them from its copy in ReplicatedStorage for the pets near it (AlienViewController,
-- decision 123). Both make them the same way, so a client's pet stands exactly in the server's box.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienDress = require(script.Parent.AlienDress)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AlienOutfit = require(ReplicatedStorage.Shared.Domain.AlienOutfit)
local OutfitDress = require(script.Parent.OutfitDress)

local PetTemplate = {}

local MODELS = AlienLooks.MODELS
-- The low-poly pets' outfit kit among the models (decision 118, lune/aliens.luau).
PetTemplate.OUTFIT_NAME = "_Outfit"
-- On a low-poly pet's model (a body the game dresses from the kit).
local OUTFIT_ATTRIBUTE = "Outfit"

-- A dressed pet, ready to clone: where its lowest visible point is under the pivot, how wide it
-- stands and how tall, studs at the dressing scale.
export type Template = {
	model: Model,
	bottom: number,
	width: number,
	height: number,
}

-- Templates made from one set of models: `find` gives a pet's model by its name (petName) and the
-- outfit kit by OUTFIT_NAME, or nil (on a client they come a little later than the pets' boxes).
-- `keep`: each template is kept for the next pet like it (the server measures them again and
-- again); a client makes each pet afresh and keeps nothing it does not show.
export type Cache = {
	find: (name: string) -> Instance?,
	keep: boolean,
	templates: { [string]: Template },
}

function PetTemplate.cache(find: (name: string) -> Instance?, keep: boolean): Cache
	return { find = find, keep = keep, templates = {} }
end

-- The pet's name in its kind's models: tiers 0-4, an "m" in front for the meteor ones.
function PetTemplate.petName(alien: AlienConfig.Alien): string
	local tier = AlienConfig.TIER_POSITIONS[alien.tier] - 1
	return `{alien.kind}-{if alien.variant == "Meteor" then "m" else ""}{tier}`
end

-- The lowest point, the widest span across and the height of the pet's visible parts, in its
-- pivot's frame.
local function measure(model: Model): (number, number, number)
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
		return 0, 0, 0
	end
	local span = high - low
	return low.Y, math.max(span.X, span.Z), span.Y
end

-- The pet `alien` in `picks`, from its model and the outfit kit in the cache's set. A
-- low-poly pet (decision 118) is its kind's body dressed in `picks` (Domain/AlienOutfit): one
-- template per set of pieces. Other pets come whole from Blender and ignore `picks`. Nil while the
-- set has no model of it, or no kit for a body that needs one (the second result: true then).
function PetTemplate.get(cache: Cache, alien: AlienConfig.Alien, picks: AlienOutfit.Picks): (Template?, boolean)
	local name = PetTemplate.petName(alien)
	local source = cache.find(name)
	if not (source and source:IsA("Model")) then
		return nil, false
	end
	local dressed = source:GetAttribute(OUTFIT_ATTRIBUTE) == true
	local key = if dressed then `{name}|{AlienOutfit.key(picks)}` else name
	local cached = cache.templates[key]
	if cached then
		return cached, false
	end
	local kit = if dressed then cache.find(PetTemplate.OUTFIT_NAME) else nil
	if dressed and not kit then
		return nil, true
	end
	local model = source:Clone()
	if kit then
		local tier = AlienConfig.TIER_POSITIONS[alien.tier] - 1
		OutfitDress.dress(model, kit, picks :: any, tier, alien.variant == "Meteor")
	end
	AlienDress.prepare(model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local bottom, width, height = measure(model)
	local template = { model = model, bottom = bottom, width = width, height = height }
	if cache.keep then
		cache.templates[key] = template
	end
	return template, false
end

-- The pet's scale against its Blender model for an alien of `scale` (alien.scale, or the shelf's):
-- the game's growth with the tier's Blender growth taken out.
function PetTemplate.modelScale(alien: AlienConfig.Alien, scale: number): number
	return MODELS.SCALE * scale / MODELS.TIER_GROWTH[AlienConfig.TIER_POSITIONS[alien.tier]]
end

-- Where a pet of `template` stands with its lowest point at `cframe`'s origin (facing its look),
-- at `scale`: its model's pivot.
function PetTemplate.pivotAt(template: Template, alien: AlienConfig.Alien, scale: number, cframe: CFrame): CFrame
	local ratio = PetTemplate.modelScale(alien, scale) / MODELS.DRESS_SCALE
	return cframe * CFrame.new(0, -template.bottom * ratio, 0)
end

-- `template`'s pet at `scale`, its pivot at `pivot` (PetTemplate.pivotAt), not parented: a copy of
-- a kept template, the template's own model otherwise.
function PetTemplate.build(
	cache: Cache,
	template: Template,
	alien: AlienConfig.Alien,
	scale: number,
	pivot: CFrame
): Model
	local model = if cache.keep then template.model:Clone() else template.model
	model:ScaleTo(PetTemplate.modelScale(alien, scale))
	model:PivotTo(pivot)
	return model
end

return table.freeze(PetTemplate)
