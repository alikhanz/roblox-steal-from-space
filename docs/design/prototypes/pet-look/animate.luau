-- Client-side motion of the dressed robot pets in workspace.RoboPetGame (preview prototype, run in
-- a playtest via MCP). Parts move by their Role attribute (from the Blender export): the pet bobs
-- and sways, the ring stays on the floor, a rotor spins, drones circle the lead, orbits and rocks
-- turn round the centre, rays turn about the facing axis, beam wings flap by moving their tip
-- attachments, and the core light pulses. One BulkMoveTo per frame.
local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("RoboPetGame", 10)
pcall(function()
	RunService:UnbindFromRenderStep("PetAnim")
end)

local pets = {}
for index, model in folder:GetChildren() do
	local base = model:GetPivot()
	local cf = model:GetBoundingBox()
	local pet = {
		base = base,
		phase = index * 1.7,
		parts = {},
		offsets = {},
		roles = {},
		groups = {},
		tips = {},
		centre = base:PointToObjectSpace(cf.Position),
	}
	local sums = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local role = item:GetAttribute("Role") or "body"
			local offset = base:ToObjectSpace(item.CFrame)
			table.insert(pet.parts, item)
			table.insert(pet.offsets, offset)
			table.insert(pet.roles, role)
			sums[role] = sums[role] or { Vector3.zero, 0 }
			sums[role][1] += offset.Position
			sums[role][2] += 1
		elseif item:IsA("Attachment") and item:GetAttribute("Flap") then
			table.insert(pet.tips, { item, item.CFrame, item:GetAttribute("Flap") })
		elseif item:IsA("PointLight") then
			pet.light, pet.brightness = item, item.Brightness
		end
	end
	for role, sum in sums do
		pet.groups[role] = sum[1] / sum[2]
	end
	table.insert(pets, pet)
end

RunService:BindToRenderStep("PetAnim", Enum.RenderPriority.Last.Value - 1, function()
	local t = os.clock()
	local parts, frames = {}, {}
	for _, pet in pets do
		local ph = pet.phase
		local bob = pet.base
			* CFrame.new(0, math.sin(t * 2 + ph) * 0.45, 0)
			* CFrame.Angles(math.sin(t * 1.1 + ph) * 0.05, math.sin(t * 0.6 + ph) * 0.14, math.sin(t * 1.4 + ph) * 0.05)
		local c = CFrame.new(pet.centre)
		local cInv = c:Inverse()
		for i, part in pet.parts do
			local role, offset = pet.roles[i], pet.offsets[i]
			local frame
			if role == "ring" then
				frame = pet.base * offset
			elseif role == "rotor" then
				local rc = CFrame.new(pet.groups.rotor)
				frame = bob * rc * CFrame.Angles(0, t * 14, 0) * rc:Inverse() * offset
			elseif role == "orbit" then
				frame = bob * c * CFrame.Angles(0, t * 0.9, 0) * cInv * offset
			elseif role == "rays" then
				frame = bob * c * CFrame.Angles(0, 0, t * 0.5) * cInv * offset
			elseif role:match("^drone%d") then
				local n = tonumber(role:match("%d+"))
				frame = bob * c * CFrame.Angles(0, t * 1.3, 0) * cInv * CFrame.new(0, math.sin(t * 4 + n) * 0.35, 0) * offset
			else
				frame = bob * offset
			end
			table.insert(parts, part)
			table.insert(frames, frame)
		end
		for _, tip in pet.tips do
			local flap = math.sin(t * 7 + ph + tip[3] * 0.6)
			tip[1].CFrame = tip[2] * CFrame.new(0, flap * 0.9, flap * 0.3)
		end
		if pet.light then
			pet.light.Brightness = pet.brightness + math.sin(t * 3 + ph) * 0.4
		end
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
