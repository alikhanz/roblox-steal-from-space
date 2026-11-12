--!strict
-- `lune run aliens <file>`: brings the pets' models from Studio into the repo, one file a kind:
-- assets/aliens/<kind>.rbxm, a Folder <kind> with its ten pets <kind>-<variant> (tiers 0-4, then
-- m0-m4 for the meteor ones). World/AlienModel dresses a pet when it is placed
-- (docs/design/BLENDER_ROBLOX.md, "Into the game").
--
-- The files go into the place by hand, not through Rojo: live sync drops the meshes of MeshParts
-- (rojo-rbx/rojo#1221). The script also writes out/Aliens.rbxm, the folder Aliens with every
-- kind of assets/aliens. In Studio: delete ServerStorage.Aliens, select ServerStorage, File →
-- Import Roblox Model → out/Aliens.rbxm (one kind: its own file into Aliens, its old folder
-- deleted first; the file dialog takes one file at a time). Each folder carries a
-- fingerprint of its file (attribute ModelHash), and src/server/World/AlienModels.json lists the
-- fingerprints the repo has: in Studio the game warns about kinds missing from the place or out of
-- date.
--
-- `<file>` is a model or place saved from Studio (Save to File). Everything in it that is either
--   * a pack straight from the Blender export (a Model named `pack-<kind>` or `<kind>`, its
--     MeshParts named `<variant>|<role>_<n>|<paint>` and `<variant>|meta1|…`, `meta2|…`), or
--   * a kind's pets already unpacked in Studio (a Folder `<kind>` of Models `<kind>-<variant>`
--     with a Zone attribute; dressed ones are stripped back to the bare model)
-- is written out. Only what the model is made of is kept: the parts, their Paint and Role, the
-- pet's data in attributes, and Blender's marker parts turned into points (attachments: the hinges
-- moving parts turn on, the fairy dust points on the wings; markersToPoints). The dressing (paint, light,
-- particles, comets, the rune and the medal) is the game's code, so it is not saved here.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ModelPack = require("./lib/ModelPack")
local Shell = require("./lib/Shell")

local Instance = roblox.Instance
-- @lune/roblox has the datatypes at run time, but its type definitions do not list them.
local CFrame = (roblox :: any).CFrame

type Instance = roblox.Instance

local OUT_DIR = "assets/aliens"
local MANIFEST = "src/server/World/AlienModels.json"
-- Every kind in one file, for the place.
local BUNDLE = "out/Aliens.rbxm"
local VARIANTS = { "0", "1", "2", "3", "4", "m0", "m1", "m2", "m3", "m4" }
-- The pet's data the dressing reads (unpack below writes them from the meta markers).
local PET_ATTRIBUTES = { "Zone", "Family", "Tier", "Meteor", "Signature", "Glow", "Core", "TierColor", "Shell" }
-- What the dressing adds: dropped (the dressing makes it anew each time).
local DRESS_CLASSES = {
	ParticleEmitter = true,
	PointLight = true,
	SurfaceGui = true,
	BillboardGui = true,
	ImageLabel = true,
	SurfaceAppearance = true,
}
-- Plain parts the dressing adds: the effects carrier, the rune circle, the comets.
local function isDressPart(instance: Instance): boolean
	return instance.ClassName == "Part"
		and (instance.Name == "Fx" or instance.Name == "Halo" or string.match(instance.Name, "^Wisp") ~= nil)
end

-- A point the game reads, kept as an attachment: it scales with the pet (Model:ScaleTo) and needs
-- no mesh. Hinge points are named after their marker's role (`hingeJawL`), fairy dust points `Dust`.
local function isPoint(instance: Instance): boolean
	return instance.ClassName == "Attachment"
		and (
			instance.Name == "Dust"
			or string.match(instance.Name, "^hinge") ~= nil
			or string.match(instance.Name, "^anchor") ~= nil
		)
end

