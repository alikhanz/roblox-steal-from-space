--!strict
-- Builds the greybox coin board stand: a panel on two legs with a glowing trim. The rows are
-- drawn by each client on the panel's front face (LeaderboardController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local LeaderboardLooks = require(ReplicatedStorage.Shared.Config.LeaderboardLooks)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

local LeaderboardModel = {}

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

function LeaderboardModel.build(): Model
	local position = StationConfig.PLATFORM_CENTER + LeaderboardLooks.POSITION
	-- The panel's front face (-Z of this frame) looks along FACING.
	local origin = CFrame.lookAt(position, position + LeaderboardLooks.FACING)
	local panelSize = LeaderboardLooks.PANEL_SIZE
	local legSize = LeaderboardLooks.LEG_SIZE

	local model = Instance.new("Model")
	model.Name = "CoinBoard"

	local panel = block(
		LeaderboardConfig.PANEL_NAME,
		panelSize,
		origin * CFrame.new(0, LeaderboardLooks.PANEL_LIFT + panelSize.Y / 2, 0),
		LeaderboardLooks.PANEL_COLOR,
		Enum.Material.Metal
	)
	panel.Parent = model

	local trimSize = panelSize + Vector3.new(1, 1, 0) * LeaderboardLooks.TRIM_THICKNESS * 2
	local trim = block(
		"Trim",
		Vector3.new(trimSize.X, trimSize.Y, panelSize.Z / 2),
		panel.CFrame * CFrame.new(0, 0, panelSize.Z / 2),
		LeaderboardLooks.TRIM_COLOR,
		Enum.Material.Neon
	)
	trim.CanCollide = false
	trim.Parent = model

	for _, side in { -1, 1 } do
		local leg = block(
			"Leg",
			legSize,
			origin * CFrame.new(side * (panelSize.X / 2 - legSize.X), legSize.Y / 2, 0),
			LeaderboardLooks.LEG_COLOR,
			Enum.Material.Metal
		)
		leg.Parent = model
	end

	local rows = Instance.new("StringValue")
	rows.Name = LeaderboardConfig.ROWS_VALUE_NAME
	rows.Value = "[]"
	rows.Parent = model
	model.PrimaryPart = panel
	return model
end

return table.freeze(LeaderboardModel)
