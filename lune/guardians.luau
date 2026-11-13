--!strict
-- `lune run guardians <file>`: brings the guardians' models from Studio into the repo, one file a
-- post: assets/guardians/<Post>.rbxm, a Model <Post> (the GuardianConfig post id). The client
-- builds a guardian's look from it (World/GuardianVisual; docs/plans/GUARDIANS.md, steps 3-4).
--
-- The files go into the place by hand, not through Rojo (live sync drops the meshes of MeshParts,
-- rojo-rbx/rojo#1221), into ReplicatedStorage: the clients clone them. The script also writes
-- out/Guardians.rbxm, the folder Guardians with every post of assets/guardians. In Studio: delete
-- ReplicatedStorage.Guardians, select ReplicatedStorage, File → Import Roblox Model →
-- out/Guardians.rbxm, save the place. Each model carries a fingerprint of its file (attribute
-- ModelHash), and src/server/World/GuardianModels.json lists the fingerprints the repo has: in
-- Studio the server warns about posts missing from the place or out of date.
--
-- `<file>` is a model or place saved from Studio (Save to File) holding the pack straight from
-- the Blender export (assets/blender/guardians/export_guardians_roblox.py: a Model whose MeshParts
-- are named `<Post>|<role>_<n>|<paint>` and `<Post>|meta1|…`, `meta2|…`), or guardians already
-- unpacked (a Folder of Models with a Zone attribute). Only what a model is made of is kept: its
-- parts with their Paint, its data in attributes, Blender's marker parts turned into points.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ModelPack = require("./lib/ModelPack")
local Shell = require("./lib/Shell")

local Instance = roblox.Instance

type Instance = roblox.Instance

local OUT_DIR = "assets/guardians"
local MANIFEST = "src/server/World/GuardianModels.json"
local BUNDLE = "out/Guardians.rbxm"
local BUNDLE_NAME = "Guardians"
-- A guardian's data, from the export's meta markers.
local ATTRIBUTES = { "Zone", "Family", "Signature", "Glow", "Core", "Shell", "Eyes" }

-- Unpacks the export's pack into one Model a post: parts renamed `<role>_<n>` with their paint
-- code in Paint, the meta markers turned into the model's attributes. A model's pivot is the
-- centre of its box, turned like the pack.
local function unpack(pack: Instance): { Instance }
	local turn = ((pack :: any).WorldPivotData :: any).Rotation
	local models: { [string]: Instance } = {}
	local order: { string } = {}
	for _, part in pack:GetDescendants() do
		if part.ClassName ~= "MeshPart" then
			continue
		end
		local post, rest = string.match(part.Name, "^(%u%w+)|(.+)$")
		if not post or not rest then
			continue
		end
		local model = models[post]
		if not model then
			model = Instance.new("Model")
			model.Name = post
			models[post] = model
			table.insert(order, post)
		end
		local zone, family, signature = string.match(rest, "^meta1|(%a+)|(%a+)|([%w_%+]*)$")
		local glow, core, shell, eyes = string.match(rest, "^meta2|(%x+)|(%x+)|(%x+)|(%x+)$")
		if zone then
			model:SetAttribute("Zone", zone)
			model:SetAttribute("Family", family)
			model:SetAttribute("Signature", signature)
		elseif glow then
			model:SetAttribute("Glow", glow)
			model:SetAttribute("Core", core)
			model:SetAttribute("Shell", shell)
			model:SetAttribute("Eyes", eyes)
		else
			local name, code = string.match(rest, "^([%w_]+)|(.+)$")
			assert(name and code, `{post}: a part named {part.Name} has no role or paint`)
			part.Name = name
			part:SetAttribute("Paint", code)
			ModelPack.bare(part)
			part.Parent = model
		end
	end
	local found: { Instance } = {}
	for _, post in order do
		local model = models[post]
		ModelPack.markersToPoints(model)
		ModelPack.standInsToPoints(model)
		ModelPack.centrePivot(model, turn)
		table.insert(found, model)
	end
	return found
end

-- Checks a guardian's model: its data and painted parts.
local function check(model: Instance): { string }
	local problems = {}
	for _, attribute in ATTRIBUTES do
		if model:GetAttribute(attribute) == nil then
			table.insert(problems, `{model.Name}: no {attribute}`)
		end
	end
	local parts = 0
	for _, part in model:GetDescendants() do
		if part.ClassName == "MeshPart" then
			parts += 1
			if part:GetAttribute("Paint") == nil then
				table.insert(problems, `{model.Name}: part {part.Name} has no Paint`)
			end
		end
	end
	if parts == 0 then
		table.insert(problems, `{model.Name}: no parts`)
	end
	return problems
end

-- Every guardian in `roots`: packs to unpack, models already unpacked.
local function guardiansIn(roots: { Instance }): { Instance }
	local found: { Instance } = {}
	local function visit(instance: Instance)
		if instance.ClassName == "Model" then
			if instance:GetAttribute("Zone") ~= nil and instance:GetAttribute("Eyes") ~= nil then
				ModelPack.markersToPoints(instance)
				for _, part in instance:GetDescendants() do
					if part.ClassName == "MeshPart" then
						ModelPack.bare(part)
					end
				end
				table.insert(found, instance)
				return
			end
			for _, part in instance:GetDescendants() do
				if part.ClassName == "MeshPart" and string.match(part.Name, "^%u%w+|meta1|") then
					for _, model in unpack(instance) do
						table.insert(found, model)
					end
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
	Shell.fail("usage: lune run guardians <model or place saved from Studio>")
	process.exit(1)
end

local guardians = guardiansIn(ModelPack.read(path))
if #guardians == 0 then
	Shell.fail(`no guardian pack or models found in {path}`)
	process.exit(1)
end
local failed = false
if not fs.isDir(OUT_DIR) then
	fs.writeDir(OUT_DIR)
end
local manifest = ModelPack.readManifest(MANIFEST)
for _, model in guardians do
	local problems = check(model)
	if #problems > 0 then
		for _, problem in problems do
			Shell.fail(problem)
		end
		failed = true
		continue
	end
	local hash, bytes = ModelPack.fingerprint(model)
	manifest[model.Name] = hash
	fs.writeFile(`{OUT_DIR}/{model.Name}.rbxm`, bytes)
	print(`{model.Name}: {#model:GetChildren()} parts, {math.floor(#bytes / 1024)} KB`)
end
ModelPack.writeManifest(MANIFEST, manifest)
print(`{BUNDLE}: {ModelPack.writeBundle(OUT_DIR, BUNDLE_NAME, BUNDLE)} guardians`)
if failed then
	process.exit(1)
end
