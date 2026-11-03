--!strict
-- Greybox effects of the attacks, made on the server so every client sees them: the harpoon's
-- beam, the bomb in flight and its flash. Placeholders until the art pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)

local BEAM_COLOR = Color3.fromRGB(120, 230, 255)
local BEAM_WIDTH = 0.4
local BOMB_RADIUS = 1
local BOMB_COLOR = Color3.fromRGB(150, 90, 255)
local FLASH_COLOR = Color3.fromRGB(200, 150, 255)
local FLASH_TRANSPARENCY = 0.5

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

-- A beam from the shooter to `target` for a moment.
function PvpEffects.harpoonBeam(from: BasePart, target: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = PvpConfig.HARPOON_BEAM_NAME
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(target)
	ghost(anchor)

	local a0 = Instance.new("Attachment")
	a0.Parent = from
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

	task.delay(PvpConfig.HARPOON_BEAM_SECONDS, function()
		a0:Destroy()
		anchor:Destroy()
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
