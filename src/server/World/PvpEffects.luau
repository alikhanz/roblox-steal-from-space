--!strict
-- The strike's greybox impact, made on the server so every client sees it. A placeholder until
-- the art pass. The harpoon and the bomb are drawn by the clients (World/HarpoonVisual,
-- World/BombVisual; brief docs/design/screens/pvp-abilities.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)

local IMPACT_COLOR = Color3.fromRGB(255, 240, 170)
local IMPACT_TRANSPARENCY = 0.15

local PvpEffects = {}

local function effectsFolder(): Instance
	local parent: Instance = workspace:FindFirstChild("World") or workspace
	local existing = parent:FindFirstChild("PvpEffects")
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "PvpEffects"
	folder.Parent = parent
	return folder
end

-- The strike landing: a bright burst at the touch point that swells and fades.
function PvpEffects.strikeImpact(position: Vector3)
	local burst = Instance.new("Part")
	burst.Name = "StrikeImpact"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.one * PvpConfig.STRIKE_IMPACT_RADIUS
	burst.Color = IMPACT_COLOR
	burst.Material = Enum.Material.Neon
	burst.Transparency = IMPACT_TRANSPARENCY
	burst.CFrame = CFrame.new(position)
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanTouch = false
	burst.CanQuery = false
	burst.CastShadow = false
	burst.Parent = effectsFolder()
	local grow = TweenInfo.new(PvpConfig.STRIKE_IMPACT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(burst, grow, {
		Size = Vector3.one * PvpConfig.STRIKE_IMPACT_RADIUS * 2,
		Transparency = 1,
	}):Play()
	task.delay(PvpConfig.STRIKE_IMPACT_SECONDS, function()
		burst:Destroy()
	end)
end

return table.freeze(PvpEffects)
