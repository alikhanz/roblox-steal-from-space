--!strict
-- Builds the greybox jetpack shop: a counter with a prompt, a back panel for the sign and a
-- glowing orb. The shop window itself lives on the client; the prompt only opens it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ShopLooks = require(ReplicatedStorage.Shared.Config.ShopLooks)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

local ShopModel = {}

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

function ShopModel.build(): Model
	local position = StationConfig.PLATFORM_CENTER + ShopLooks.POSITION
	local origin = CFrame.lookAt(position, position + ShopLooks.FACING)

	local model = Instance.new("Model")
	model.Name = "JetpackShop"

	local counter = block(
		ShopConfig.COUNTER_NAME,
		ShopLooks.COUNTER_SIZE,
		origin * CFrame.new(0, ShopLooks.COUNTER_SIZE.Y / 2, 0),
		ShopLooks.COUNTER_COLOR,
		Enum.Material.Metal
	)
	counter.Parent = model

	local trim = block(
		"Trim",
		Vector3.new(ShopLooks.COUNTER_SIZE.X + 0.2, ShopLooks.TRIM_HEIGHT, ShopLooks.COUNTER_SIZE.Z + 0.2),
		origin * CFrame.new(0, ShopLooks.COUNTER_SIZE.Y, 0),
		ShopLooks.TRIM_COLOR,
		Enum.Material.Neon
	)
	trim.CanCollide = false
	trim.Parent = model

	local panel = block(
		ShopConfig.SIGN_NAME,
		ShopLooks.PANEL_SIZE,
		origin * CFrame.new(0, ShopLooks.PANEL_SIZE.Y / 2, ShopLooks.PANEL_OFFSET),
		ShopLooks.PANEL_COLOR,
		Enum.Material.Metal
	)
	panel.Parent = model

	local orb = block(
		"Orb",
		Vector3.one * ShopLooks.ORB_RADIUS * 2,
		origin * CFrame.new(0, ShopLooks.ORB_HEIGHT, 0),
		ShopLooks.ORB_COLOR,
		Enum.Material.Neon
	)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = ShopLooks.ORB_COLOR
	light.Range = ShopLooks.ORB_LIGHT_RANGE
	light.Brightness = ShopLooks.ORB_LIGHT_BRIGHTNESS
	light.Parent = orb
	orb.Parent = model

	-- The prompt's texts are set by each client in its own language, and the client draws it
	-- in the same style as the egg prompt (PromptViewController).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.MaxActivationDistance = ShopConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.PrimaryPart = counter
	return model
end

return table.freeze(ShopModel)
