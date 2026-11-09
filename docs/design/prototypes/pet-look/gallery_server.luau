-- The pet gallery (preview prototype, a Script in Workspace, installed via MCP): shows one kind at a
-- time, its ten variants (tiers 0-4 and their meteor versions) in a ring near the edge of the
-- player's island, far apart, each signed. The client's buttons (gallery_client.luau) step through
-- the 72 kinds in guardian order. The pets come dressed from ServerStorage.RoboPets/<kind>.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- id|name, three kinds a guardian (main, second, rare), guardians in zone order.
local KINDS = {
	"slimeWarden|Слизень-сторож", "patrolSwarm|Патрульный рой", "patrolRay|Скат-патрульный",
	"crabDrone|Краб-дрон", "droneRay|Скат-дрон", "blimpWhale|Кит-дирижабль",
	"violetCrab|Лиловый краб", "violetWorm|Лиловый червь", "violetRay|Лиловый скат",
	"acidSlime|Кислотный слизень", "acidWorm|Кислотный червь", "acidWhale|Кислотный кит",
	"rustyCrab|Ржавый краб", "rustySwarm|Ржавый рой", "rustyWhale|Ржавый кит",
	"slimeKing|Король слизней", "royalSwarm|Свита короля", "royalRay|Королевский скат",
	"iceWorm|Ледяной червь", "iceSwarm|Ледяной рой", "iceCrab|Ледяной краб",
	"snowCrab|Снежный краб", "snowSlime|Снежный слизень", "snowWhale|Снежный кит",
	"frostSlime|Морозный слизень", "flakeSwarm|Рой снежинок", "frostRay|Морозный скат",
	"crystalWorm|Хрустальный червь", "crystalSlime|Хрустальный слизень", "crystalWhale|Хрустальный кит",
	"iceRay|Ледяной скат", "icebreakerCrab|Краб-ледокол", "auroraSwarm|Северное сияние",
	"wormMother|Мать червей", "motherWhale|Ледяная китиха", "nannyRay|Скат-няня",
	"devourerSwarm|Рой пожирателей", "devourerCrab|Краб-пожиратель", "devourerWorm|Червь-пожиратель",
	"starRay|Звёздный скат", "starSlime|Звёздный слизень", "starWhale|Звёздный кит",
	"fireSlime|Огненный слизень", "fireWorm|Огненный червь", "fireWhale|Огненный кит",
	"redSwarm|Красный рой", "redCrab|Красный краб", "redRay|Красный скат",
	"lightningRay|Скат-молния", "stormSlime|Грозовой слизень", "stormWhale|Грозовой кит",
	"devourerQueen|Матка пожирателей", "guardCrab|Краб-гвардеец", "empressWorm|Червь-императрица",
	"shadowWorm|Теневой червь", "shadowSlime|Теневой слизень", "shadowCrab|Теневой краб",
	"blackRay|Чёрный скат", "eclipseSwarm|Рой затмения", "eclipseWhale|Кит-затмение",
	"voidSwarm|Рой пустоты", "voidSlime|Слизень пустоты", "voidRay|Скат пустоты",
	"gravityCrab|Гравикраб", "gravityWorm|Гравичервь", "gravitySwarm|Гравирой",
	"whaleCalf|Китёнок", "rayCalf|Скатёнок", "stargazerCrab|Звездочёт",
	"spaceWhale|Космический кит", "spaceWorm|Космический червь", "galaxySlime|Галактический слизень",
}
local ZONES = { debris = "Пояс обломков", ice = "Ледяные кольца", nebula = "Красная туманность", horizon = "Горизонт событий" }
local SLOTS = { "основной", "второй", "редкий" }
local VARIANTS = { "0", "1", "2", "3", "4", "m0", "m1", "m2", "m3", "m4" }
local TIER_NAMES = { "обычный", "необычный", "редкий", "эпический", "легендарный" }
-- The islands' ring (StationSize): eight islands, the first on +X.
local RING_RADIUS, ISLAND_COUNT = 398.5, 8
-- Where the pets stand: a ring this far from the island's centre, near its edge.
local GALLERY_RADIUS = 78

