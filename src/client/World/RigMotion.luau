--!strict
-- How the moving parts of a robot model move, for the pets (AlienMotionController) and the
-- guardians (GuardianMotionController) alike: the parts tell what they are by their Role
-- attribute (AlienDress), hinges are points (attachments, lune/lib/ModelPack.luau) named
-- `hinge<Name>` (`hingeJawL` turns `jawL`). What each part does is worked out once, as the model
-- arrives (a Mover); each frame `pose` gives every moving part its frame.
--
-- Each family moves its own way: a slime's jelly squashes (the controller passes the squash), a
-- crab snaps its claws and steps, a worm waves its segments and looks round, a ray beats its fins
-- and wags its tail, a whale rows and beats its flukes, a swarm's little drones fly loops of their
-- own; wings flap, rotors spin, comets circle, eyes blink. A guardian also swings its arms, opens
-- its jaw (Rig.mouth, set by its controller) and its hunters circle it as a flock.
--
-- Lengths are made at the dressing scale and grow with the model (Rig.scale); the model's own
-- clock (`t`) may run faster or slower than the world's: a guardian in a chase moves quicker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local PetMotion = require(ReplicatedStorage.Shared.Domain.PetMotion)

local MOTION = AlienLooks.MOTION

local RigMotion = {}

-- What a part does, worked out once (Mover.kind).
local STATIC = 1 -- rides with the body
local HALO = 2 -- the rune circle: stays on the floor, turning
local ROTOR = 3
local ORBIT = 4
local RAYS = 5
local WING = 6
local JAW = 7 -- a crab's jaw
local MAND = 8 -- a devourer's mandible
local LEG = 9
local SEG = 10 -- a worm's segment
local FIN = 11 -- a ray's fin, inner or outer
local TAIL = 12 -- a bead of a ray's tail
local BUZZ = 13 -- the lead drone's little wing
local FLIPPER = 14
local FLUKES = 15
local WISP = 16 -- a comet
local DRONE = 17 -- a little drone, its mandible or its wing (Mover.droneKind)
local ARM = 18 -- a guardian slime's arm
local MOUTH = 19 -- a guardian's lower jaw (role jaw)
local FLOCK = 20 -- a guardian swarm's hunters

type Snap = {
	nextAt: number,
	start: number?,
	twice: boolean,
}

-- A little drone's loop round its model: a closed curve through points in the model's space.
type Path = {
	points: { Vector3 },
	home: Vector3,
	period: number,
}

-- A part that moves, and how.
type Mover = {
	part: BasePart,
	-- Where it rests in the model's space, and its size there.
	offset: CFrame,
	size: Vector3,
	kind: number,
	-- The point it turns about, in the model's space (unused where it does not turn).
	hinge: Vector3,
	-- An outer fin's own joint, past the fin's root.
	joint: Vector3?,
	-- Which side it sits on: 1 at +X, -1 at -X.
	out: number,
	-- A segment's, a bead's or a leg's place in its row; a drone's number.
	k: number,
	-- Which jaw it keeps time with: true for the left one.
	left: boolean,
	-- A crab's top jaw (it opens up; the bottom one down).
	top: boolean,
	-- A drone's own body (0), its mandible (1) or its wing (2).
	droneKind: number,
	-- A glowing eye: it blinks.
	eye: boolean,
	-- Above a slime's jelly floor: squashed with the jelly; `squashSize` stretches its size too.
	aboveFloor: boolean,
	squashSize: boolean,
	-- Turns with a worm's head.
	headTurns: boolean,
	-- A comet's orbit (studs at the dressing scale), tilt, speed and phase.
	orbit: number,
	tilt: number,
	speed: number,
	phase: number,
}

-- A model's moving parts and the rhythm they keep.
export type Rig = {
	family: string,
	phase: number,
	random: Random,
	-- Against the dressing scale: lengths made there grow by this.
	scale: number,
	-- Half its widest span and its height, studs.
	radius: number,
	height: number,
	-- The model's middle in its own space.
	centre: Vector3,
	movers: { Mover },
	-- The middle of each role's parts, in the model's space.
	groups: { [string]: Vector3 },
	hinges: { [string]: Vector3 },
	paths: { [number]: Path },
	-- Where a slime's jelly starts (above its solid base), in the model's space.
	jellyFloor: number?,
	-- How far a guardian's lower jaw is open, radians (its controller sets it).
	mouth: number,
	blinkAt: number,
	blinkStart: number?,
	blinkTwice: boolean,
	jawL: Snap,
	jawR: Snap,
}

