--!strict
-- The tutorial's guide in the world (docs/design/screens/tutorial-arrows.md): a path of chevrons
-- running from the player towards the step's target, and the target lit by a pulsing outline.
-- Client-only and seen only by this player: the path is a Beam between two attachments on the
-- Terrain (which sits at the world's origin, so their positions are world positions), the
-- outline a Highlight under the camera. Near the target the path goes away; the outline stays.

local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local GUIDE = Theme.NEON.FLIGHT.Vertical
-- The path starts a little ahead of the player and ends a little short of the target, studs.
local START_OFFSET = 4
local END_OFFSET = 6
-- Closer than this to the target, the path is not drawn: the target is right there.
local NEAR_DISTANCE = 15
local WIDTH = 2.4
-- One chevron per this many studs, running towards the target at this many studs a second.
local CHEVRON_LENGTH = 3
local CHEVRON_SPEED = 1.2
-- Fades in from the player and out at the target, as shares of the path's length.
local FADE_SHARE = 0.08
local PATH_TRANSPARENCY = 0.15
-- A beam takes its transparency at its segments' ends only: with one segment both ends are
-- the fully faded ones and the path would not show at all.
local SEGMENTS = 24
-- The target's outline breathes between these fill transparencies, this many times a second.
local FILL_FROM = 0.88
local FILL_TO = 0.6
local PULSE_RATE = 1.4

export type GuidePath = {
	-- Draws the path from `from` to `to` and lights `target` (if any) for this frame.
	show: (from: Vector3, to: Vector3, target: Instance?) -> (),
	hide: () -> (),
	destroy: () -> (),
}

local GuidePath = {}

function GuidePath.new(): GuidePath
	local terrain = workspace.Terrain
	local start = Instance.new("Attachment")
	start.Name = "TutorialPathStart"
	start.Parent = terrain
	local finish = Instance.new("Attachment")
	finish.Name = "TutorialPathEnd"
	finish.Parent = terrain

	local beam = Instance.new("Beam")
	beam.Name = "TutorialPath"
	-- From the target to the player: a beam lays its texture's top towards Attachment0, so the
	-- chevrons (pointing up in the sprite) point at the target. A positive speed runs the
	-- texture towards Attachment1, hence the minus: the chevrons run to the target too.
	beam.Attachment0 = finish
	beam.Attachment1 = start
	beam.Texture = Icons.CHEVRONS
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = CHEVRON_LENGTH
	beam.TextureSpeed = -CHEVRON_SPEED
	beam.Width0 = WIDTH
	beam.Width1 = WIDTH
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = SEGMENTS
	beam.Color = ColorSequence.new(GUIDE)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(FADE_SHARE, PATH_TRANSPARENCY),
		NumberSequenceKeypoint.new(1 - FADE_SHARE, PATH_TRANSPARENCY),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Enabled = false
	beam.Parent = terrain

	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialTarget"
	highlight.FillColor = GUIDE
	highlight.OutlineColor = GUIDE
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false

	local function placeHighlight(target: Instance?)
		if not target then
			highlight.Enabled = false
			return
		end
		if highlight.Adornee ~= target then
			highlight.Adornee = target
		end
		local camera = workspace.CurrentCamera
		if highlight.Parent ~= camera then
			highlight.Parent = camera
		end
		local wave = (math.sin(os.clock() * math.pi * 2 * PULSE_RATE) + 1) / 2
		highlight.FillTransparency = FILL_FROM + (FILL_TO - FILL_FROM) * wave
		highlight.Enabled = true
	end

	local function show(from: Vector3, to: Vector3, target: Instance?)
		placeHighlight(target)
		local offset = to - from
		local distance = offset.Magnitude
		if distance <= NEAR_DISTANCE then
			beam.Enabled = false
			return
		end
		local direction = offset / distance
		start.WorldPosition = from + direction * START_OFFSET
		finish.WorldPosition = to - direction * END_OFFSET
		beam.Enabled = true
	end

	local function hide()
		beam.Enabled = false
		highlight.Enabled = false
	end

	local function destroy()
		beam:Destroy()
		start:Destroy()
		finish:Destroy()
		highlight:Destroy()
	end

	return {
		show = show,
		hide = hide,
		destroy = destroy,
	}
end

return table.freeze(GuidePath)