-- Strips a dressed pet back to its model.
local function strip(pet: Instance)
	for _, instance in pet:GetDescendants() do
		if instance.Parent == nil then
			continue
		end
		-- Attachments go too (the wing tip's sparkles), but the points stay (hinges, fairy dust).
		local added = DRESS_CLASSES[instance.ClassName]
			or isDressPart(instance)
			or (instance.ClassName == "Attachment" and not isPoint(instance))
		if added then
			instance:Destroy()
		end
	end
	ModelPack.markersToPoints(pet)
	for _, part in pet:GetDescendants() do
		if part.ClassName == "MeshPart" then
			ModelPack.bare(part)
		end
	end
end

-- Unpacks a pack from the Blender export into its ten pets (as the prototype's unpack.luau did in
-- Studio): parts renamed `<role>_<n>` with their paint code in Paint, the meta markers turned
-- into the pet's attributes and dropped. A pet's pivot is the centre of its box, turned like the
-- pack.
local function unpack(pack: Instance, kind: string): Instance
	local folder = Instance.new("Folder")
	folder.Name = kind
	local turn = ((pack :: any).WorldPivotData :: any).Rotation
	local pets: { [string]: Instance } = {}
	for _, part in pack:GetDescendants() do
		if part.ClassName ~= "MeshPart" then
			continue
		end
		local variant, rest = string.match(part.Name, "^([m%d]+)|(.+)$")
		if not variant or not rest then
			continue
		end
		local pet = pets[variant]
		if not pet then
			pet = Instance.new("Model")
			pet.Name = `{kind}-{variant}`
			pets[variant] = pet
		end
		local zone, family, tier, meteor, signature = string.match(rest, "^meta1|(%a+)|(%a+)|(%d)|(%a+)|([%w_%+]*)$")
		local glow, core, tierColor, shell = string.match(rest, "^meta2|([%d,]+)|([%d,]+)|([%d,]+)|([%d,]+)$")
		if zone then
			pet:SetAttribute("Zone", zone)
			pet:SetAttribute("Family", family)
			pet:SetAttribute("Tier", tonumber(tier))
			pet:SetAttribute("Meteor", meteor == "true")
			pet:SetAttribute("Signature", signature)
		elseif glow then
			pet:SetAttribute("Glow", glow)
			pet:SetAttribute("Core", core)
			pet:SetAttribute("TierColor", tierColor)
			pet:SetAttribute("Shell", shell)
		else
			local name, code = string.match(rest, "^([%w_]+)|(.+)$")
			assert(name and code, `{kind}: a part named {part.Name} has no role or paint`)
			part.Name = name
			part:SetAttribute("Paint", code)
			ModelPack.bare(part)
			part.Parent = pet
		end
	end
	for _, pet in pets do
		ModelPack.markersToPoints(pet)
		ModelPack.centrePivot(pet, turn)
		pet.Parent = folder
	end
	return folder
end

-- Low-poly packs (decision 118, assets/blender/lowpoly/export_lowpoly_roblox.py): each kind's body
-- once and the kit of outfit pieces. A kind's ten pets are its body ten times over, the same meshes:
-- grown to the tier as Blender grows a pet (the game divides it out, AlienLooks.MODELS.TIER_GROWTH),
-- the shell gold on a legendary and molten on a meteor. The outfit is the game's (World/AlienOutfit):
-- the body carries points for its slots (attachments `anchor<Slot>`, attribute Scale) and the kit
-- (folder OUTFIT_FOLDER) one model a piece, its pivot where it goes on such a point.
local OUTFIT_FOLDER = "_Outfit"
local TIERS = 5
local GROWTH = { 0.74, 0.86, 1.0, 1.14, 1.3 }
-- robo.TIER_COLORS in sRGB (the pets' TierColor).
local TIER_COLORS = { "218,221,229", "160,249,179", "137,203,255", "225,149,255", "255,221,108" }
local SHELL_SOURCES = { Shell = true, Candy = true, Crystal = true }
local GOLD_SHELL = "S255,190,45,0,0.35,Gold"
local LAVA_SHELL = "L89,31,13,0,0,Meteor"

local function isLowpolyPack(model: Instance): boolean
	for _, part in model:GetDescendants() do
		if part.ClassName == "MeshPart" and string.match(part.Name, "^kit|") then
			return true
		end
	end
	return false
end

-- A part `<role>_<n>|<code>` (the rest of its name after its owner): renamed, painted, bare.
local function takePart(part: Instance, rest: string, owner: string)
	local name, code = string.match(rest, "^([%w_]+)|(.+)$")
	assert(name and code, `{owner}: a part named {part.Name} has no role or paint`)
	part.Name = name
	part:SetAttribute("Paint", code)
	ModelPack.bare(part)
end

local function sourceOfCode(code: string): string
	return string.match(code, ",(%a*)$") or ""
end

-- `model` grown by `factor` round its pivot: parts, their sizes, the points on them and their scales.
local function grow(model: Instance, factor: number)
	local pivot = (model :: any).WorldPivotData
	for _, item in model:GetDescendants() do
		local part: any = item
		if part.ClassName == "MeshPart" then
			local here = pivot:ToObjectSpace(part.CFrame)
			part.CFrame = pivot * (CFrame.new(here.Position * factor) * here.Rotation)
			part.Size = part.Size * factor
		elseif part.ClassName == "Attachment" then
			local here = part.CFrame
			part.CFrame = CFrame.new(here.Position * factor) * here.Rotation
			local scale = part:GetAttribute("Scale")
			if type(scale) == "number" then
				part:SetAttribute("Scale", scale * factor)
			end
		end
	end
end

local function unpackLowpoly(pack: Instance): { Instance }
	local turn = ((pack :: any).WorldPivotData :: any).Rotation
	type Kind =
		{ body: Instance, meta1: string?, meta2: string?, anchors: { { slot: string, scale: number, at: any } } }
	local kinds: { [string]: Kind } = {}
	local kindOrder: { string } = {}
	local pieces: { [string]: { model: Instance, origin: any, dust: { { side: string, order: number, at: any } } } } =
		{}
	local pieceOrder: { string } = {}
	for _, part in pack:GetDescendants() do
		if part.ClassName ~= "MeshPart" then
			continue
		end
		local position = (part :: any).CFrame.Position
		local piece, pieceRest = string.match(part.Name, "^kit|(%w+)|(.+)$")
		if piece and pieceRest then
			local entry = pieces[piece]
			if not entry then
				local model = Instance.new("Model")
				model.Name = piece
				entry = { model = model, origin = nil, dust = {} }
				pieces[piece] = entry
				table.insert(pieceOrder, piece)
			end
			local side, order = string.match(pieceRest, "^dust([LR])(%d+)$")
			if pieceRest == "origin" then
				entry.origin = position
			elseif side then
				table.insert(entry.dust, { side = side, order = tonumber(order) :: number, at = position })
			else
				takePart(part, pieceRest, piece)
				part.Parent = entry.model
				continue
			end
			part:Destroy()
			continue
		end
		local kindId, rest = string.match(part.Name, "^(%a%w*)|(.+)$")
		if not kindId or not rest then
			continue
		end
		local kind = kinds[kindId]
		if not kind then
			local body = Instance.new("Model")
			body.Name = kindId
			kind = { body = body, meta1 = nil, meta2 = nil, anchors = {} } :: Kind
			kinds[kindId] = kind
			table.insert(kindOrder, kindId)
		end
		local slot, scale = string.match(rest, "^anchor|(%a+)|([%d%.]+)$")
		if string.match(rest, "^meta1|") then
			kind.meta1 = rest
		elseif string.match(rest, "^meta2|") then
			kind.meta2 = rest
		elseif slot then
			table.insert(kind.anchors, { slot = slot, scale = tonumber(scale) :: number, at = position })
		else
			takePart(part, rest, kindId)
			part.Parent = kind.body
			continue
		end
		part:Destroy()
	end

	local found: { Instance } = {}
	table.sort(kindOrder)
	for _, kindId in kindOrder do
		local kind = kinds[kindId]
		local zone, family, signature = string.match(kind.meta1 or "", "^meta1|(%a+)|(%a+)|([%w_%+]*)$")
		local glow, core, shell = string.match(kind.meta2 or "", "^meta2|([%d,]+)|([%d,]+)|([%d,]+)$")
		assert(zone and glow, `{kindId}: no meta markers`)
		-- The anchors' points sit on a body part that never moves: the shell.
		local holder: Instance? = nil
		for _, part in kind.body:GetChildren() do
			if part.ClassName == "MeshPart" and SHELL_SOURCES[ModelPack.sourceOf(part)] then
				holder = part
			end
		end
		assert(holder, `{kindId}: no shell to hold the outfit's points`)
		for _, anchor in kind.anchors do
			local point: any = Instance.new("Attachment")
			point.Name = `anchor{anchor.slot}`
			point.CFrame = (holder :: any).CFrame:ToObjectSpace(CFrame.new(anchor.at))
			point:SetAttribute("Scale", anchor.scale)
			point.Parent = holder
		end
		ModelPack.centrePivot(kind.body, turn)
		local folder = Instance.new("Folder")
		folder.Name = kindId
		for index = 1, TIERS * 2 do
			local tier = (index - 1) % TIERS
			local meteor = index > TIERS
			local pet = kind.body:Clone()
			pet.Name = `{kindId}-{if meteor then "m" else ""}{tier}`
			grow(pet, GROWTH[tier + 1])
			for _, part in pet:GetChildren() do
				local code = part:GetAttribute("Paint")
				if type(code) == "string" and SHELL_SOURCES[sourceOfCode(code)] then
					if meteor then
						part:SetAttribute("Paint", LAVA_SHELL)
					elseif tier == TIERS - 1 then
						part:SetAttribute("Paint", GOLD_SHELL)
					end
				end
			end
			pet:SetAttribute("Zone", zone)
			pet:SetAttribute("Family", family)
			pet:SetAttribute("Tier", tier)
			pet:SetAttribute("Meteor", meteor)
			pet:SetAttribute("Signature", signature)
			pet:SetAttribute("Glow", glow)
			pet:SetAttribute("Core", core)
			pet:SetAttribute("TierColor", TIER_COLORS[tier + 1])
			pet:SetAttribute("Shell", shell)
			pet:SetAttribute("Outfit", true)
			pet.Parent = folder
		end
		table.insert(found, folder)
	end

	local kit = Instance.new("Folder")
	kit.Name = OUTFIT_FOLDER
	table.sort(pieceOrder)
	for _, name in pieceOrder do
		local entry = pieces[name]
		assert(entry.origin, `outfit piece {name}: no origin marker`)
		for _, dust in entry.dust do
			for _, part in entry.model:GetChildren() do
				if
					ModelPack.roleOf(part.Name) == `wing{dust.side}` and string.match(ModelPack.sourceOf(part), "Wing$")
				then
					local point: any = Instance.new("Attachment")
					point.Name = "Dust"
					point.CFrame = (part :: any).CFrame:ToObjectSpace(CFrame.new(dust.at))
					point:SetAttribute("Order", dust.order)
					point.Parent = part
				end
			end
		end
		local model: any = entry.model
		model.WorldPivotData = CFrame.new(entry.origin) * turn
		entry.model.Parent = kit
	end
	table.insert(found, kit)
	return found
end

-- Checks a kind's folder: its ten pets, each with its data and parts.
local function check(folder: Instance): { string }
	local problems = {}
	for _, variant in VARIANTS do
		local pet = folder:FindFirstChild(`{folder.Name}-{variant}`)
		if not pet then
			table.insert(problems, `{folder.Name}: no pet {variant}`)
			continue
		end
		for _, attribute in PET_ATTRIBUTES do
			if pet:GetAttribute(attribute) == nil then
				table.insert(problems, `{pet.Name}: no {attribute}`)
			end
		end
		local parts = 0
		for _, part in pet:GetDescendants() do
			if part.ClassName == "MeshPart" then
				parts += 1
				if part:GetAttribute("Paint") == nil then
					table.insert(problems, `{pet.Name}: part {part.Name} has no Paint`)
				end
			end
		end
		if parts == 0 then
			table.insert(problems, `{pet.Name}: no parts`)
		end
	end
	return problems
end

-- Every kind in `roots`: packs to unpack, folders of pets to strip.
local function kindsIn(roots: { Instance }): { Instance }
	local found: { Instance } = {}
	local function visit(instance: Instance)
		if instance.ClassName == "Folder" and instance.Name == OUTFIT_FOLDER then
			table.insert(found, instance)
			return
		elseif instance.ClassName == "Folder" then
			local pet = instance:FindFirstChild(`{instance.Name}-0`)
			if pet and pet.ClassName == "Model" and pet:GetAttribute("Zone") ~= nil then
				for _, child in instance:GetChildren() do
					strip(child)
				end
				table.insert(found, instance)
				return
			end
		elseif instance.ClassName == "Model" then
			if isLowpolyPack(instance) then
				for _, folder in unpackLowpoly(instance) do
					table.insert(found, folder)
				end
				return
			end
			for _, part in instance:GetDescendants() do
				if part.ClassName == "MeshPart" and string.match(part.Name, "^[m%d]+|meta1|") then
					local kind = string.match(instance.Name, "^pack%-(%w+)$") or instance.Name
					table.insert(found, unpack(instance, kind))
					return
				end
			end
		end
		for _, child in instance:GetChildren() do
			visit(child)
		end
	end
	for _, root in roots do
		visit(root)
	end
	return found
end

local path = process.args[1]
if not path then
	Shell.fail("usage: lune run aliens <model or place saved from Studio>")
	process.exit(1)
end

local kinds = kindsIn(ModelPack.read(path))
if #kinds == 0 then
	Shell.fail(`no packs or pets found in {path}`)
	process.exit(1)
end
local failed = false
if not fs.isDir(OUT_DIR) then
	fs.writeDir(OUT_DIR)
end
local manifest = ModelPack.readManifest(MANIFEST)
for _, folder in kinds do
	local problems = if folder.Name == OUTFIT_FOLDER then {} else check(folder)
	if #problems > 0 then
		for _, problem in problems do
			Shell.fail(problem)
		end
		failed = true
		continue
	end
	local hash, bytes = ModelPack.fingerprint(folder)
	manifest[folder.Name] = hash
	fs.writeFile(`{OUT_DIR}/{folder.Name}.rbxm`, bytes)
	print(`{folder.Name}: {#folder:GetChildren()} pets, {math.floor(#bytes / 1024)} KB`)
end
ModelPack.writeManifest(MANIFEST, manifest)
print(`{BUNDLE}: {ModelPack.writeBundle(OUT_DIR, "Aliens", BUNDLE)} kinds`)
if failed then
	process.exit(1)
end