-- A slime's jelly this frame (the pets' controller works it out): how much taller than at rest it
-- is, the squash's floor and its sideways squeeze.
export type Squash = {
	floor: number,
	sy: number,
	sxz: number,
}

export type ReadOptions = {
	-- A part to leave out (the bay's label part: it never moves).
	skip: string?,
	-- Against the dressing scale (see Rig.scale).
	scale: number,
	-- The clock the rhythms start from.
	now: number,
}

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- Turns about `pivot` (a point in the model's space) by `turn`.
local function about(pivot: Vector3, turn: CFrame): CFrame
	return CFrame.new(pivot) * turn * CFrame.new(-pivot)
end

-- A point on a closed Catmull-Rom loop through `points` (a chain of cubic curves that passes
-- through every point), `u` from 0 to 1 round the loop.
local function loop(points: { Vector3 }, u: number): Vector3
	local count = #points
	local at = (u % 1) * count
	local i = math.floor(at)
	local f = at - i
	local p0 = points[(i - 1) % count + 1]
	local p1 = points[i % count + 1]
	local p2 = points[(i + 1) % count + 1]
	local p3 = points[(i + 2) % count + 1]
	return 0.5
		* (2 * p1 + (p2 - p0) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (3 * p1 - p0 - 3 * p2 + p3) * f * f * f)
end

-- A frame squashed about the jelly's floor: up and down by `sy`, sideways by `sxz` round the
-- model's centre line.
local function squashed(frame: CFrame, floor: number, centre: Vector3, sy: number, sxz: number): CFrame
	local p = frame.Position
	local moved =
		Vector3.new(centre.X + (p.X - centre.X) * sxz, floor + (p.Y - floor) * sy, centre.Z + (p.Z - centre.Z) * sxz)
	return frame - p + moved
end

-- A part's size under the squash: each of its own axes stretched by how much it points up or
-- sideways in the model.
local function squashedSize(size: Vector3, frame: CFrame, sy: number, sxz: number): Vector3
	local function along(axis: Vector3): number
		local v = frame:VectorToWorldSpace(axis)
		return math.sqrt((v.X * sxz) ^ 2 + (v.Y * sy) ^ 2 + (v.Z * sxz) ^ 2)
	end
	return Vector3.new(size.X * along(Vector3.xAxis), size.Y * along(Vector3.yAxis), size.Z * along(Vector3.zAxis))
end

-- The little drones' loops: each flies a smooth closed curve through six points round the model,
-- starting where it rests, each a little nearer or farther and higher or lower.
local function dronePaths(rig: Rig): { [number]: Path }
	local paths: { [number]: Path } = {}
	for role, home in rig.groups do
		local n = tonumber(string.match(role, "^drone(%d+)$"))
		if not n then
			continue
		end
		local away = Vector3.new(home.X - rig.centre.X, 0, home.Z - rig.centre.Z)
		local reach = away.Magnitude
		local start = math.atan2(away.Z, away.X)
		local points: { Vector3 } = {}
		for i = 0, 5 do
			local angle = start + i * math.pi / 3
			-- Never nearer than its rest spot: closer in, a drone grazes the lead.
			local radius = if i == 0 then reach else reach * rig.random:NextNumber(1.0, 1.3)
			local rise = if i == 0 then 0 else reach * rig.random:NextNumber(-0.3, 0.3)
			table.insert(
				points,
				Vector3.new(
					rig.centre.X + math.cos(angle) * radius,
					home.Y + rise,
					rig.centre.Z + math.sin(angle) * radius
				)
			)
		end
		paths[n] = { points = points, home = home, period = rig.random:NextNumber(3.5, 5.5) }
	end
	return paths
end

-- A part as it was read, before its mover is worked out (the hinges must all be known first).
type Found = {
	part: BasePart,
	role: string,
	offset: CFrame,
	eye: boolean,
}

-- What `found` does in `rig` (nil: nothing to move, a part never seen).
local function moverOf(rig: Rig, found: Found): Mover?
	local part, role, offset = found.part, found.role, found.offset
	-- Never seen and carrying nothing: a hinge marker, Blender's hidden flame or rays, the floor
	-- ring the rune replaced.
	if part.Transparency >= 1 and #part:GetChildren() == 0 then
		return nil
	end
	local floor = rig.jellyFloor
	local mover: Mover = {
		part = part,
		offset = offset,
		size = part.Size,
		kind = STATIC,
		hinge = Vector3.zero,
		joint = nil,
		out = 1,
		k = 0,
		left = string.sub(role, -1) == "L",
		top = false,
		droneKind = 0,
		eye = found.eye,
		aboveFloor = floor ~= nil and offset.Position.Y > floor,
		squashSize = role == "body" and part.Name ~= "Fx",
		headTurns = true,
		orbit = 0,
		tilt = 0,
		speed = 0,
		phase = 0,
	}
	local side = string.sub(role, -1)
	local own = rig.hinges[role]
	local function turnsAbout(hinge: Vector3, kind: number)
		mover.kind = kind
		mover.hinge = hinge
		mover.out = if hinge.X > 0 then 1 else -1
	end
	local jawHinge = rig.hinges["jaw" .. side]
	local finRoot = rig.hinges["fin" .. side]
	local flukes = rig.hinges.flukes
	if role == "halo" then
		mover.kind = HALO
	elseif string.match(role, "^rotor[LR]?$") and rig.groups[role] then
		-- Each rotor spins about its own parts' middle (a guardian crab has two).
		turnsAbout(rig.groups[role], ROTOR)
	elseif role == "orbit" then
		mover.kind = ORBIT
		mover.headTurns = false
	elseif role == "rays" then
		mover.kind = RAYS
	elseif (role == "wingL" or role == "wingR") and own then
		turnsAbout(own, WING)
	elseif string.match(role, "^jaw%u%a%a[LR]$") and jawHinge then
		turnsAbout(jawHinge, JAW)
		mover.top = string.sub(role, 4, 6) == "Top"
	elseif role == "jaw" and own then
		turnsAbout(own, MOUTH)
	elseif (role == "armL" or role == "armR") and own then
		turnsAbout(own, ARM)
	elseif role == "hunters" then
		mover.kind = FLOCK
		mover.headTurns = false
	elseif (role == "mandL" or role == "mandR") and own then
		turnsAbout(own, MAND)
	elseif string.match(role, "^leg[LR]%u$") and own then
		turnsAbout(own, LEG)
		mover.k = string.byte(role, 5) - 64 + (if string.sub(role, 4, 4) == "L" then 0 else 1)
	elseif string.match(role, "^seg%u$") then
		mover.kind = SEG
		mover.k = string.byte(role, 4) - 64
		mover.headTurns = false
	elseif string.match(role, "^fin") and finRoot then
		turnsAbout(finRoot, FIN)
		if string.sub(role, 1, 8) == "finOuter" then
			mover.joint = rig.hinges["finOuter" .. side]
		end
	elseif string.match(role, "^tail%u$") then
		mover.kind = TAIL
		mover.k = string.byte(role, 5) - 64
	elseif (role == "buzzL" or role == "buzzR") and own then
		turnsAbout(own, BUZZ)
	elseif (role == "flipperL" or role == "flipperR") and own then
		turnsAbout(own, FLIPPER)
	elseif role == "flukes" and flukes then
		turnsAbout(flukes, FLUKES)
	elseif role == "wisp" then
		mover.kind = WISP
		mover.headTurns = false
		mover.tilt = tonumber(part:GetAttribute("Tilt")) or 0
		mover.speed = tonumber(part:GetAttribute("Speed")) or 1.6
		mover.phase = tonumber(part:GetAttribute("Phase")) or 0
		mover.orbit = tonumber(part:GetAttribute("Orbit")) or 0
	elseif string.match(role, "^drone%d") then
		mover.kind = DRONE
		mover.k = tonumber(string.match(role, "%d+")) or 0
		local centre = rig.groups["drone" .. mover.k]
		if own and centre then
			mover.hinge = own
			mover.out = if own.X > centre.X then 1 else -1
			if string.match(role, "Mand[LR]$") then
				mover.droneKind = 1
			elseif string.match(role, "Buzz[LR]$") then
				mover.droneKind = 2
			end
		end
	end
	return mover
end

-- Whether a paint code is a glowing eye's (a pet's EyeLight, a guardian's GuardianEye): it blinks.
local function isEye(paint: string): boolean
	return string.match(paint, ",EyeLight$") ~= nil or string.match(paint, ",GuardianEye$") ~= nil
end

-- Reads a model once: its parts in its own space (round `base`, where it stands at rest) and
-- what each of them does.
function RigMotion.read(model: Model, base: CFrame, random: Random, options: ReadOptions): Rig
	local cf, size = model:GetBoundingBox()
	local now = options.now
	local rig: Rig = {
		family = tostring(model:GetAttribute("Family") or ""),
		phase = random:NextNumber(0, 2 * math.pi),
		random = random,
		scale = options.scale,
		radius = math.max(size.X, size.Z) / 2,
		height = size.Y,
		centre = base:PointToObjectSpace(cf.Position),
		movers = {},
		groups = {},
		hinges = {},
		paths = {},
		jellyFloor = nil,
		mouth = 0,
		blinkAt = now + random:NextNumber(0.5, 4),
		blinkStart = nil,
		blinkTwice = false,
		jawL = { nextAt = now + random:NextNumber(0.5, 3), start = nil, twice = false },
		jawR = { nextAt = now + random:NextNumber(0.5, 3), start = nil, twice = false },
	}
	local found: { Found } = {}
	local sums: { [string]: { position: Vector3, count: number } } = {}
	-- A hinge, under the name of what turns on it: hingeL → wingL, hingeJawL → jawL, hingeLegLA →
	-- legLA, hingeFinOuterR → finOuterR, hingeHead → head, hingeJaw → jaw.
	local function addHinge(name: string, position: Vector3)
		if name == "hingeL" or name == "hingeR" then
			rig.hinges["wing" .. string.sub(name, -1)] = position
		elseif string.match(name, "^hinge%u") then
			rig.hinges[string.lower(string.sub(name, 6, 6)) .. string.sub(name, 7)] = position
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			if item.Name == options.skip and item.Parent == model then
				continue
			end
			local role = tostring(item:GetAttribute("Role") or "body")
			local offset = base:ToObjectSpace(item.CFrame)
			local paint = tostring(item:GetAttribute("Paint") or "")
			-- The glowing eyes blink (a model's eyes of one material are one part, at one height).
			table.insert(found, { part = item, role = role, offset = offset, eye = isEye(paint) })
			-- A slime's jelly starts a little above the bottom of its glass dome: the ceramic base
			-- and the feet under it stay solid.
			if string.match(paint, ",Dome$") then
				rig.jellyFloor = offset.Position.Y - item.Size.Y * 0.3
			end
			local sum = sums[role] or { position = Vector3.zero, count = 0 }
			sum.position += offset.Position
			sum.count += 1
			sums[role] = sum
			-- A model from before the markers became points still has them as parts.
			if string.match(role, "^hinge") then
				addHinge(role, offset.Position)
			end
		elseif item:IsA("Attachment") and string.match(item.Name, "^hinge") then
			addHinge(item.Name, base:PointToObjectSpace(item.WorldPosition))
		end
	end
	for role, sum in sums do
		rig.groups[role] = sum.position / sum.count
	end
	rig.paths = dronePaths(rig)
	for _, item in found do
		local mover = moverOf(rig, item)
		if mover then
			table.insert(rig.movers, mover)
		end
	end
	return rig
end

-- How far the eyes are open this frame; a new blink every few seconds, sometimes a double one.
local function eyeOpen(rig: Rig, t: number): number
	if t >= rig.blinkAt then
		rig.blinkStart = t
		rig.blinkTwice = rig.random:NextNumber() < 0.25
		rig.blinkAt = t + between(rig.random, MOTION.BLINK_EVERY)
	end
	return PetMotion.eyeOpen(t - (rig.blinkStart or -100), rig.blinkTwice)
end

-- How far a jaw is open this frame; a new snap every few seconds, sometimes a double one.
local function jawOpen(rig: Rig, jaw: Snap, t: number): number
	if t >= jaw.nextAt then
		jaw.start = t
		jaw.twice = rig.random:NextNumber() < 0.3
		jaw.nextAt = t + between(rig.random, MOTION.JAW_EVERY)
	end
	return PetMotion.jawOpen(t - (jaw.start or -100), jaw.twice, MOTION.JAW_OPEN)
end

-- Where each part of `rig` goes this frame at the model's own time `t`, `origin` being the
-- model's frame this frame (where it stands, bobbing and turning): appends the parts and their
-- frames. `ground`: where it stands, unmoved (what stays on the floor turns there); `squash`: a
-- slime's jelly this frame.
function RigMotion.pose(
	rig: Rig,
	t: number,
	origin: CFrame,
	ground: CFrame,
	squash: Squash?,
	parts: { BasePart },
	frames: { CFrame }
)
	local ph = rig.phase
	local c = CFrame.new(rig.centre)
	local cInv = c:Inverse()
	local beat = math.sin(t * 5 + ph)
	-- From the wings' 38° rest sweep: 11° to 45° back.
	local swing = -0.17 + 0.3 * beat
	local open = eyeOpen(rig, t)
	-- Every model's jaws keep their rhythm; only the ones it has (a crab's, pincers, a devourer's
	-- mandibles, its drones' too) use it.
	local jawL, jawR = jawOpen(rig, rig.jawL, t), jawOpen(rig, rig.jawR, t)
	local headTurn: CFrame? = nil
	local neck = rig.hinges.head
	if rig.family == "worm" and neck then
		local yaw = 0.2 * math.sin(t * 0.8 + ph) + 0.08 * math.sin(t * 2.1 + ph * 2)
		local pitch = 0.07 * math.sin(t * 1.3 + ph)
		headTurn = about(neck, CFrame.Angles(pitch, yaw, 0))
	end
	-- The beats shared by every part of a kind this frame.
	local finPhase = t * 1.8 + ph
	for _, m in rig.movers do
		local kind, offset = m.kind, m.offset
		-- Where the part sits in the model's own space this frame.
		local here: CFrame
		if kind == STATIC then
			here = offset
		elseif kind == HALO then
			-- The rune stays on the floor, turning: in the world, not with the body.
			table.insert(parts, m.part)
			table.insert(frames, ground * CFrame.new(offset.Position) * CFrame.Angles(0, t * 0.35, 0))
			continue
		elseif kind == ROTOR then
			here = about(m.hinge, CFrame.Angles(0, t * 14, 0)) * offset
		elseif kind == ORBIT then
			here = c * CFrame.Angles(0, t * 0.9, 0) * cInv * offset
		elseif kind == RAYS then
			here = c * CFrame.Angles(0, 0, t * 0.5) * cInv * offset
		elseif kind == WING then
			here = about(m.hinge, CFrame.Angles(0, -m.out * swing, m.out * 0.12 * beat)) * offset
		elseif kind == JAW then
			-- A crab's jaw turns on its hinge: the top one up, the bottom one down a little less
			-- (the model faces -Z, so a turn about X lifts the jaw's tip).
			local angle = (if m.left then jawL else jawR) * (if m.top then 1 else -0.6)
			here = about(m.hinge, CFrame.Angles(angle, 0, 0)) * offset
		elseif kind == MOUTH then
			-- A guardian's lower jaw drops on its hinge (its tip down) as far as its state opens it.
			here = about(m.hinge, CFrame.Angles(-rig.mouth, 0, 0)) * offset
		elseif kind == ARM then
			-- A guardian slime's arms swing slow and heavy from the shoulder, out of step.
			local sway = t * 1.4 + ph + (if m.out > 0 then 0 else math.pi)
			here = about(m.hinge, CFrame.Angles(0.3 * math.sin(sway), 0, m.out * 0.08 * (1 + math.cos(sway)))) * offset
		elseif kind == FLOCK then
			-- A guardian swarm's hunters circle it as one, rising and dipping.
			here = c
				* CFrame.Angles(0, t * 0.7 + ph, 0)
				* cInv
				* CFrame.new(0, 0.04 * rig.height * math.sin(t * 2.3 + ph), 0)
				* offset
		elseif kind == MAND then
			-- A devourer's jaws open outwards and snap together (the jaw's tip points ahead, so a
			-- turn about Y towards its own side opens it).
			here = about(m.hinge, CFrame.Angles(0, -m.out * (if m.left then jawL else jawR) * 0.8, 0)) * offset
		elseif kind == LEG then
			-- A crab steps in the air: each leg swings forward and back on its hip, lifting as it
			-- swings forward; every other leg in step, the two sides opposite (as crabs walk).
			local phase = t * 4 + ph + m.k * math.pi
			here = about(m.hinge, CFrame.Angles(0, 0.16 * math.sin(phase), m.out * 0.07 * (1 + math.cos(phase))))
				* offset
		elseif kind == SEG then
			-- A worm crawls through the air: a wave runs from the head down the segments, wider
			-- towards the tail; neighbours stay touching (a small step in phase and size).
			local wave = t * 2.2 + ph - m.k * 0.6
			local amp = rig.height * 0.018 * m.k
			here = CFrame.new(amp * math.sin(wave), amp * 0.4 * math.sin(wave + 1.2), 0) * offset
		elseif kind == FIN then
			-- A ray beats its fins slow and wide, as in water: the inner part from the body, the
			-- outer one following a little later, so the fin bends like a wave.
			local rootTurn = about(m.hinge, CFrame.Angles(0, 0, m.out * 0.22 * math.sin(finPhase)))
			local joint = m.joint
			here = if joint
				then rootTurn * about(joint, CFrame.Angles(0, 0, m.out * 0.28 * math.sin(finPhase - 0.9))) * offset
				else rootTurn * offset
		elseif kind == TAIL then
			-- A ray's tail of beads wags as a wave, wider towards its end (small: a wide wag would
			-- pull the chain apart).
			here = CFrame.new(rig.height * 0.005 * m.k * math.sin(t * 3 + ph - m.k * 0.4), 0, 0) * offset
		elseif kind == BUZZ then
			-- The lead drone's little wings buzz.
			here = about(m.hinge, CFrame.Angles(0, 0, m.out * 0.45 * math.sin(t * 28 + ph))) * offset
		elseif kind == FLIPPER then
			-- A whale rows with its side flippers, the two a little out of step.
			local row = t * 1.6 + ph + (if m.out > 0 then 0 else 0.5)
			here = about(m.hinge, CFrame.Angles(0.35 * math.sin(row), 0, m.out * 0.1 * math.cos(row))) * offset
		elseif kind == FLUKES then
			-- The tail flukes beat up and down, slowly.
			here = about(m.hinge, CFrame.Angles(0.3 * math.sin(t * 1.3 + ph), 0, 0)) * offset
		elseif kind == WISP then
			-- A comet circles the model; its orbit was measured at the dressing scale.
			here = c
				* CFrame.Angles(m.tilt, 0, m.tilt * 0.5)
				* CFrame.Angles(0, t * m.speed + m.phase, 0)
				* CFrame.new(m.orbit * rig.scale, 0, 0)
		else
			-- A little drone flies its own loop round the model, nose first, bobbing; its jaws and
			-- wings move on the way.
			local n = m.k
			local hover = math.sin(t * 4 + n) * MOTION.DRONE_BOB * rig.scale
			local fly = CFrame.new(0, hover, 0)
			local path = rig.paths[n]
			if path then
				local u = t / path.period + n * 0.37
				local at = loop(path.points, u)
				local ahead = loop(path.points, u + 0.01) - at
				fly = CFrame.new(at + Vector3.new(0, hover, 0))
					* CFrame.Angles(0, math.atan2(-ahead.X, -ahead.Z), 0)
					* CFrame.new(-path.home)
			end
			if m.droneKind == 1 then
				here = fly
					* about(m.hinge, CFrame.Angles(0, -m.out * (if m.left then jawL else jawR) * 0.8, 0))
					* offset
			elseif m.droneKind == 2 then
				here = fly * about(m.hinge, CFrame.Angles(0, 0, m.out * 0.45 * math.sin(t * 30 + n * 2))) * offset
			else
				here = fly * offset
			end
		end
		local size = m.size
		-- A worm's head (and all it wears) looks round on its neck; the segments wave apart.
		if headTurn and m.headTurns then
			here = headTurn * here
		end
		-- The jelly squashes everything above its floor: the dome, the face, what rides on top.
		if squash and m.aboveFloor then
			here = squashed(here, squash.floor, rig.centre, squash.sy, squash.sxz)
			if m.squashSize then
				size = squashedSize(size, offset, squash.sy, squash.sxz)
			end
		end
		if m.eye then
			size = Vector3.new(size.X, size.Y * open, size.Z)
		end
		local part = m.part
		if part.Size ~= size then
			part.Size = size
		end
		table.insert(parts, part)
		table.insert(frames, origin * here)
	end
end

-- Every part of `rig` at rest, with `origin` the model's frame: appends the parts and their frames
-- (a far model moved whole with its body).
function RigMotion.rest(rig: Rig, origin: CFrame, parts: { BasePart }, frames: { CFrame })
	for _, m in rig.movers do
		table.insert(parts, m.part)
		table.insert(frames, origin * m.offset)
	end
end

-- The rig's moving parts, for preloading their meshes.
function RigMotion.parts(rig: Rig): { BasePart }
	local list = {}
	for _, m in rig.movers do
		table.insert(list, m.part)
	end
	return list
end

return table.freeze(RigMotion)
