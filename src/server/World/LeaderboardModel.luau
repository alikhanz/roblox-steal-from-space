--!strict
-- Builds the coin board in the middle of the station, the "crown" (decision 087): the pearl dais,
-- pillar and screen backs and the gold glow from the kit (World/StationKit), four navy screens
-- round the pillar high over the kiosks — each client draws the top on them (CoinBoardController)
-- — and two coins it turns: a gold one on top and a hologram round the pillar. Only the dais and
-- the pillar collide, as plain parts. Without the kit the board stands in greybox parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local LeaderboardLooks = require(ReplicatedStorage.Shared.Config.LeaderboardLooks)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StationKit = require(script.Parent.StationKit)
local StationShape = require(ReplicatedStorage.Shared.Config.StationShape)

local SCALE = StationShape.SCALE
-- Greybox without the kit: a screen's back and glowing rim round its face, studs.
local GREYBOX_BACK_PAD = 1.4 * SCALE
local GREYBOX_BACK_DEPTH = 0.6 * SCALE
local GREYBOX_RIM = 0.8 * SCALE

local LeaderboardModel = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = material
	result.Anchored = true
	result.CanTouch = false
	result.CanQuery = false
	result.CanCollide = false
	result.CastShadow = false
	return result
end

-- An upright cylinder (Roblox cylinders run along X) standing on `ground`.
local function column(name: string, ground: CFrame, radius: number, height: number): Part
	local result = part(
		name,
		Vector3.new(height, radius * 2, radius * 2),
		ground * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		LeaderboardLooks.PEARL_COLOR,
		LeaderboardLooks.PEARL_MATERIAL
	)
	result.Shape = Enum.PartType.Cylinder
	return result
end

-- Screen `index`'s frame (1-based): its face's centre, its front (-Z) looking out and down.
local function screenFrame(ground: CFrame, index: number): CFrame
	return ground
		* CFrame.Angles(0, (index - 1) * math.pi * 2 / StationShape.BOARD_SCREENS, 0)
		* CFrame.new(0, StationShape.BOARD_SCREEN_MIDDLE, -StationShape.BOARD_SCREEN_OUT)
		* CFrame.Angles(-StationShape.BOARD_SCREEN_TILT, 0, 0)
end

-- A coin standing on its edge at `center`, its faces along Z: a gold disc, or a see-through
-- glowing one, with the kit's glow round it. A model the clients turn about its pivot's Y.
local function coin(name: string, center: CFrame, radius: number, hologram: boolean): Model
	local model = Instance.new("Model")
	model.Name = name
	local disc = part(
		"Disc",
		Vector3.new(radius * StationShape.COIN_THICKNESS, radius * 2, radius * 2),
		center * CFrame.Angles(0, math.rad(90), 0),
		LeaderboardLooks.COIN_COLOR,
		if hologram then Enum.Material.Neon else LeaderboardLooks.COIN_MATERIAL
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = if hologram then LeaderboardLooks.HOLO_TRANSPARENCY else 0
	disc.CastShadow = not hologram
	disc.Parent = model
	local glow = StationKit.piece("CoinGlow", radius)
	if glow then
		glow.CFrame = center
		glow.Color = LeaderboardLooks.GLOW_COLOR
		glow.Material = Enum.Material.Neon
		glow.CanCollide = false
		glow.CastShadow = false
		glow.Parent = model
	end
	model.PrimaryPart = disc
	model.WorldPivot = center
	return model
end

function LeaderboardModel.build(): Model
	local ground = CFrame.new(StationConfig.PLATFORM_CENTER + LeaderboardLooks.POSITION)
	local model = Instance.new("Model")
	model.Name = "CoinBoard"

	-- What players bump into: the dais and the pillar, plain parts (seen only without the kit).
	local dais = column("Dais", ground, StationShape.BOARD_DAIS_RADIUS, StationShape.BOARD_DAIS_HEIGHT)
	local pillar = column("Pillar", ground, StationShape.BOARD_PILLAR_RADIUS, StationShape.BOARD_TOP)
	for _, solid in { dais, pillar } do
		solid.CanCollide = true
		solid.Parent = model
	end

	local pearl = StationKit.piece("BoardPearl", SCALE)
	local glow = StationKit.piece("BoardGlow", SCALE)
	if pearl and glow then
		dais.Transparency = 1
		pillar.Transparency = 1
		pearl.CFrame = StationKit.place("BoardPearl", ground, SCALE)
		pearl.Color = LeaderboardLooks.PEARL_COLOR
		pearl.Material = LeaderboardLooks.PEARL_MATERIAL
		pearl.CanCollide = false
		pearl.Parent = model
		glow.CFrame = StationKit.place("BoardGlow", ground, SCALE)
		glow.Color = LeaderboardLooks.GLOW_COLOR
		glow.Material = Enum.Material.Neon
		glow.CanCollide = false
		glow.CastShadow = false
		glow.Parent = model
	end

	local faceSize =
		Vector3.new(StationShape.BOARD_SCREEN_WIDTH, StationShape.BOARD_SCREEN_HEIGHT, StationShape.BOARD_FACE_DEPTH)
	for index = 1, StationShape.BOARD_SCREENS do
		local frame = screenFrame(ground, index)
		local depth = StationShape.BOARD_FACE_DEPTH
		local panelFrame = frame * CFrame.new(0, 0, depth / 2)
		local panel = part(
			LeaderboardConfig.PANEL_NAME,
			faceSize,
			panelFrame,
			LeaderboardLooks.PANEL_COLOR,
			Enum.Material.SmoothPlastic
		)
		panel.Parent = model
		if not (pearl and glow) then
			local rimSize = faceSize + Vector3.new(2, 2, 0) * GREYBOX_RIM
			local rim = part(
				"Rim",
				rimSize,
				frame * CFrame.new(0, 0, depth * 1.5),
				LeaderboardLooks.GLOW_COLOR,
				Enum.Material.Neon
			)
			rim.Parent = model
			local backSize = rimSize + Vector3.new(2, 2, 0) * GREYBOX_BACK_PAD + Vector3.zAxis * GREYBOX_BACK_DEPTH
			local backFrame = frame * CFrame.new(0, 0, depth * 2 + GREYBOX_BACK_DEPTH / 2)
			local back =
				part("Back", backSize, backFrame, LeaderboardLooks.PEARL_COLOR, LeaderboardLooks.PEARL_MATERIAL)
			back.Parent = model
		end
	end

	local coins = Instance.new("Folder")
	coins.Name = LeaderboardConfig.COINS_FOLDER_NAME
	local top =
		coin("Coin", ground * CFrame.new(0, StationShape.BOARD_COIN_LIFT, 0), StationShape.BOARD_COIN_RADIUS, false)
	top.Parent = coins
	local holoFrame = ground * CFrame.new(0, StationShape.BOARD_HOLO_LIFT, 0)
	local hologram = coin("Hologram", holoFrame, StationShape.BOARD_HOLO_RADIUS, true)
	hologram.Parent = coins
	coins.Parent = model

	local rows = Instance.new("StringValue")
	rows.Name = LeaderboardConfig.ROWS_VALUE_NAME
	rows.Value = "[]"
	rows.Parent = model
	model.PrimaryPart = pillar
	return model
end

return table.freeze(LeaderboardModel)
