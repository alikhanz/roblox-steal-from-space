--!strict
-- The star serpent's look on this client (decision 093). The server's serpent is a greybox head
-- that moves and is hit (World/SerpentModel); here it wears the kit of meshes from Blender
-- (ReplicatedStorage.SerpentKit, assets/blender/serpent/serpent_kit.py):
--   * the head's pieces on the server's head, the greybox hidden on this client;
--   * one segment's pieces copied down the path the head flies (Domain/SerpentBody), thinner
--     towards the tail, every third with stars on its flanks, and a constellation line of Beams
--     from star to star down its back;
--   * the tail's thruster after the last segment, a jet of Beams out of it;
--   * the star egg in the cradle on its neck while the egg is inside; its eyes gold while it
--     carries the egg, red once it guards it (SerpentLooks.MODEL).
-- Every piece is anchored, touches nothing and is moved once a frame (one BulkMoveTo). The model
-- never crosses the network. Without the kit in the place there is no look: the caller draws
-- the greybox body.
--
-- The kit: a Folder of MeshParts, each group measured from its speck (`Origin` for the head and
-- the egg, `SegmentOrigin`, `TailOrigin`; `JetPoint` where the jet comes out). Insertion into
-- Studio turned the kit about Y, which offsets from the specks don't mind.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetQueue = require(script.Parent.Parent.Loading.AssetQueue)
local LoadConfig = require(ReplicatedStorage.Shared.Config.LoadConfig)
local SerpentBody = require(ReplicatedStorage.Shared.Domain.SerpentBody)
local SerpentHunt = require(ReplicatedStorage.Shared.Domain.SerpentHunt)
local SerpentLooks = require(ReplicatedStorage.Shared.Config.SerpentLooks)

local MODEL = SerpentLooks.MODEL
local BODY = SerpentLooks.BODY

local SerpentVisual = {}

-- A piece of the kit and where it sits from its group's speck.
type Source = {
	part: MeshPart,
	offset: CFrame,
}

type Placed = {
	part: MeshPart,
	offset: CFrame,
}

type Segment = {
	pieces: { Placed },
	star: MeshPart,
}

export type Visual = {
	model: Model,
	head: { Placed },
	eyes: { MeshPart },
	egg: { Placed },
	eggGlow: Placed?,
	segments: { Segment },
	tail: { Placed },
	-- Every part, in the order `frames` is filled each frame.
	parts: { BasePart },
	frames: { CFrame },
	eggShown: boolean,
}

local HEAD_PIECES = { "HeadBody", "HeadEyes", "HeadGlow", "HeadStars" }
local EGG_PIECES = { "EggBody", "EggGlow" }
local TAIL_PIECES = { "TailBody", "TailGlow" }

local function kit(): Folder?
	local folder = ReplicatedStorage:FindFirstChild(MODEL.FOLDER_NAME)
	return if folder and folder:IsA("Folder") then folder else nil
end

local function meshIn(folder: Folder, name: string): MeshPart?
	local part = folder:FindFirstChild(name)
	return if part and part:IsA("MeshPart") then part else nil
end

-- The pieces `names` of `folder` and their offsets from its speck `speck`; nil if any is missing.
local function sources(folder: Folder, speck: string, names: { string }): { [string]: Source }?
	local origin = meshIn(folder, speck)
	if not origin then
		return nil
	end
	local result: { [string]: Source } = {}
	for _, name in names do
		local part = meshIn(folder, name)
		if not part then
			return nil
		end
		result[name] = { part = part, offset = origin.CFrame:ToObjectSpace(part.CFrame) }
	end
	return result
end

-- A Neon piece (white in the kit) in `colour`; plastic keeps its baked vertex colours on white.
local function copy(source: Source, parent: Instance, colour: Color3?, across: number?, along: number?): Placed
	local part = source.part:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	if colour then
		part.Material = Enum.Material.Neon
		part.Color = colour
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
	end
	local offset = source.offset
	if across and along then
		-- Stretched in the segment's frame: its local Z runs along the body.
		local stretch = Vector3.new(across, across, along)
		part.Size = source.part.Size * stretch
		offset = CFrame.new(offset.Position * stretch) * offset.Rotation
	end
	part.Parent = parent
	return { part = part, offset = offset }
