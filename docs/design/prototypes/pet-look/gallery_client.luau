-- The pet gallery's client (preview prototype, a LocalScript in the PetGalleryGui ScreenGui that
-- gallery_server.luau hands each player): a bar at the top with the shown kind and buttons to step
-- through the kinds, a guardian (three kinds) at a time or one by one; and the pets' motion, the same
-- as animate.luau, rebuilt whenever the server swaps the pets.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
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

-- The motion (animate.luau): rebuilt from the pets in the folder. On top of the shared bob and sway,
-- each family moves its own way (a slime wobbles like jelly and hops, a crab snaps its claws), every
-- pet blinks and turns to a player close by, each on its own rhythm.

-- A slime's jelly: how far it squashes and stretches at rest (a share of its height), and how high
-- a hop goes (a share of the pet's height) every few seconds.
local JELLY_REST = 0.035
local HOP_HEIGHT = 0.12
-- A crab's jaws open this far (radians) before they snap shut; now and then a double snap.
local JAW_OPEN = 0.45
-- A pet turns to a player this close (studs), at most this far (radians) from where it faces.
local LOOK_RADIUS = 40
local LOOK_LIMIT = math.rad(70)

local pets = {}
local function rebuild()
	pets = {}
	local meshes = {}
	for index, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local base = model:GetPivot()
		local cf, size = model:GetBoundingBox()
		local random = Random.new(index * 7919)
		local now = os.clock()
		local pet = {
			base = base,
			phase = index * 1.7,
			random = random,
			family = model:GetAttribute("Family"),
			parts = {},
			offsets = {},
			sizes = {},
			roles = {},
			eyes = {},
			groups = {},
			hinges = {},
			dustOpen = {},
			dustFold = {},
			images = {},
			beat = 0,
			yaw = 0,
			height = size.Y,
			centre = base:PointToObjectSpace(cf.Position),
			blinkAt = now + random:NextNumber(0.5, 4),
			hopAt = now + random:NextNumber(2, 8),
			jaws = {
				L = { nextAt = now + random:NextNumber(0.5, 3) },
				R = { nextAt = now + random:NextNumber(0.5, 3) },
			},
		}
		local sums = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				local role = item:GetAttribute("Role") or "body"
				local offset = base:ToObjectSpace(item.CFrame)
				table.insert(pet.parts, item)
				table.insert(pet.offsets, offset)
				table.insert(pet.sizes, item.Size)
				table.insert(pet.roles, role)
				local paint = item:GetAttribute("Paint") or ""
				-- The glowing eyes blink (a pet's eyes of one material are one part, at one height).
				pet.eyes[#pet.parts] = paint:match(",EyeLight$") ~= nil
				-- A slime's jelly starts a little above the bottom of its glass dome: the ceramic base
				-- and the feet under it stay solid.
				if paint:match(",Dome$") then
					pet.jellyFloor = offset.Position.Y - item.Size.Y * 0.3
				end
				sums[role] = sums[role] or { Vector3.zero, 0 }
				sums[role][1] += offset.Position
				sums[role][2] += 1
				if role == "hingeL" or role == "hingeR" then
					pet.hinges["wing" .. role:sub(-1)] = offset.Position
				elseif role == "hingeJawL" or role == "hingeJawR" then
					pet.hinges["jaw" .. role:sub(-1)] = offset.Position
				elseif role:match("^hingeLeg[LR]%u$") then
					-- A crab leg's hip, under the leg's own role name (hingeLegLA → legLA).
					pet.hinges["leg" .. role:sub(9)] = offset.Position
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

-- How far the eyes are open, 1 down to almost shut: a quick close and open every few seconds,
-- sometimes twice in a row.
local function eyeOpen(pet, t: number): number
	if t >= pet.blinkAt then
		pet.blinkStart = t
		pet.blinkTwice = pet.random:NextNumber() < 0.25
		pet.blinkAt = t + pet.random:NextNumber(2, 6)
	end
	local function once(s: number): number
		if s < 0 or s > 0.14 then
			return 1
		end
		return 1 - 0.9 * math.sin(s / 0.14 * math.pi)
	end
	local s = t - (pet.blinkStart or -100)
	return math.min(once(s), if pet.blinkTwice then once(s - 0.22) else 1)
end

-- How far a crab's jaw is open: it opens slowly, holds, snaps shut; sometimes twice in a row.
local function jawOpen(pet, jaw, t: number): number
	if t >= jaw.nextAt then
		jaw.start = t
		jaw.twice = pet.random:NextNumber() < 0.3
		jaw.nextAt = t + pet.random:NextNumber(1.8, 4.5)
	end
	local function once(s: number): number
		if s < 0 then
			return 0
		elseif s < 0.35 then
			return JAW_OPEN * math.sin(s / 0.35 * math.pi / 2)
		elseif s < 0.45 then
			return JAW_OPEN
		elseif s < 0.52 then
			return JAW_OPEN * (1 - (s - 0.45) / 0.07)
		end
		return 0
	end
	local s = t - (jaw.start or -100)
	return math.max(once(s), if jaw.twice then once(s - 0.6) else 0)
end

-- 0 to 1 with a gentle start and end.
local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- A slime's jelly this frame: how much taller than at rest it is (negative: squashed), and how
-- high its hop has lifted it. A hop crouches, pushes off stretched, rounds out in the air and lands
-- with a wobble that grows from nothing and dies away. Every phase starts where the last one ended:
-- a jump in the curve shows as a jerk.
local function jelly(pet, t: number): (number, number)
	local stretch = JELLY_REST * math.sin(t * 2.6 + pet.phase)
	local lift = 0
	if pet.hopStart then
		local s = t - pet.hopStart
		if s < 0.2 then
			stretch -= 0.12 * smooth(s / 0.2)
		elseif s < 0.35 then
			stretch += -0.12 + 0.22 * smooth((s - 0.2) / 0.15)
		elseif s < 0.8 then
			stretch += 0.1 * (1 - smooth((s - 0.35) / 0.45))
		else
			local d = s - 0.8
			stretch -= 0.15 * math.exp(-d * 3.5) * math.sin(d * 13)
			if d > 1.8 then
				pet.hopStart = nil
				pet.hopAt = t + pet.random:NextNumber(5, 10)
			end
		end
		if s > 0.28 and s < 0.8 then
			local u = (s - 0.28) / 0.52
			lift = HOP_HEIGHT * pet.height * 4 * u * (1 - u)
		end
	elseif t >= pet.hopAt then
		pet.hopStart = t
	end
	return stretch, lift
end

-- A frame squashed about the jelly's floor: up and down by `sy`, sideways by `sxz` round the
-- pet's centre line.
local function squashed(frame: CFrame, floor: number, centre: Vector3, sy: number, sxz: number): CFrame
	local p = frame.Position
	local moved = Vector3.new(centre.X + (p.X - centre.X) * sxz, floor + (p.Y - floor) * sy, centre.Z + (p.Z - centre.Z) * sxz)
	return frame - p + moved
end

-- A part's size under the squash: each of its own axes stretched by how much it points up or
-- sideways in the pet.
local function squashedSize(size: Vector3, frame: CFrame, sy: number, sxz: number): Vector3
	local function along(axis: Vector3): number
		local v = frame:VectorToWorldSpace(axis)
		return math.sqrt((v.X * sxz) ^ 2 + (v.Y * sy) ^ 2 + (v.Z * sxz) ^ 2)
	end
	return Vector3.new(size.X * along(Vector3.xAxis), size.Y * along(Vector3.yAxis), size.Z * along(Vector3.zAxis))
end

local last = os.clock()
RunService:BindToRenderStep("PetGallery", Enum.RenderPriority.Last.Value - 1, function()
	local t = os.clock()
	local dt = math.min(t - last, 0.1)
	last = t
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local parts, frames = {}, {}
	for _, pet in pets do
		local ph = pet.phase
		-- Turn to a player close by, smoothly, never further than LOOK_LIMIT (the pet faces -Z).
		local wanted = 0
		if root then
			local away = pet.base:PointToObjectSpace(root.Position)
			if Vector2.new(away.X, away.Z).Magnitude < LOOK_RADIUS then
				wanted = math.clamp(math.atan2(-away.X, -away.Z), -LOOK_LIMIT, LOOK_LIMIT)
			end
		end
		pet.yaw += (wanted - pet.yaw) * math.min(1, dt * 2.5)
		local stretch, lift = 0, 0
		if pet.family == "slime" and pet.jellyFloor then
			stretch, lift = jelly(pet, t)
		end
		local sy = 1 + stretch
		local sxz = 1 / math.sqrt(sy)
		local c = CFrame.new(pet.centre)
		local cInv = c:Inverse()
		local bob = pet.base
			* CFrame.new(0, math.sin(t * 2 + ph) * 0.45 + lift, 0)
			* c
			* CFrame.Angles(0, pet.yaw, 0)
			* cInv
			* CFrame.Angles(math.sin(t * 1.1 + ph) * 0.05, math.sin(t * 0.6 + ph) * 0.14, math.sin(t * 1.4 + ph) * 0.05)
		local beat = math.sin(t * 5 + ph)
		-- From the wings' 38° rest sweep: 11° to 45° back (animate.luau).
		local swing = -0.17 + 0.3 * beat
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
		local open = eyeOpen(pet, t)
		local jaws = {
			L = if pet.hinges.jawL then jawOpen(pet, pet.jaws.L, t) else 0,
			R = if pet.hinges.jawR then jawOpen(pet, pet.jaws.R, t) else 0,
		}
		for i, part in pet.parts do
			if not part.Parent then
				continue
			end
			local role, offset = pet.roles[i], pet.offsets[i]
			-- Where the part sits in the pet's own space this frame; nil for the floor's rune circle,
			-- which stays put in the world.
			local here: CFrame? = nil
			local frame
			if role == "ring" then
				frame = pet.base * offset
			elseif role == "halo" then
				frame = pet.base * CFrame.new(offset.Position) * CFrame.Angles(0, t * 0.35, 0)
			elseif role == "rotor" then
				local rc = CFrame.new(pet.groups.rotor)
				here = rc * CFrame.Angles(0, t * 14, 0) * rc:Inverse() * offset
			elseif role == "orbit" then
				here = c * CFrame.Angles(0, t * 0.9, 0) * cInv * offset
			elseif role == "rays" then
				here = c * CFrame.Angles(0, 0, t * 0.5) * cInv * offset
			elseif (role == "wingL" or role == "wingR") and pet.hinges[role] then
				local hinge = CFrame.new(pet.hinges[role])
				local side = if pet.hinges[role].X > 0 then 1 else -1
				here = hinge * CFrame.Angles(0, -side * swing, side * 0.12 * beat) * hinge:Inverse() * offset
			elseif (role == "jawTopL" or role == "jawTopR" or role == "jawBotL" or role == "jawBotR") and pet.hinges["jaw" .. role:sub(-1)] then
				-- A crab's jaw turns on its hinge: the top one up, the bottom one down a little less
				-- (the pet faces -Z, so a turn about X lifts the jaw's tip).
				local hinge = CFrame.new(pet.hinges["jaw" .. role:sub(-1)])
				local angle = jaws[role:sub(-1)] * (if role:sub(4, 6) == "Top" then 1 else -0.6)
				here = hinge * CFrame.Angles(angle, 0, 0) * hinge:Inverse() * offset
			elseif role:match("^leg[LR]%u$") and pet.hinges[role] then
				-- A crab steps in the air: each leg swings forward and back on its hip, lifting as it
				-- swings forward; every other leg in step, the two sides opposite (as crabs walk).
				local hinge = CFrame.new(pet.hinges[role])
				local side = if pet.hinges[role].X > 0 then 1 else -1
				local index = string.byte(role, 5) - 64 + (if role:sub(4, 4) == "L" then 0 else 1)
				local phase = t * 4 + pet.phase + index * math.pi
				local step = 0.16 * math.sin(phase)
				local raise = 0.07 * (1 + math.cos(phase))
				here = hinge * CFrame.Angles(0, step, side * raise) * hinge:Inverse() * offset
			elseif role == "wisp" then
				local tilt = part:GetAttribute("Tilt")
				local angle = t * (part:GetAttribute("Speed") or 1.6) + part:GetAttribute("Phase")
				here = c
					* CFrame.Angles(tilt, 0, tilt * 0.5)
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(part:GetAttribute("Orbit"), 0, 0)
			elseif role:match("^drone%d") then
				local n = tonumber(role:match("%d+"))
				here = c * CFrame.Angles(0, t * 1.3, 0) * cInv * CFrame.new(0, math.sin(t * 4 + n) * 0.35, 0) * offset
			else
				here = offset
			end
			local size = pet.sizes[i]
			if here then
				-- The jelly squashes everything above its floor: the dome, the face, what rides on top.
				if stretch ~= 0 and offset.Position.Y > pet.jellyFloor then
					here = squashed(here, pet.jellyFloor, pet.centre, sy, sxz)
					if role == "body" and part.Name ~= "Fx" then
						size = squashedSize(size, offset, sy, sxz)
					end
				end
				frame = bob * here
			end
			if pet.eyes[i] then
				size = Vector3.new(size.X, size.Y * open, size.Z)
			end
			if part.Size ~= size then
				part.Size = size
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
