--!strict
-- Greybox effects of the attacks, made on the server so every client sees them: the strike's
-- impact, the harpoon's beam, the bomb in flight and its flash. Placeholders until the art pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)

local BEAM_COLOR = Color3.fromRGB(120, 230, 255)
local BEAM_WIDTH = 0.9
local HOOK_SIZE = 1.4
-- The beam starts at the hand when the rig has one, so it is seen leaving the character.
local HAND_NAME = "RightHand"
local BOMB_RADIUS = 1
local BOMB_COLOR = Color3.fromRGB(150, 90, 255)
local FLASH_COLOR = Color3.fromRGB(200, 150, 255)
local FLASH_TRANSPARENCY = 0.5
local SHIELD_RADIUS = 4
local SHIELD_COLOR = Color3.fromRGB(120, 230, 255)
local SHIELD_TRANSPARENCY = 0.6
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

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- The harpoon: a beam from the shooter's hand to `target`, with a glowing hook that flies out
-- along it and back.
function PvpEffects.harpoonBeam(from: BasePart, target: Vector3)
	local character = from.Parent
	local hand = character and character:FindFirstChild(HAND_NAME)
	local origin: BasePart = if hand and hand:IsA("BasePart") then hand else from

	local anchor = Instance.new("Part")
	anchor.Name = PvpConfig.HARPOON_BEAM_NAME
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(target)
	ghost(anchor)

	local a0 = Instance.new("Attachment")
	a0.Parent = origin
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = BEAM_WIDTH
	beam.Width1 = BEAM_WIDTH
	beam.Color = ColorSequence.new(BEAM_COLOR)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Parent = anchor
	anchor.Parent = effectsFolder()

	local hook = Instance.new("Part")
	hook.Name = "HarpoonHook"
	hook.Shape = Enum.PartType.Ball
	hook.Size = Vector3.one * HOOK_SIZE
	hook.Color = BEAM_COLOR
	hook.Material = Enum.Material.Neon
	ghost(hook)
	hook.CFrame = CFrame.new(origin.Position)
	hook.Parent = effectsFolder()

	-- Out for the first half, back for the second.
	local total = PvpConfig.HARPOON_BEAM_SECONDS
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		local phase = math.clamp(elapsed / total, 0, 1)
		local along = if phase < 0.5 then phase * 2 else (1 - phase) * 2
		hook.CFrame = CFrame.new(origin.Position:Lerp(target, along))
		if elapsed >= total then
			connection:Disconnect()
			hook:Destroy()
			a0:Destroy()
			anchor:Destroy()
		end
	end)
end

-- A bomb that flies straight from `start` at `velocity` until `fuseSeconds` pass or `touches`
-- says it reached someone, then calls `onExplode` with where it ended up. Moved by hand:
-- space has no drag and no gravity for it.
function PvpEffects.throwBomb(
	start: Vector3,
	velocity: Vector3,
	fuseSeconds: number,
	touches: (Vector3) -> boolean,
	onExplode: (Vector3) -> ()
)
	local bomb = Instance.new("Part")
	bomb.Name = PvpConfig.BOMB_NAME
	bomb.Shape = Enum.PartType.Ball
	bomb.Size = Vector3.one * BOMB_RADIUS * 2
	bomb.Color = BOMB_COLOR
	bomb.Material = Enum.Material.Neon
	bomb.CFrame = CFrame.new(start)
	ghost(bomb)
	bomb.Parent = effectsFolder()

	local position = start
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		position += velocity * deltaTime
		bomb.CFrame = CFrame.new(position)
		if elapsed >= fuseSeconds or touches(position) then
			connection:Disconnect()
			bomb:Destroy()
			onExplode(position)
		end
	end)
end

-- The shield: a translucent bubble welded to the character for `seconds`.
function PvpEffects.shieldBubble(character: Model, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local bubble = Instance.new("Part")
	bubble.Name = PvpConfig.SHIELD_NAME
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * SHIELD_RADIUS * 2
	bubble.Color = SHIELD_COLOR
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = SHIELD_TRANSPARENCY
	bubble.CanCollide = false
	bubble.CanTouch = false
	bubble.CanQuery = false
	bubble.CastShadow = false
	bubble.Massless = true
	bubble.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
	bubble.Parent = character
	task.delay(seconds, function()
		bubble:Destroy()
	end)
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
	ghost(burst)
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

-- The explosion: a translucent sphere of the blast radius for a moment.
function PvpEffects.bombFlash(center: Vector3, radius: number)
	local flash = Instance.new("Part")
	flash.Name = "BombFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * radius * 2
	flash.Color = FLASH_COLOR
	flash.Material = Enum.Material.Neon
	flash.Transparency = FLASH_TRANSPARENCY
	flash.CFrame = CFrame.new(center)
	ghost(flash)
	flash.Parent = effectsFolder()
	task.delay(PvpConfig.BOMB_FLASH_SECONDS, function()
		flash:Destroy()
	end)
end

return table.freeze(PvpEffects)