end

local function colourOf(name: string): Color3?
	if name == "HeadGlow" or name == "SegmentRing" or name == "TailGlow" then
		return MODEL.SEAM_COLOR
	elseif name == "HeadStars" or name == "SegmentStar" or name == "SegmentStars" then
		return MODEL.STAR_COLOR
	elseif name == "EggGlow" then
		return MODEL.EGG_GLOW_COLOR
	elseif name == "HeadEyes" then
		return MODEL.EYE_CARRYING
	end
	return nil
end

local function attachment(part: BasePart, at: Vector3): Attachment
	local made = Instance.new("Attachment")
	made.Position = at
	made.Parent = part
	return made
end

local function line(from: Attachment, to: Attachment, width0: number, width1: number)
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = width0
	beam.Width1 = width1
	beam.Color = ColorSequence.new(MODEL.LINE_COLOR)
	beam.Transparency = NumberSequence.new(MODEL.LINE_TRANSPARENCY)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Parent = from
end

-- The thruster's jet out of `exit` (an attachment on the tail), pointing away from the head.
local function jet(body: BasePart, exit: Vector3, back: Vector3)
	local look = MODEL.JET
	local from = attachment(body, exit)
	local function beam(texture: string, length: number, width: number, colour: Color3)
		local to = attachment(body, exit + back * length)
		local made = Instance.new("Beam")
		made.Attachment0 = from
		made.Attachment1 = to
		made.FaceCamera = true
		made.Segments = 1
		made.Texture = texture
		made.TextureMode = Enum.TextureMode.Stretch
		made.TextureSpeed = look.scroll
		made.Width0 = width
		made.Width1 = width * 0.4
		made.Color = ColorSequence.new(colour)
		made.Transparency = NumberSequence.new(0, 1)
		made.Brightness = look.brightness
		made.LightEmission = 1
		made.LightInfluence = 0
		made.Parent = from
	end
	beam(look.texture, look.length, look.width, MODEL.SEAM_COLOR)
	beam(look.core, look.coreLength, look.coreWidth, Color3.new(1, 1, 1))
end

-- Whether the place has the serpent's kit.
function SerpentVisual.present(): boolean
	return kit() ~= nil
end

