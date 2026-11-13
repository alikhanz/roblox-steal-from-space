--!strict
-- The pets' living motion (plan docs/plans/ALIEN_MODELS.md, step 3), as the pet gallery prototype
-- had it (docs/design/prototypes/pet-look/gallery_client.luau, approved by the user). The server
-- stands each pet's box (World/AlienModel, tag BayConfig.ALIEN_TAG); AlienViewController builds the
-- pets near the camera in their boxes (decision 123) and hands them here (`track`), and every one
-- of them moves, all in one BulkMoveTo a frame. One standing small on the floor
-- (BayConfig.ALIEN_PLAIN_ATTRIBUTE) is not handed here: it stands as it is.
--
-- Detail by distance (plan step 4, PetMotion.detail, AlienLooks.MOTION): near pets are drawn and
-- moved in full; in the middle distance only their main particle layers stay, without the light,
-- moving every other frame; far ones stand still with no particles, light or pictures. A phone
-- warmed up at once with thirty pets in full. A pet hidden for a while (its island far off, kept
-- to show again at once) is out of the world and skipped.
--
-- When the bay's layout moves a pet to another place (BayConfig.ALIEN_PIVOT_ATTRIBUTE), it glides
-- there with its place (PlaceGlideController) rather than jump.
--
-- The whole pet bobs and sways, turns to a player close by, and a slime's jelly squashes and hops;
-- how each moving part moves (claws, legs, segments, fins, wings, drones, comets, blinks) is
-- World/RigMotion, shared with the guardians. Its light breathes and its pictures (the medal, the
-- crest) turn.
--
-- The frame's work is kept small (it was most of the client's time with thirty pets, 2026-11-10):
-- what each part does is worked out once, as the pet arrives (RigMotion.read), and the parts never
-- seen (hinge markers, Blender's hidden flames and rays) are not moved at all.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local PetMotion = require(ReplicatedStorage.Shared.Domain.PetMotion)
local RigMotion = require(script.Parent.Parent.World.RigMotion)

local MOTION = AlienLooks.MOTION
local LOOK_LIMIT = math.rad(MOTION.LOOK_LIMIT_DEGREES)
-- The part the bay's label hangs on (the pet's box, World/AlienModel; the pet's own copy of it,
-- AlienDress's, is not moved): it stays put, so the label does not bob.
local LABEL_PART = "Body"
-- The dressing's effects carrier: only a dressed pet has it.
local EFFECTS_PART = "Fx"

export type AlienMotionController = {
	name: string,
	start: () -> (),
	-- Moves `look`, a pet built in its box `stand` (both in the world), from now on: its effects
	-- are on it already (AlienDress.adornLocally). A fresh one pops onto its place first.
	track: (look: Model, stand: Model) -> (),
	-- Stops moving `look` (taken apart).
	untrack: (look: Model) -> (),
}

-- The pet on its way to where the bay's layout moved it (BayLooks.LAYOUT_GLIDE_SECONDS).
type Glide = {
	from: CFrame,
	to: CFrame,
	start: number,
}

type Picture = {
	image: ImageLabel,
	-- Degrees a second, or nil for a slow sway from `sway`.
	spin: number?,
	sway: number,
}

type Pet = {
	look: Model,
	base: CFrame,
	glide: Glide?,
	-- The part the bay's label hangs on, and where it sits in the pet's space: it never moves,
	-- but glides with the pet.
	label: BasePart?,
	labelOffset: CFrame,
	rig: RigMotion.Rig,
	pictures: { Picture },
	-- Steady particle layers: the secondary ones and the main ones (AlienLooks.MOTION.MAIN_EFFECTS).
	effects: { ParticleEmitter | Trail | Beam },
	mainEffects: { ParticleEmitter | Trail | Beam },
	boards: { BillboardGui },
	-- How much of it is drawn and moved now (PetMotion.detail); nil until first seen.
	detail: number?,
	-- Which frames it moves on in the middle distance (every other one).
	frameSlot: number,
	light: PointLight?,
	brightness: number,
	yaw: number,
	hopAt: number,
	hopStart: number?,
}

local AlienMotionController = {}

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- Reads a dressed pet once: its moving parts (RigMotion) and what else it shows (its box's label
-- part, its light, pictures and effect layers).
local function petOf(model: Model, stand: Model): Pet?
	if not model:FindFirstChild(EFFECTS_PART) then
		return nil
	end
	-- Where the server stood it (its parts are read relative to that, at rest as they are built).
	local pivot = stand:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
	local base = if typeof(pivot) == "CFrame" then pivot else model:GetPivot()
	local uid = stand:GetAttribute(BayConfig.ALIEN_UID_ATTRIBUTE)
	local random = Random.new(if type(uid) == "number" then uid else 1)
	local now = os.clock()
	local rig = RigMotion.read(model, base, random, {
		skip = LABEL_PART,
		scale = model:GetScale() / AlienLooks.MODELS.DRESS_SCALE,
		now = now,
	})
	local pet: Pet = {
		look = model,
		base = base,
		glide = nil,
		label = nil,
		labelOffset = CFrame.identity,
		rig = rig,
		pictures = {},
		effects = {},
		mainEffects = {},
		boards = {},
		detail = nil,
		frameSlot = random:NextInteger(0, 1),
		light = nil,
		brightness = 0,
		yaw = 0,
		hopAt = now + random:NextNumber(2, 8),
		hopStart = nil,
	}
	local label = stand:FindFirstChild(LABEL_PART)
	if label and label:IsA("BasePart") then
		pet.label = label
		pet.labelOffset = base:ToObjectSpace(label.CFrame)
	end
	for _, item in model:GetDescendants() do
		if item:IsA("PointLight") then
			pet.light, pet.brightness = item, item.Brightness
		elseif item:IsA("ImageLabel") and (item:GetAttribute("Spin") or item:GetAttribute("Sway")) then
			table.insert(pet.pictures, {
				image = item,
				spin = tonumber(item:GetAttribute("Spin")),
				sway = tonumber(item:GetAttribute("Sway")) or 0,
			})
		end
		-- What the detail turns off and on: the steady particle layers, the ribbons (wing strokes,
		-- comet tails) and the beams (jet flames), the main ones apart; the pictures (medal, crest).
		if (item:IsA("ParticleEmitter") and item.Rate > 0) or item:IsA("Trail") or item:IsA("Beam") then
			table.insert(if MOTION.MAIN_EFFECTS[item.Name] then pet.mainEffects else pet.effects, item)
		elseif item:IsA("BillboardGui") then
			table.insert(pet.boards, item)
		end
	end
	return pet
end

-- A slime's jelly this frame: how much taller than at rest it is, and how high a hop lifts it
-- (a share of its height).
local function jelly(pet: Pet, t: number): (number, number)
	local stretch = MOTION.JELLY_REST * math.sin(t * 2.6 + pet.rig.phase)
	local lift = 0
	if pet.hopStart then
		local since = t - pet.hopStart
		local hopStretch, hopLift = PetMotion.hop(since, MOTION.HOP_HEIGHT)
		stretch += hopStretch
		lift = hopLift
		if since >= PetMotion.HOP_SECONDS then
			pet.hopStart = nil
			pet.hopAt = t + between(pet.rig.random, MOTION.HOP_EVERY)
		end
	elseif t >= pet.hopAt then
		pet.hopStart = t
	end
	return stretch, lift
end

-- Where each part of `pet` goes this frame: appends the parts and their frames.
local function move(pet: Pet, t: number, dt: number, root: BasePart?, parts: { BasePart }, frames: { CFrame })
	local rig = pet.rig
	local ph = rig.phase
	-- Turn to a player close by, smoothly, never further than LOOK_LIMIT (the pet faces -Z).
	local wanted = 0
	if root then
		local away = pet.base:PointToObjectSpace(root.Position)
		if Vector2.new(away.X, away.Z).Magnitude < MOTION.LOOK_RADIUS + rig.radius then
			wanted = math.clamp(math.atan2(-away.X, -away.Z), -LOOK_LIMIT, LOOK_LIMIT)
		end
	end
	pet.yaw += (wanted - pet.yaw) * math.min(1, dt * 2.5)
	local stretch, lift = 0, 0
	local floor = rig.jellyFloor
	if rig.family == "slime" and floor then
		stretch, lift = jelly(pet, t)
	end
	local squash: RigMotion.Squash? = nil
	if stretch ~= 0 and floor then
		local sy = 1 + stretch
		squash = { floor = floor, sy = sy, sxz = 1 / math.sqrt(sy) }
	end
	local c = CFrame.new(rig.centre)
	local bob = pet.base
		* CFrame.new(0, math.sin(t * 2 + ph) * MOTION.BOB * rig.scale + lift * rig.height, 0)
		* c
		* CFrame.Angles(0, pet.yaw, 0)
		* c:Inverse()
		* CFrame.Angles(math.sin(t * 1.1 + ph) * 0.05, math.sin(t * 0.6 + ph) * 0.14, math.sin(t * 1.4 + ph) * 0.05)
	RigMotion.pose(rig, t, bob, pet.base, squash, parts, frames)
	if pet.light then
		pet.light.Brightness = pet.brightness + math.sin(t * 3 + ph) * 0.4
	end
	for _, picture in pet.pictures do
		local spin = picture.spin
		picture.image.Rotation = if spin then t * spin else math.sin(t * 0.8 + picture.sway) * 2
	end
end

-- Draws `pet` at `detail` (PetMotion.detail): all its effects, light and pictures; only its main
-- particle layers; or none of them.
local function setDetail(pet: Pet, detail: number)
	pet.detail = detail
	for _, effect in pet.effects do
		effect.Enabled = detail == 1
	end
	for _, effect in pet.mainEffects do
		effect.Enabled = detail <= 2
	end
	for _, board in pet.boards do
		board.Enabled = detail <= 2
	end
	if pet.light then
		pet.light.Enabled = detail == 1
	end
end

-- Moves a pet on its way to a new place one frame along (its label part too): true while it is
-- on the way, the last frame included.
local function glide(pet: Pet, t: number, parts: { BasePart }, frames: { CFrame }): boolean
	local way = pet.glide
	if not way then
		return false
	end
	local u = (t - way.start) / BayLooks.LAYOUT_GLIDE_SECONDS
	if u >= 1 then
		pet.base = way.to
		pet.glide = nil
	else
		pet.base = way.from:Lerp(way.to, PetMotion.smooth(u))
	end
	local label = pet.label
	if label then
		table.insert(parts, label)
		table.insert(frames, pet.base * pet.labelOffset)
	end
	return true
end

-- Overshoots a little past 1 and settles (an "ease out back").
local function backOut(u: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

-- A fresh alien (just hatched, crossbred or moved onto a place) pops onto its place: it grows from
-- a share of its size, a little past full and back, its feet on the pad all the while. Yields for
-- the pop; its motion begins after it. Only one built as the server stood its box pops: built
-- later (the player came near), it just stands there.
local function popIn(model: Model, stand: Model)
	local shownAt = stand:GetAttribute(BayConfig.ALIEN_SHOWN_AT_ATTRIBUTE)
	local pop = BayLooks.ALIEN_POP
	if
		type(shownAt) ~= "number"
		or workspace:GetServerTimeNow() - shownAt > pop.freshSeconds
		or GuiService.ReducedMotionEnabled
	then
		return
	end
	local lift = tonumber(stand:GetAttribute(BayConfig.ALIEN_LIFT_ATTRIBUTE)) or 0
	local full = model:GetScale()
	local start = os.clock()
	while model:IsDescendantOf(workspace) do
		local u = math.min((os.clock() - start) / pop.seconds, 1)
		local k = pop.from + (1 - pop.from) * backOut(u)
		-- Where it stands now: the layout may move its place while it pops (several aliens come
		-- at once), and it must land there, not where it appeared.
		local pivot = stand:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
		local floor = (if typeof(pivot) == "CFrame" then pivot else model:GetPivot()) * CFrame.new(0, -lift, 0)
		model:ScaleTo(full * k)
		model:PivotTo(floor * CFrame.new(0, lift * k, 0))
		if u >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

function AlienMotionController.new(): AlienMotionController
	local pets: { [Model]: Pet } = {}
	local moves: { [Model]: RBXScriptConnection } = {}

	local function untrack(look: Model)
		pets[look] = nil
		local connection = moves[look]
		if connection then
			connection:Disconnect()
			moves[look] = nil
		end
	end

	local function track(look: Model, stand: Model)
		task.spawn(function()
			popIn(look, stand)
			if not look:IsDescendantOf(workspace) or pets[look] then
				return
			end
			local pet = petOf(look, stand)
			if not pet then
				return
			end
			pets[look] = pet
			-- The bay's layout moved it to another place: it glides there from where it stands, and
			-- the motion goes round its new pivot (the server's move of its box is overridden every
			-- frame on the way).
			moves[look] = stand:GetAttributeChangedSignal(BayConfig.ALIEN_PIVOT_ATTRIBUTE):Connect(function()
				local pivot = stand:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
				if typeof(pivot) == "CFrame" then
					pet.glide = { from = pet.base, to = pivot, start = os.clock() }
				end
			end)
		end)
	end

	local last = os.clock()
	local frame = 0
	local function step()
		local t = os.clock()
		local dt = math.min(t - last, 0.1)
		last = t
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local character = Players.LocalPlayer.Character
		local found = character and character:FindFirstChild("HumanoidRootPart")
		local root = if found and found:IsA("BasePart") then found else nil
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		frame += 1
		for _, pet in pets do
			-- Hidden for a while (AlienViewController): out of the world until it shows again.
			if not pet.look.Parent then
				continue
			end
			local gliding = glide(pet, t, parts, frames)
			local distance = (pet.base.Position - eye).Magnitude
			local radius = pet.rig.radius
			local detail = PetMotion.detail(distance, radius, pet.detail, MOTION.NEAR, MOTION.FAR, MOTION.DETAIL_MARGIN)
			if detail ~= pet.detail then
				setDetail(pet, detail)
			end
			-- Close by: every frame; farther, every other one (half the work, still smooth from
			-- there); far pets stand still. On its way to a new place, every frame.
			if (detail == 1 and distance <= MOTION.SMOOTH + radius) or (gliding and detail <= 2) then
				move(pet, t, dt, root, parts, frames)
			elseif detail <= 2 and frame % 2 == pet.frameSlot then
				move(pet, t, dt * 2, root, parts, frames)
			elseif gliding then
				RigMotion.rest(pet.rig, pet.base, parts, frames)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	local function start()
		RunService.RenderStepped:Connect(step)
	end

	return {
		name = "AlienMotionController",
		start = start,
		track = track,
		untrack = untrack,
	}
end

return table.freeze(AlienMotionController)
