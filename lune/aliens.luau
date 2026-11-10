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
		and (instance.Name == "Dust" or string.match(instance.Name, "^hinge") ~= nil)
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
		if instance.ClassName == "Folder" then
			local pet = instance:FindFirstChild(`{instance.Name}-0`)
			if pet and pet.ClassName == "Model" and pet:GetAttribute("Zone") ~= nil then
				for _, child in instance:GetChildren() do
					strip(child)
				end
				table.insert(found, instance)
				return
			end
		elseif instance.ClassName == "Model" then
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
	local problems = check(folder)
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
