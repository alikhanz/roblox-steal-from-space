--!strict
-- A guardian's look on this client (docs/plans/GUARDIANS.md, step 4). The server's guardian is a
-- greybox body that moves and catches; here it wears its post's model (ReplicatedStorage.Guardians,
-- GuardianLooks.MODELS): painted once (AlienDress.paintModel), copied at the post's size, carried
-- on the body every frame, its parts moving near the camera (RigMotion) at a pace, with a jaw and a
-- throat, by the guardian's state; its eyes glow in the state's colour; it lunges and snaps when
-- it catches someone. The model never crosses the network. A post with no model in the place
-- keeps the greybox, and so does a guardian far from the camera: GuardianViewController attaches
-- the model only near it and detaches it again (decision 101), so a post's meshes are fetched only
-- once one of its guardians is near.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienDress = require(ReplicatedStorage.Shared.World.AlienDress)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AssetQueue = require(script.Parent.Parent.Loading.AssetQueue)
local GuardianBrain = require(ReplicatedStorage.Shared.Domain.GuardianBrain)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local GuardianPose = require(ReplicatedStorage.Shared.Domain.GuardianPose)
local LoadConfig = require(ReplicatedStorage.Shared.Config.LoadConfig)
local RigMotion = require(script.Parent.RigMotion)

local MODELS = GuardianLooks.MODELS

local GuardianVisual = {}

-- A post's model, painted, at the scale it was made, and its longest side across (X or Z).
type Template = {
	model: Model,
	span: number,
}

type Maw = {
	part: BasePart,
	colour: Color3,
}

export type Visual = {
	model: Model,
	body: BasePart,
	rig: RigMotion.Rig,
	eyes: { BasePart },
	maws: { Maw },
	-- Half its length and its length, studs.
	radius: number,
	length: number,
	-- Its own clock: runs at its pace (a chase is quicker).
	clock: number,
	tempo: number,
	state: GuardianBrain.State,
	strikeAt: number?,
	-- Whether its parts move now (near the camera), and its throat's glow as last drawn.
	moving: boolean,
	glow: number,
	-- Its signature's particles and beams: they play only while its parts move (near the camera).
	effects: { ParticleEmitter | Beam },
	effectsOn: boolean,
	-- Where it was carried last (a far one still is not moved again).
	origin: CFrame?,
	-- Where its body was drawn last frame while near (GuardianPose.follow); nil while far.
	shown: CFrame?,
}

-- Templates by post; false where the place has no model.
local templates: { [string]: Template | false } = {}

local function sourceOf(part: Instance): string
	local code = part:GetAttribute("Paint")
	return if type(code) == "string" then string.match(code, ",(%a*)$") or "" else ""
end

local function colourOf(hex: any): Color3
	local ok, colour = pcall(Color3.fromHex, tostring(hex))
	return if ok then colour else Color3.new(1, 1, 1)
end

local function templateOf(postId: string): Template?
	local cached = templates[postId]
	if cached ~= nil then
		return cached or nil
	end
	local folder = ReplicatedStorage:FindFirstChild(MODELS.FOLDER_NAME)
	local source = folder and folder:FindFirstChild(postId)
	if not (source and source:IsA("Model")) then
		templates[postId] = false
		warn(`[GuardianVisual] No model for {postId} in ReplicatedStorage.{MODELS.FOLDER_NAME}; the greybox stands in`)
		return nil
	end
	local model = source:Clone()
	local core = colourOf(model:GetAttribute("Core"))
	AlienDress.paintModel(model, core)
	-- Its kind's effects, made at the scale the pets' were tuned at; they scale with the model.
	local scale = model:GetScale()
	model:ScaleTo(AlienLooks.MODELS.DRESS_SCALE)
	AlienDress.adornSignature(model, core)
	model:ScaleTo(scale)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			-- 132 guardians: their shadows would cost more than they show in open space.
			part.CastShadow = false
			if string.match(part.Name, "^core_") then
				part.Color = part.Color:Lerp(Color3.new(0, 0, 0), MODELS.CORE_DIM)
			end
		end
	end
	local _, size = model:GetBoundingBox()
	local template = { model = model, span = math.max(size.X, size.Z) }
	templates[postId] = template
	return template
end

-- Paints the eyes in `state`'s colour.
function GuardianVisual.setState(visual: Visual, state: GuardianBrain.State)
	visual.state = state
	local colour = GuardianLooks.EYE_COLORS[state] or GuardianLooks.EYE_COLORS.Sleep
	for _, eye in visual.eyes do
		eye.Color = colour
	end
end

