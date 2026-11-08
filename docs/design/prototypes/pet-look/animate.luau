-- Client-side motion of the dressed robot pets in workspace.RoboPetGame (preview prototype, run in
-- a playtest via MCP). Parts move by their Role attribute: the pet bobs and sways; the rune circle
-- stays on the floor and turns; a rotor spins; drones circle the lead; rocks and planets orbit the
-- centre; each fairy wing opens and folds back on its hinge; comets fly tilted orbits (their trails
-- draw the arcs); a meteor's fan of rays spins; the core light pulses. One BulkMoveTo per frame.
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
		hinges = {},
		dustOpen = {},
		dustFold = {},
		spinning = {},
		beat = 0,
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
			-- A wing's hinge: the marker Blender puts at its exact root.
			if role == "hingeL" or role == "hingeR" then
				pet.hinges["wing" .. role:sub(-1)] = offset.Position
			end
		elseif item:IsA("PointLight") then
			pet.light, pet.brightness = item, item.Brightness
		elseif item:IsA("ParticleEmitter") and item.Name:match("^DustOpen") then
			table.insert(pet.dustOpen, item)
		elseif item:IsA("ParticleEmitter") and item.Name:match("^DustFold") then
			table.insert(pet.dustFold, item)
		elseif item:IsA("ImageLabel") and item:GetAttribute("Spin") then
			table.insert(pet.spinning, item)
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
		-- Wings open and fold back like a book on their hinges (a butterfly's beat), with a slight lift.
		local beat = math.sin(t * 5 + ph)
		local swing = 0.55 + 0.45 * beat
		-- Fairy dust off the wing edges at the fastest part of each stroke (the beat passes zero):
		-- forwards as the wings open (the beat falls), back as they fold (it rises).
		local stroke = if pet.beat > 0 and beat <= 0 then pet.dustOpen elseif pet.beat < 0 and beat >= 0 then pet.dustFold else nil
		if stroke then
			for _, dust in stroke do
				dust:Emit(if dust.Name:match("Star$") then 2 else 10)
			end
		end
		pet.beat = beat
		for i, part in pet.parts do
			local role, offset = pet.roles[i], pet.offsets[i]
			local frame
			if role == "ring" then
				frame = pet.base * offset
			elseif role == "halo" then
				frame = pet.base * CFrame.new(offset.Position) * CFrame.Angles(0, t * 0.35, 0)
			elseif role == "rotor" then
				local rc = CFrame.new(pet.groups.rotor)
				frame = bob * rc * CFrame.Angles(0, t * 14, 0) * rc:Inverse() * offset
			elseif role == "orbit" then
				frame = bob * c * CFrame.Angles(0, t * 0.9, 0) * cInv * offset
			elseif role == "rays" then
				frame = bob * c * CFrame.Angles(0, 0, t * 0.5) * cInv * offset
			elseif role == "wingL" or role == "wingR" then
				-- The side comes from where the hinge really is, not the role's name: the import turns
				-- the pet round, so Blender's left wing sits at +X here. As the beat rises the wing
				-- folds back (its edge sweeps to +Z, behind the pet) and lifts; as it falls, it opens.
				local hinge = CFrame.new(pet.hinges[role])
				local side = if pet.hinges[role].X > 0 then 1 else -1
				frame = bob * hinge * CFrame.Angles(0, -side * swing, side * 0.12 * beat) * hinge:Inverse() * offset
			elseif role == "wisp" then
				local tilt = part:GetAttribute("Tilt")
				local angle = t * (part:GetAttribute("Speed") or 1.6) + part:GetAttribute("Phase")
				frame = bob * c * CFrame.Angles(tilt, 0, tilt * 0.5) * CFrame.Angles(0, angle, 0) * CFrame.new(part:GetAttribute("Orbit"), 0, 0)
			elseif role:match("^drone%d") then
				local n = tonumber(role:match("%d+"))
				frame = bob * c * CFrame.Angles(0, t * 1.3, 0) * cInv * CFrame.new(0, math.sin(t * 4 + n) * 0.35, 0) * offset
			else
				frame = bob * offset
			end
			table.insert(parts, part)
			table.insert(frames, frame)
		end
		if pet.light then
			pet.light.Brightness = pet.brightness + math.sin(t * 3 + ph) * 0.4
		end
		-- The legendary medal of rays turns slowly, its two layers against each other.
		for _, image in pet.spinning do
			image.Rotation = t * image:GetAttribute("Spin")
		end
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