-- The serpent's look under `parent`, `segments` long; nil (with a warning) without a whole kit.
function SerpentVisual.build(parent: Instance, segments: number): Visual?
	local folder = kit()
	local headNames = table.clone(HEAD_PIECES)
	table.move(EGG_PIECES, 1, #EGG_PIECES, #headNames + 1, headNames)
	local head = folder and sources(folder, "Origin", headNames)
	local segment = folder
		and sources(folder, "SegmentOrigin", { "SegmentBody", "SegmentRing", "SegmentStar", "SegmentStars" })
	local tail = folder and sources(folder, "TailOrigin", { "TailBody", "TailGlow", "JetPoint" })
	if not (folder and head and segment and tail) then
		warn(`[SerpentVisual] No whole kit in ReplicatedStorage.{MODEL.FOLDER_NAME}; the greybox stands in`)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "SerpentLook"

	local visual: Visual = {
		model = model,
		head = {},
		eyes = {},
		egg = {},
		eggGlow = nil,
		segments = {},
		tail = {},
		parts = {},
		frames = {},
		eggShown = true,
	}
	for _, name in HEAD_PIECES do
		local placed = copy(head[name], model, colourOf(name))
		table.insert(visual.head, placed)
		if name == "HeadEyes" then
			table.insert(visual.eyes, placed.part)
		end
	end
	for _, name in EGG_PIECES do
		local placed = copy(head[name], model, colourOf(name))
		table.insert(visual.egg, placed)
		if name == "EggGlow" then
			visual.eggGlow = placed
		end
	end

	local lastStar: Attachment? = nil
	local lastWidth = 0
	for index = 1, segments do
		local size = SerpentBody.sizeOf(index, segments, BODY.firstSize, BODY.lastSize)
		local across, along = SerpentBody.stretchOf(size, MODEL.SEGMENT_SIZE, MODEL.LENGTH_FLOOR)
		local starName = if SerpentBody.starred(index, BODY.starEvery) then "SegmentStars" else "SegmentStar"
		local pieces: { Placed } = {}
		for _, name in { "SegmentBody", "SegmentRing", starName } do
			table.insert(pieces, copy(segment[name], model, colourOf(name), across, along))
		end
		local star = pieces[3].part
		-- The line runs through the back star: the flank stars' piece is centred lower, between
		-- its three stars, so measure the back star from the plain piece.
		local back = segment.SegmentStar.offset.Position * Vector3.new(across, across, along)
		local point = attachment(star, (pieces[3].offset:Inverse() * CFrame.new(back)).Position)
		local width = size * MODEL.LINE_WIDTH
		if lastStar then
			line(lastStar, point, lastWidth, width)
		end
		lastStar, lastWidth = point, width
		table.insert(visual.segments, { pieces = pieces, star = star })
	end

	for _, name in TAIL_PIECES do
		table.insert(visual.tail, copy(tail[name], model, colourOf(name)))
	end
	local tailBody = visual.tail[1]
	local exit = (tailBody.offset:Inverse() * tail.JetPoint.offset).Position
	-- The tail looks towards the head (-Z): its jet points +Z, in the tail body's own axes.
	jet(tailBody.part, exit, tailBody.offset.Rotation:Inverse() * Vector3.zAxis)

	for _, placed in visual.head do
		table.insert(visual.parts, placed.part)
	end
	for _, placed in visual.egg do
		table.insert(visual.parts, placed.part)
	end
	for _, item in visual.segments do
		for _, placed in item.pieces do
			table.insert(visual.parts, placed.part)
		end
	end
	for _, placed in visual.tail do
		table.insert(visual.parts, placed.part)
	end
	model.Parent = parent
	-- After the player's jetpack (AssetQueue): a hunt can be on as the player joins.
	local assets: { AssetQueue.Asset } = {}
	for _, part in visual.parts do
		table.insert(assets, part)
	end
	AssetQueue.later("serpent", LoadConfig.PRIORITY.SERPENT, assets)
	return visual
end

-- Shows the star egg in its cradle while it is inside the serpent and paints the eyes by the
-- hunt's phase: gold while it carries the egg, red once it guards it.
function SerpentVisual.setEgg(visual: Visual, place: SerpentHunt.EggPlace?)
	local inside = place == nil or place == "Inside"
	visual.eggShown = inside
	for _, placed in visual.egg do
		placed.part.Transparency = if inside then 0 else 1
	end
	local colour = if place == "Out" then MODEL.EYE_GUARDING else MODEL.EYE_CARRYING
	for _, eye in visual.eyes do
		eye.Color = colour
	end
end

-- Puts the head's pieces on `head` (the server's head), each segment on `points` (from the
-- neck back; one more for the tail), each facing the point before it (`neck` for the first).
-- `clock` turns the egg.
function SerpentVisual.place(visual: Visual, head: CFrame, neck: Vector3, points: { Vector3 }, clock: number)
	local frames = visual.frames
	local n = 0
	local function put(at: CFrame, placed: Placed)
		n += 1
		frames[n] = at * placed.offset
	end
	for _, placed in visual.head do
		put(head, placed)
	end
	for _, placed in visual.egg do
		if placed == visual.eggGlow then
			n += 1
			frames[n] = head * placed.offset * CFrame.Angles(0, clock * MODEL.EGG_SPIN, 0)
		else
			put(head, placed)
		end
	end
	local previous = neck
	local function frameAt(point: Vector3): CFrame
		local at = if (previous - point).Magnitude > 1e-3
			then CFrame.lookAt(point, previous)
			else CFrame.new(point) * head.Rotation
		previous = point
		return at
	end
	for index, item in visual.segments do
		local at = frameAt(points[index] or previous)
		for _, placed in item.pieces do
			put(at, placed)
		end
	end
	local tailAt = frameAt(points[#visual.segments + 1] or previous)
	for _, placed in visual.tail do
		put(tailAt, placed)
	end
	workspace:BulkMoveTo(visual.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function SerpentVisual.destroy(visual: Visual)
	visual.model:Destroy()
end

return table.freeze(SerpentVisual)
