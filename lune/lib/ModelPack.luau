--!strict
-- What `lune run aliens` and `lune run guardians` share: unpacking a Blender export's parts into a
-- bare model (lean parts, Blender's marker parts turned into points), measuring it, fingerprinting
-- it, and the manifest of fingerprints the game checks the place against
-- (docs/design/BLENDER_ROBLOX.md, "Into the game").

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

-- @lune/roblox has the datatypes at run time, but its type definitions do not list them.
local CFrame = (roblox :: any).CFrame
local Vector3 = (roblox :: any).Vector3
local Enum = (roblox :: any).Enum
local Instance = roblox.Instance

type Instance = roblox.Instance

local ModelPack = {}

-- The attribute a model's folder carries its fingerprint in.
ModelPack.HASH_ATTRIBUTE = "ModelHash"

-- A part's eight corners in `frame`'s space, folded into `low`/`high`.
function ModelPack.grow(frame: any, part: any, low: any, high: any): (any, any)
	local local_ = frame:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = local_ * Vector3.new(half.X * x, half.Y * y, half.Z * z)
				low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
				high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
			end
		end
	end
	return low, high
end

-- Sets `model`'s pivot to the centre of its parts' box, turned by `turn`.
function ModelPack.centrePivot(model: Instance, turn: any)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local frame = CFrame.new() * turn
	for _, part in model:GetChildren() do
		if part.ClassName == "MeshPart" then
			low, high = ModelPack.grow(frame, part, low, high)
		end
	end
	local centre = frame * ((low + high) / 2);
	(model :: any).WorldPivotData = CFrame.new(centre) * turn
end

-- Decoration needs no collision geometry (nothing touches or queries it): a box keeps the file
-- small (the hull data was most of it) and the physics light.
function ModelPack.bare(part: any)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CollisionFidelity = Enum.CollisionFidelity.Box
	part.PhysicalConfigData = ""
end

-- A part's role: its name before its number (`wingL_12` → wingL, `drone2_41` → drone2).
function ModelPack.roleOf(name: string): string
	return string.match(name, "^(.-)_%d+$") or name
end

-- The Blender material a part's paint code names (`…,GoldWing` → GoldWing).
function ModelPack.sourceOf(part: Instance): string
	local code = part:GetAttribute("Paint")
	return if type(code) == "string" then string.match(code, ",(%a*)$") or "" else ""
end

-- Blender's marker parts become points (attachments): a hinge marker `hinge<X>` (the pivot a wing,
-- a jaw, a leg or a fin turns on) a point of that name on a part of the body that never moves; a
-- fairy dust marker `dust<L|R><n>` a point `Dust` on its wing's membrane (so it flaps with it). A
-- marker is a MeshPart all the same: a mesh to download and a part to send, ~12 a pet (8654 of the
-- 720 pets' 35379 parts; 2026-11-10). The motion and the dressing read the points.
function ModelPack.markersToPoints(model: Instance)
	local anchor: any = nil
	local membranes: { [string]: any } = {}
	local hinges: { [string]: { any } } = {}
	local hingeOrder: { string } = {}
	local dusts: { any } = {}
	for _, part in model:GetDescendants() do
		if part.ClassName ~= "MeshPart" then
			continue
		end
		local role = ModelPack.roleOf(part.Name)
		if string.match(role, "^hinge") then
			if not hinges[role] then
				hinges[role] = {}
				table.insert(hingeOrder, role)
			end
			table.insert(hinges[role], part)
		elseif string.match(role, "^dust[LR]") then
			table.insert(dusts, part)
		elseif (role == "wingL" or role == "wingR") and string.match(ModelPack.sourceOf(part), "Wing$") then
			membranes[role] = membranes[role] or part
		elseif role == "body" and not anchor then
			anchor = part
		end
	end
	table.sort(hingeOrder)
	for _, role in hingeOrder do
		local parts = hinges[role]
		assert(anchor, `{model.Name}: a hinge marker but no body part to hold its point`)
		local sum = Vector3.new(0, 0, 0)
		for _, part in parts do
			-- Lune keeps a part's CFrame, not its Position (a derived property).
			sum += (part :: any).CFrame.Position
		end
		local point = Instance.new("Attachment")
		point.Name = role;
		(point :: any).CFrame = anchor.CFrame:ToObjectSpace(CFrame.new(sum / #parts))
		point.Parent = anchor
		for _, part in parts do
			part:Destroy()
		end
	end
	for _, marker in dusts do
		local host = membranes["wing" .. string.sub(ModelPack.roleOf(marker.Name), 5, 5)]
		if host then
			local point = Instance.new("Attachment")
			point.Name = "Dust"
			(point :: any).CFrame = host.CFrame:ToObjectSpace(CFrame.new(marker.CFrame.Position))
			point.Parent = host
		end
		marker:Destroy()
	end
end

-- Fingerprints `folder` (alone, without its old fingerprint), stores the fingerprint on it and
-- returns it with the folder's bytes.
function ModelPack.fingerprint(folder: Instance): (string, string)
	folder.Parent = nil
	folder:SetAttribute(ModelPack.HASH_ATTRIBUTE, nil)
	local hash = string.sub(serde.hash("sha256", roblox.serializeModel({ folder })), 1, 16)
	folder:SetAttribute(ModelPack.HASH_ATTRIBUTE, hash)
	return hash, roblox.serializeModel({ folder })
end

function ModelPack.readManifest(path: string): { [string]: string }
	return if fs.isFile(path) then serde.decode("json", fs.readFile(path)) else {}
end

-- The manifest as the repo keeps it: sorted, one line a model, stable byte for byte.
function ModelPack.writeManifest(path: string, manifest: { [string]: string })
	local names: { string } = {}
	for name in manifest do
		table.insert(names, name)
	end
	table.sort(names)
	local lines: { string } = {}
	for _, name in names do
		table.insert(lines, `\t"{name}": "{manifest[name]}"`)
	end
	fs.writeFile(path, "{\n" .. table.concat(lines, ",\n") .. "\n}\n")
end

-- Every `.rbxm` of `dir` in one folder named `name`, written to `path` (the file for the place).
function ModelPack.writeBundle(dir: string, name: string, path: string): number
	local bundle = Instance.new("Folder")
	bundle.Name = name
	for _, file in fs.readDir(dir) do
		if string.match(file, "%.rbxm$") then
			for _, root in roblox.deserializeModel(fs.readFile(`{dir}/{file}`)) do
				root.Parent = bundle
			end
		end
	end
	if not fs.isDir("out") then
		fs.writeDir("out")
	end
	fs.writeFile(path, roblox.serializeModel({ bundle }))
	return #bundle:GetChildren()
end

-- The roots of a model or place file saved from Studio.
function ModelPack.read(path: string): { Instance }
	local source = fs.readFile(path)
	if string.match(path, "%.rbxlx?$") then
		return { roblox.deserializePlace(source) :: any }
	end
	return roblox.deserializeModel(source)
end

return table.freeze(ModelPack)