local folder = workspace:FindFirstChild("PetGallery") or Instance.new("Folder")
folder.Name = "PetGallery"
folder.Parent = workspace
local remote = ReplicatedStorage:FindFirstChild("PetGalleryStep") or Instance.new("RemoteEvent")
remote.Name = "PetGalleryStep"
remote.Parent = ReplicatedStorage
-- The bar's text (a StringValue: string attributes are capped at 50 characters).
local titleValue = ReplicatedStorage:FindFirstChild("PetGalleryTitle") or Instance.new("StringValue")
titleValue.Name = "PetGalleryTitle"
titleValue.Parent = ReplicatedStorage
local current = 0

local function islandOf(player: Player): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = if root then root.Position else Vector3.new(RING_RADIUS, 0, 0)
	local best, bestDistance = Vector3.zero, math.huge
	for index = 0, ISLAND_COUNT - 1 do
		local angle = index * math.pi * 2 / ISLAND_COUNT
		local centre = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
		local distance = (Vector3.new(at.X, 0, at.Z) - centre).Magnitude
		if distance < bestDistance then
			best, bestDistance = centre, distance
		end
	end
	return best
end

local function label(model: Model, text: string, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GalleryLabel"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = Enum.Font.GothamBold
	text_.TextScaled = true
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.3
	text_.Text = text
	text_.Parent = gui
	gui.Parent = model.PrimaryPart or model:FindFirstChild("Fx", true)
end

local function show(index: number, player: Player)
	index = (index - 1) % #KINDS + 1
	current = index
	folder:ClearAllChildren()
	local id, name = KINDS[index]:match("^(%w+)|(.+)$")
	local source = ServerStorage.RoboPets:FindFirstChild(id)
	local zone = source and source:FindFirstChildOfClass("Model") and source:FindFirstChildOfClass("Model"):GetAttribute("Zone")
	local guardian = math.floor((index - 1) / 3) + 1
	local slot = SLOTS[(index - 1) % 3 + 1]
	titleValue.Value = `{index}/{#KINDS} · {name} ({slot}) · страж {guardian}/24 · {ZONES[zone] or "?"}`
	if not source then
		titleValue.Value = `{index}/{#KINDS} · {name}: моделей нет`
		return
	end
	local centre = islandOf(player)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { folder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	for slotIndex, variant in VARIANTS do
		local pet = source:FindFirstChild(`{id}-{variant}`)
		if not pet then
			continue
		end
		local angle = (slotIndex - 1) * math.pi * 2 / #VARIANTS
		local spot = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * GALLERY_RADIUS
		local hit = workspace:Raycast(spot + Vector3.new(0, 80, 0), Vector3.new(0, -160, 0), params)
		local floor = if hit then hit.Position.Y else 0
		local model = pet:Clone()
		-- Streaming is always on (Server Authority): without this a pet reaches the client part by
		-- part, and the client's motion would be built from half a pet.
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local cf, size = model:GetBoundingBox()
		local at = Vector3.new(spot.X, floor + 0.3 + size.Y / 2, spot.Z)
		local facing = CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z))
		model:PivotTo(facing * cf:ToObjectSpace(model:GetPivot()))
		local tier = tonumber(variant:match("%d")) + 1
		label(model, (if variant:sub(1, 1) == "m" then "метеоритный " else "") .. TIER_NAMES[tier], size.Y)
		model.Parent = folder
	end
end

remote.OnServerEvent:Connect(function(player, step)
	if typeof(step) == "number" then
		show(current + step, player)
	end
end)

local function join(player: Player)
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(3)
	if current == 0 then
		show(1, player)
	end
	local gui = script:FindFirstChild("PetGalleryGui")
	if gui then
		gui:Clone().Parent = player:WaitForChild("PlayerGui")
	end
end
Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do
	task.spawn(join, player)
end
