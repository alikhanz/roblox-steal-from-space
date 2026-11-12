--!strict
-- The ring sight round the star serpent's head on this client (decision 107, brief
-- docs/design/screens/serpent-target.md): only hits on the head knock its egg out, and its long
-- body draws the eye away from it. A circle as wide as where hits land (SerpentConfig.HIT_RADIUS)
-- with four notches in from it, always turned to the camera, in the strike button's colour; it
-- breathes, and a hit flashes it white and shrinks it for a moment. Shown only while the egg is
-- inside the serpent. One BillboardGui of five frames, no images, no particles. Looks in
-- SerpentLooks.TARGET.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentLooks = require(ReplicatedStorage.Shared.Config.SerpentLooks)

local LOOKS = SerpentLooks.TARGET
local DIAMETER = SerpentConfig.HIT_RADIUS * 2

local SerpentTarget = {}

export type Target = {
	gui: BillboardGui,
	stroke: UIStroke,
	-- The ring and its notches: their colour follows the flash.
	frames: { Frame },
	-- os.clock() of the last hit, for the flash.
	hitAt: number,
}

local function notch(parent: Instance, anchor: Vector2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Notch"
	frame.AnchorPoint = anchor
	-- Its outer end on the ring, at the anchor's side.
	frame.Position = UDim2.fromScale(anchor.X, anchor.Y)
	frame.Size = size
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = LOOKS.color
	frame.BackgroundTransparency = LOOKS.transparency
	frame.Parent = parent
	return frame
end

-- The ring on `head`, in `parent` (a folder of this client's that goes with the serpent).
function SerpentTarget.build(head: BasePart, parent: Instance): Target
	local gui = Instance.new("BillboardGui")
	gui.Name = "SerpentTarget"
	gui.Adornee = head
	-- Scale in studs: the ring is as wide as where hits land, however far it is.
	gui.Size = UDim2.fromScale(DIAMETER, DIAMETER)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = LOOKS.maxDistance
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = LOOKS.color
	stroke.Transparency = LOOKS.transparency
	stroke.Thickness = LOOKS.thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = ring
	ring.Parent = gui

	local width = LOOKS.thickness
	local long = LOOKS.notchLength
	local frames = {
		ring,
		notch(gui, Vector2.new(0.5, 0), UDim2.new(0, width, long, 0)),
		notch(gui, Vector2.new(0.5, 1), UDim2.new(0, width, long, 0)),
		notch(gui, Vector2.new(0, 0.5), UDim2.new(long, 0, 0, width)),
		notch(gui, Vector2.new(1, 0.5), UDim2.new(long, 0, 0, width)),
	}
	gui.Parent = parent
	return { gui = gui, stroke = stroke, frames = frames, hitAt = -math.huge }
end

function SerpentTarget.setShown(target: Target, shown: boolean)
	target.gui.Enabled = shown
end

-- A hit landed on the head: flash and shrink from now.
function SerpentTarget.hit(target: Target, clock: number)
	target.hitAt = clock
end

-- Breathing and the flash, each frame while shown.
function SerpentTarget.update(target: Target, clock: number)
	if not target.gui.Enabled then
		return
	end
	local breath = (math.sin(clock * 2 * math.pi / LOOKS.breathSeconds) + 1) / 2
	target.stroke.Thickness = LOOKS.thickness + (LOOKS.breathThickness - LOOKS.thickness) * breath
	-- 0 right at the hit, 1 once the flash is over.
	local settled = math.clamp((clock - target.hitAt) / LOOKS.flashSeconds, 0, 1)
	local colour = LOOKS.flashColor:Lerp(LOOKS.color, settled)
	target.stroke.Color = colour
	for index = 2, #target.frames do
		target.frames[index].BackgroundColor3 = colour
	end
	local scale = LOOKS.flashScale + (1 - LOOKS.flashScale) * settled
	target.gui.Size = UDim2.fromScale(DIAMETER * scale, DIAMETER * scale)
end

return table.freeze(SerpentTarget)