-- Dresses `body` (a guardian of `post`) in its post's model, under `parent`; nil where the place
-- has no model for the post. `seed` keeps each guardian's rhythm its own.
function GuardianVisual.attach(body: BasePart, post: GuardianConfig.Post, parent: Instance, seed: number): Visual?
	local template = templateOf(post.id)
	if not template then
		return nil
	end
	local box = GuardianLooks.KINDS[post.kind].bodySize
	local look = GuardianLooks.POSTS[post.id]
	local model = template.model:Clone()
	model.Name = post.id
	model:ScaleTo(GuardianPose.fitScale(template.span, math.max(box.X, box.Z), look.scale))
	model:PivotTo(body.CFrame)
	local eyes: { BasePart } = {}
	local maws: { Maw } = {}
	local meshes: { AssetQueue.Asset } = {}
	local effects: { ParticleEmitter | Beam } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("ParticleEmitter") or part:IsA("Beam") then
			part.Enabled = false
			table.insert(effects, part)
		end
		if not part:IsA("BasePart") then
			continue
		end
		table.insert(meshes, part)
		local source = sourceOf(part)
		if source == MODELS.EYE_SOURCE then
			table.insert(eyes, part)
		elseif source == MODELS.MAW_SOURCE then
			table.insert(maws, { part = part, colour = part.Color })
		end
	end
	model.Parent = parent
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Z)
	local visual: Visual = {
		model = model,
		body = body,
		rig = RigMotion.read(model, model:GetPivot(), Random.new(seed), { scale = model:GetScale(), now = 0 }),
		eyes = eyes,
		maws = maws,
		radius = length / 2,
		length = length,
		clock = 0,
		tempo = GuardianLooks.STATE_MOTION.Sleep.tempo,
		state = "Sleep",
		strikeAt = nil,
		moving = false,
		glow = -1,
		effects = effects,
		effectsOn = false,
		origin = nil,
		shown = nil,
	}
	-- Many new meshes at once: ask for them all, or some stay unloaded (after the jetpack, AssetQueue).
	AssetQueue.later(`guardian model {model.Name}`, LoadConfig.PRIORITY.GUARDIAN, meshes)
	return visual
end

-- A catch: a lunge ahead and a snap of the jaws, starting at `now` (os.clock()).
function GuardianVisual.strike(visual: Visual, now: number)
	visual.strikeAt = now
end

function GuardianVisual.detach(visual: Visual)
	visual.model:Destroy()
end

-- The throat glows brighter the fiercer the guardian: drawn only when the glow changes.
local function glowMaw(visual: Visual, glow: number)
	if math.abs(glow - visual.glow) < 0.02 then
		return
	end
	visual.glow = glow
	for _, maw in visual.maws do
		maw.part.Color = Color3.new(0, 0, 0):Lerp(maw.colour, glow)
	end
end

-- Where a near guardian's body is drawn this frame: following the server's body smoothly
-- (GuardianPose.follow), its turns eased like the star serpent's head, so the steps in which the
-- body's motion arrives do not jerk the model. Put straight on the body when it comes near or
-- has gone far off (streamed in, teleported).
local function follow(visual: Visual, dt: number): CFrame
	local body = visual.body.CFrame
	local shown = visual.shown
	if not shown or (body.Position - shown.Position).Magnitude > MODELS.SNAP_DISTANCE then
		return body
	end
	local position = GuardianPose.follow(
		shown.Position,
		visual.body.AssemblyLinearVelocity,
		body.Position,
		dt,
		MODELS.FOLLOW_SECONDS
	)
	return CFrame.new(position) * shown.Rotation:Lerp(body.Rotation, GuardianPose.share(dt, MODELS.TURN_SECONDS))
end

-- Carries every guardian of `visuals` on its body this frame (`now`: os.clock(), `dt` since the
-- last frame), moving the parts of those near `eye` (the camera), in one BulkMoveTo.
function GuardianVisual.step(visuals: { [any]: Visual }, now: number, dt: number, eye: Vector3)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, visual in visuals do
		local motion = GuardianLooks.STATE_MOTION[visual.state] or GuardianLooks.STATE_MOTION.Sleep
		visual.tempo = GuardianPose.ease(visual.tempo, motion.tempo, dt, MODELS.TEMPO_EASE_SECONDS)
		visual.clock += dt * visual.tempo
		local lunge, snap = 0, 0
		local strikeAt = visual.strikeAt
		if strikeAt then
			lunge, snap = GuardianPose.strike(now - strikeAt, MODELS.STRIKE_SECONDS)
			if now - strikeAt >= MODELS.STRIKE_SECONDS then
				visual.strikeAt = nil
			end
		end
		local rig = visual.rig
		rig.mouth = motion.mouth + snap * MODELS.STRIKE_MOUTH
		glowMaw(visual, math.max(motion.maw, snap))
		local body = visual.body.CFrame
		local distance = (body.Position - eye).Magnitude
		local reach = MODELS.MOTION_DISTANCE + visual.radius + (if visual.moving then MODELS.MOTION_MARGIN else 0)
		visual.moving = distance <= reach
		if visual.moving ~= visual.effectsOn then
			visual.effectsOn = visual.moving
			for _, effect in visual.effects do
				effect.Enabled = visual.moving
			end
		end
		if visual.moving then
			local shown = follow(visual, dt)
			visual.shown = shown
			visual.origin = nil
			local bob = math.sin(visual.clock * 2 + rig.phase) * MODELS.BOB * rig.height
			-- The model faces -Z, as the body does (GuardianService turns it along its way).
			local origin = shown * CFrame.new(0, bob, -lunge * MODELS.STRIKE_LUNGE * visual.length)
			RigMotion.pose(rig, visual.clock, origin, origin, nil, parts, frames)
		elseif visual.origin ~= body then
			-- Far: still, carried whole with its body (only when the body has moved).
			visual.shown = nil
			RigMotion.rest(rig, body, parts, frames)
			visual.origin = body
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return table.freeze(GuardianVisual)
