-- The pet gallery's client (preview prototype, a LocalScript in the PetGalleryGui ScreenGui that
-- gallery_server.luau hands each player): a bar at the top with the shown kind and buttons to step
-- through the kinds, a guardian (three kinds) at a time or one by one; and the pets' motion, the same
-- as animate.luau, rebuilt whenever the server swaps the pets.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local gui = script.Parent
local folder = workspace:WaitForChild("PetGallery")
local remote = ReplicatedStorage:WaitForChild("PetGalleryStep")

-- The bar.
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 48)
bar.Size = UDim2.fromOffset(760, 64)
bar.BackgroundColor3 = Color3.fromRGB(16, 18, 34)
bar.BackgroundTransparency = 0.15
bar.Parent = gui
Instance.new("UICorner").Parent = bar
local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(150, 0)
title.Size = UDim2.new(1, -300, 1, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Parent = bar
local function button(text: string, x: number, step: number)
	local b = Instance.new("TextButton")
	b.Position = UDim2.new(x, if x > 0.5 then -72 else 6, 0, 8)
	b.Size = UDim2.fromOffset(66, 48)
	b.BackgroundColor3 = Color3.fromRGB(60, 70, 140)
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Text = text
	b.Parent = bar
	Instance.new("UICorner").Parent = b
	b.Activated:Connect(function()
		remote:FireServer(step)
	end)
	return b
end
button("◀◀", 0, -3)
button("◀", 0.09, -1).Position = UDim2.fromOffset(78, 8)
button("▶", 1, 1).Position = UDim2.new(1, -144, 0, 8)
button("▶▶", 1, 3)
local titleValue = ReplicatedStorage:WaitForChild("PetGalleryTitle")
local function retitle()
	title.Text = titleValue.Value
end
titleValue.Changed:Connect(retitle)
retitle()

-- The motion (animate.luau): rebuilt from the pets in the folder.
local pets = {}
local function rebuild()
	pets = {}
	local meshes = {}
	for index, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
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
			images = {},
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
				if role == "hingeL" or role == "hingeR" then
					pet.hinges["wing" .. role:sub(-1)] = offset.Position
				end
				if item:IsA("MeshPart") then
					table.insert(meshes, item)
				end
			elseif item:IsA("PointLight") then
				pet.light, pet.brightness = item, item.Brightness
			elseif item:IsA("ParticleEmitter") and item.Name:match("^DustOpen") then
				table.insert(pet.dustOpen, item)
			elseif item:IsA("ParticleEmitter") and item.Name:match("^DustFold") then
				table.insert(pet.dustFold, item)
			elseif item:IsA("ImageLabel") and (item:GetAttribute("Spin") or item:GetAttribute("Sway")) then
				table.insert(pet.images, item)
			end
		end
		for role, sum in sums do
			pet.groups[role] = sum[1] / sum[2]
		end
		table.insert(pets, pet)
	end
	-- Many new meshes at once: ask for them all, or some stay unloaded (half a pet missing).
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, meshes)
	end)
end

local pending = false
local function soon()
	if pending then
		return
	end
	pending = true
	task.delay(0.5, function()
		pending = false
		rebuild()
	end)
end
-- Parts may still stream in after their pet (a pet left out of Atomic streaming): rebuild then too.
folder.DescendantAdded:Connect(function(item)
	if item:IsA("Model") or item:IsA("BasePart") then
		soon()
	end
end)
folder.ChildRemoved:Connect(soon)
rebuild()

RunService:BindToRenderStep("PetGallery", Enum.RenderPriority.Last.Value - 1, function()
	local t = os.clock()
	local parts, frames = {}, {}
	for _, pet in pets do
		local ph = pet.phase
		local bob = pet.base
			* CFrame.new(0, math.sin(t * 2 + ph) * 0.45, 0)
			* CFrame.Angles(math.sin(t * 1.1 + ph) * 0.05, math.sin(t * 0.6 + ph) * 0.14, math.sin(t * 1.4 + ph) * 0.05)
		local c = CFrame.new(pet.centre)
		local cInv = c:Inverse()
		local beat = math.sin(t * 5 + ph)
		-- Round the wings' 38° rest sweep: 21° to 55° back (animate.luau).
		local swing = 0.3 * beat
		local stroke = if pet.beat > 0 and beat <= 0
			then pet.dustOpen
			elseif pet.beat < 0 and beat >= 0 then pet.dustFold
			else nil
		if stroke then
			for _, dust in stroke do
				dust:Emit(if dust.Name:match("Star$") then 2 else 10)
			end
		end
		pet.beat = beat
		for i, part in pet.parts do
			if not part.Parent then
				continue
			end
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
			elseif (role == "wingL" or role == "wingR") and pet.hinges[role] then
				local hinge = CFrame.new(pet.hinges[role])
				local side = if pet.hinges[role].X > 0 then 1 else -1
				frame = bob * hinge * CFrame.Angles(0, -side * swing, side * 0.12 * beat) * hinge:Inverse() * offset
			elseif role == "wisp" then
				local tilt = part:GetAttribute("Tilt")
				local angle = t * (part:GetAttribute("Speed") or 1.6) + part:GetAttribute("Phase")
				frame = bob
					* c
					* CFrame.Angles(tilt, 0, tilt * 0.5)
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(part:GetAttribute("Orbit"), 0, 0)
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
		for _, image in pet.images do
			local spin = image:GetAttribute("Spin")
			image.Rotation = if spin then t * spin else math.sin(t * 0.8 + image:GetAttribute("Sway")) * 2
		end
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
