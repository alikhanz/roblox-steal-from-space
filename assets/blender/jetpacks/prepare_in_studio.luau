--!strict
-- Turns the inserted jetpack pack (export_jetpacks.py → Open Cloud → insert_asset) into the game's
-- templates, ServerStorage.Jetpacks.Jetpack<n> (decision 089, JetpackModel). Run in Studio, Edit
-- mode (Command Bar or MCP execute_luau), with the inserted asset at ServerStorage.JetpacksIn; then
-- save the place.
--
-- The pack's parts are named by export_jetpacks.py:
--   J<n>|Shell, J<n>|Metal, J<n>|Glow, J<n>|Glass  the body's meshes (kept, renamed to the class);
--   J<n>|Origin                                  the torso's centre: the template's pivot;
--   J<n>|Nozzle<k>                               a nozzle's exit: an Attachment NozzleExit.
-- Markers go once read. The pack is scaled to studs by the spacing of the origins (SPACING studs in
-- Blender), whatever unit the importer used.

local ServerStorage = game:GetService("ServerStorage")

local SPACING = 4 -- export_jetpacks.py
local MAX_PARTS = 4 -- export_jetpacks.py
local SOURCE = "JetpacksIn"
local TARGET = "Jetpacks"

local source = ServerStorage:FindFirstChild(SOURCE)
assert(source, `ServerStorage.{SOURCE} is missing: insert the pack there first`)

local bodies: { [number]: { BasePart } } = {}
local origins: { [number]: Vector3 } = {}
local nozzles: { [number]: { Vector3 } } = {}
for _, part in source:GetDescendants() do
	if not part:IsA("BasePart") then
		continue
	end
	local grade, what = string.match(part.Name, "^J(%d+)|(.+)$")
	local n = tonumber(grade)
	if not n or not what then
		continue
	end
	if what == "Origin" then
		origins[n] = part.Position
	elseif string.match(what, "^Nozzle") then
		nozzles[n] = nozzles[n] or {}
		table.insert(nozzles[n], part.Position)
	else
		part.Name = what
		bodies[n] = bodies[n] or {}
		table.insert(bodies[n], part)
	end
end
assert(origins[0] and origins[1], "the pack lacks its origin markers")
local unit = SPACING / (origins[1] - origins[0]).Magnitude
-- Insertion turns the pack about Y (it faces the camera). The row runs along Blender's +X, which
-- import puts on Roblox's −X; the turn that took −X onto the row is undone with the pivot.
local row = (origins[1] - origins[0]).Unit
local turn = CFrame.Angles(0, math.atan2(row.Z, -row.X), 0)
local link = source:FindFirstChildWhichIsA("PackageLink", true)
if link then
	link:Destroy()
end

local old = ServerStorage:FindFirstChild(TARGET)
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = TARGET

local count = 0
for n, parts in bodies do
	local origin = assert(origins[n], `jetpack {n} has no origin`)
	local model = Instance.new("Model")
	model.Name = `Jetpack{n}`
	for _, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if part:IsA("MeshPart") then
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end
		part.Parent = model
	end
	model.WorldPivot = CFrame.new(origin) * turn
	-- Into studs about the pivot (a plain resize: the stored scale stays 1).
	for _, part in parts do
		part.Size *= unit
		part.Position = origin + (part.Position - origin) * unit
	end
	-- The nozzles hang off the shell (every jetpack has one); a flame leaves along −Y (down).
	local shell = model:FindFirstChild("Shell") :: BasePart
	assert(shell, `jetpack {n} has no shell`)
	-- In the pivot's frame. The import loses a marker's place now and then (it lands on the origin:
	-- 4 of 32 on 2026-11-10); every jetpack is mirror-symmetric in X, so a lost nozzle is its pair's
	-- mirror.
	local exits: { Vector3 } = {}
	for _, at in nozzles[n] or {} do
		local here = (CFrame.new(origin) * turn):PointToObjectSpace(origin + (at - origin) * unit)
		if here.Magnitude > 0.05 then
			table.insert(exits, here)
		end
	end
	for _, here in table.clone(exits) do
		local mirror = Vector3.new(-here.X, here.Y, here.Z)
		local paired = false
		for _, other in exits do
			paired = paired or (other - mirror).Magnitude < 0.05
		end
		if not paired then
			table.insert(exits, mirror)
		end
	end
	for _, here in exits do
		local exit = Instance.new("Attachment")
		exit.Name = "NozzleExit"
		exit.Parent = shell
		exit.WorldCFrame = CFrame.new(origin) * turn * CFrame.new(here)
	end
	-- Stored at the origin of the world, so a clone's pivot is the torso's centre.
	model:PivotTo(CFrame.new())
	model.Parent = folder
	count += 1
end
folder.Parent = ServerStorage
source:Destroy()

-- Read the result back instead of trusting the insert (BLENDER_ROBLOX.md, section 7): every grade,
-- within the part budget, with its nozzles and a loaded mesh on every part.
local ContentProvider = game:GetService("ContentProvider")
local problems = {}
for n = 0, 11 do
	local model = folder:FindFirstChild(`Jetpack{n}`)
	if not model then
		table.insert(problems, `Jetpack{n} missing`)
		continue
	end
	local parts, exits, unloaded = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			parts += 1
			if ContentProvider:GetAssetFetchStatus(d.MeshId) ~= Enum.AssetFetchStatus.Success then
				unloaded += 1
			end
		elseif d:IsA("Attachment") and d.Name == "NozzleExit" then
			exits += 1
		end
	end
	print(`[Jetpacks] Jetpack{n}: {parts} parts, {exits} nozzles, {unloaded} meshes not loaded yet`)
	if parts == 0 or parts > MAX_PARTS then
		table.insert(problems, `Jetpack{n} has {parts} parts`)
	end
	if exits == 0 then
		table.insert(problems, `Jetpack{n} has no nozzles`)
	end
end
print(`[Jetpacks] {count} templates in ServerStorage.{TARGET}, unit {unit}`)
if #problems > 0 then
	warn(`[Jetpacks] {table.concat(problems, "; ")}`)
end
