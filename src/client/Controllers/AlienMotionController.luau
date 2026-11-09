--!strict
-- The pets' living motion (plan docs/plans/ALIEN_MODELS.md, step 3), as the pet gallery prototype
-- had it (docs/design/prototypes/pet-look/gallery_client.luau, approved by the user). The server
-- places a dressed pet (World/AlienModel, tag BayConfig.ALIEN_TAG) and never moves it; here every
-- pet near the camera moves on the client, all of them in one BulkMoveTo a frame.
--
-- On top of a shared bob and sway each family moves its own way: a slime wobbles like jelly and
-- hops, a crab snaps its claws and steps, a worm waves its segments and looks round, a ray beats
-- its fins and wags its tail, a whale rows and beats its flukes, a swarm's little drones fly loops
-- of their own; wings flap and shed dust, comets circle, the rune and the medal turn; every pet
-- blinks and turns to a player close by, each on its own rhythm. The parts tell what they are by
-- their Role attribute (AlienDress); hinges are parts named `hinge<Name>` (`hingeJawL` turns
-- `jawL`). Lengths made at the dressing scale grow with the pet (Model:GetScale()).

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local PetMotion = require(ReplicatedStorage.Shared.Domain.PetMotion)

local MOTION = AlienLooks.MOTION
local LOOK_LIMIT = math.rad(MOTION.LOOK_LIMIT_DEGREES)
-- The part the bay's label hangs on (AlienDress): it stays put, so the label does not bob.
local LABEL_PART = "Body"
-- The dressing's effects carrier: only a dressed pet has it (the greybox blob does not move).
local EFFECTS_PART = "Fx"

export type AlienMotionController = {
	name: string,
	start: () -> (),
}

type Snap = {
	nextAt: number,
	start: number?,
	twice: boolean,
}

-- A little drone's loop round its pet: a closed curve through points in the pet's space.
type Path = {
	points: { Vector3 },
	home: Vector3,
	period: number,
}

type Pet = {
	base: CFrame,
	phase: number,
	random: Random,
	family: string,
	-- Against the dressing scale: lengths made there grow by this.
	scale: number,
	-- Half its widest span, studs.
	radius: number,
	height: number,
	-- The pet's middle in its own space.
	centre: Vector3,
	parts: { BasePart },
	offsets: { CFrame },
	sizes: { Vector3 },
	roles: { string },
	-- Which parts are glowing eyes (they blink).
	eyes: { [number]: boolean },
	-- The middle of each role's parts, in the pet's space.
	groups: { [string]: Vector3 },
	hinges: { [string]: Vector3 },
	paths: { [number]: Path },
	dustOpen: { ParticleEmitter },
	dustFold: { ParticleEmitter },
	images: { ImageLabel },
	light: PointLight?,
	brightness: number,
	-- Where a slime's jelly starts (above its solid base), in the pet's space.
	jellyFloor: number?,
	beat: number,
	yaw: number,
	blinkAt: number,
	blinkStart: number?,
	blinkTwice: boolean,
	hopAt: number,
	hopStart: number?,
	jaws: { [string]: Snap },
}

local AlienMotionController = {}

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
-- pet's centre line.
local function squashed(frame: CFrame, floor: number, centre: Vector3, sy: number, sxz: number): CFrame
	local p = frame.Position
	local moved =
		Vector3.new(centre.X + (p.X - centre.X) * sxz, floor + (p.Y - floor) * sy, centre.Z + (p.Z - centre.Z) * sxz)
	return frame - p + moved
end

-- A part's size under the squash: each of its own axes stretched by how much it points up or
-- sideways in the pet.
local function squashedSize(size: Vector3, frame: CFrame, sy: number, sxz: number): Vector3
	local function along(axis: Vector3): number
		local v = frame:VectorToWorldSpace(axis)
		return math.sqrt((v.X * sxz) ^ 2 + (v.Y * sy) ^ 2 + (v.Z * sxz) ^ 2)
	end
	return Vector3.new(size.X * along(Vector3.xAxis), size.Y * along(Vector3.yAxis), size.Z * along(Vector3.zAxis))
end

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- Turns about `pivot` (a point in the pet's space) by `turn`.
local function about(pivot: Vector3, turn: CFrame): CFrame
	return CFrame.new(pivot) * turn * CFrame.new(-pivot)
end

-- The little drones' loops: each flies a smooth closed curve through six points round the pet,
-- starting where it rests, each a little nearer or farther and higher or lower.
local function dronePaths(pet: Pet): { [number]: Path }
	local paths: { [number]: Path } = {}
	for role, home in pet.groups do
		local n = tonumber(string.match(role, "^drone(%d+)$"))
		if not n then
			continue
		end
		local away = Vector3.new(home.X - pet.centre.X, 0, home.Z - pet.centre.Z)
		local reach = away.Magnitude
		local start = math.atan2(away.Z, away.X)
		local points: { Vector3 } = {}
		for i = 0, 5 do
			local angle = start + i * math.pi / 3
			-- Never nearer than its rest spot: closer in, a drone grazes the lead.
			local radius = if i == 0 then reach else reach * pet.random:NextNumber(1.0, 1.3)
			local rise = if i == 0 then 0 else reach * pet.random:NextNumber(-0.3, 0.3)
			table.insert(
				points,
				Vector3.new(
					pet.centre.X + math.cos(angle) * radius,
					home.Y + rise,
					pet.centre.Z + math.sin(angle) * radius
				)
			)
		end
		paths[n] = { points = points, home = home, period = pet.random:NextNumber(3.5, 5.5) }
	end
	return paths
end

-- Reads a dressed pet once: its parts in its own space and what each of them does.
local function petOf(model: Model): Pet?
	if not model:FindFirstChild(EFFECTS_PART) then
		return nil
	end
	local base = model:GetPivot()
	local cf, size = model:GetBoundingBox()
	local uid = model:GetAttribute(BayConfig.ALIEN_UID_ATTRIBUTE)
	local random = Random.new(if type(uid) == "number" then uid else 1)
	local now = os.clock()
	local pet: Pet = {
		base = base,
		phase = random:NextNumber(0, 2 * math.pi),
		random = random,
		family = tostring(model:GetAttribute("Family") or ""),
		scale = model:GetScale() / AlienLooks.MODELS.DRESS_SCALE,
		radius = math.max(size.X, size.Z) / 2,
		height = size.Y,
		centre = base:PointToObjectSpace(cf.Position),
		parts = {},
		offsets = {},
		sizes = {},
		roles = {},
		eyes = {},
		groups = {},
		hinges = {},
		paths = {},
		dustOpen = {},
		dustFold = {},
		images = {},
		light = nil,
		brightness = 0,
		jellyFloor = nil,
		beat = 0,
		yaw = 0,
		blinkAt = now + random:NextNumber(0.5, 4),
		blinkStart = nil,
		blinkTwice = false,
		hopAt = now + random:NextNumber(2, 8),
		hopStart = nil,
		jaws = {
			L = { nextAt = now + random:NextNumber(0.5, 3), start = nil, twice = false },
			R = { nextAt = now + random:NextNumber(0.5, 3), start = nil, twice = false },
		},
	}
	local sums: { [string]: { position: Vector3, count: number } } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			if item.Name == LABEL_PART and item.Parent == model then
				continue
			end
			local role = tostring(item:GetAttribute("Role") or "body")
			local offset = base:ToObjectSpace(item.CFrame)
			table.insert(pet.parts, item)
			table.insert(pet.offsets, offset)
			table.insert(pet.sizes, item.Size)
			table.insert(pet.roles, role)
			local paint = tostring(item:GetAttribute("Paint") or "")
			-- The glowing eyes blink (a pet's eyes of one material are one part, at one height).
			pet.eyes[#pet.parts] = string.match(paint, ",EyeLight$") ~= nil
			-- A slime's jelly starts a little above the bottom of its glass dome: the ceramic base
			-- and the feet under it stay solid.
			if string.match(paint, ",Dome$") then
				pet.jellyFloor = offset.Position.Y - item.Size.Y * 0.3
			end
			local sum = sums[role] or { position = Vector3.zero, count = 0 }
			sum.position += offset.Position
			sum.count += 1
			sums[role] = sum
			if role == "hingeL" or role == "hingeR" then
				pet.hinges["wing" .. string.sub(role, -1)] = offset.Position
			elseif string.match(role, "^hinge%u") then
				-- Any other hinge, under the name of what turns on it: hingeJawL → jawL,
				-- hingeLegLA → legLA, hingeFinOuterR → finOuterR, hingeHead → head.
				pet.hinges[string.lower(string.sub(role, 6, 6)) .. string.sub(role, 7)] = offset.Position
			end
		elseif item:IsA("PointLight") then
			pet.light, pet.brightness = item, item.Brightness
		elseif item:IsA("ParticleEmitter") and string.match(item.Name, "^DustOpen") then
			table.insert(pet.dustOpen, item)
		elseif item:IsA("ParticleEmitter") and string.match(item.Name, "^DustFold") then
			table.insert(pet.dustFold, item)
		elseif item:IsA("ImageLabel") and (item:GetAttribute("Spin") or item:GetAttribute("Sway")) then
			table.insert(pet.images, item)
		end
	end
	for role, sum in sums do
		pet.groups[role] = sum.position / sum.count
	end
	pet.paths = dronePaths(pet)
	return pet
end

-- How far the eyes are open this frame; a new blink every few seconds, sometimes a double one.
local function eyeOpen(pet: Pet, t: number): number
	if t >= pet.blinkAt then
		pet.blinkStart = t
		pet.blinkTwice = pet.random:NextNumber() < 0.25
		pet.blinkAt = t + between(pet.random, MOTION.BLINK_EVERY)
	end
	return PetMotion.eyeOpen(t - (pet.blinkStart or -100), pet.blinkTwice)
end

-- How far a jaw is open this frame; a new snap every few seconds, sometimes a double one.
local function jawOpen(pet: Pet, jaw: Snap, t: number): number
	if t >= jaw.nextAt then
		jaw.start = t
		jaw.twice = pet.random:NextNumber() < 0.3
		jaw.nextAt = t + between(pet.random, MOTION.JAW_EVERY)
	end
	return PetMotion.jawOpen(t - (jaw.start or -100), jaw.twice, MOTION.JAW_OPEN)
end

-- A slime's jelly this frame: how much taller than at rest it is, and how high a hop lifts it
-- (a share of its height).
local function jelly(pet: Pet, t: number): (number, number)
	local stretch = MOTION.JELLY_REST * math.sin(t * 2.6 + pet.phase)
	local lift = 0
	if pet.hopStart then
		local since = t - pet.hopStart
		local hopStretch, hopLift = PetMotion.hop(since, MOTION.HOP_HEIGHT)
		stretch += hopStretch
		lift = hopLift
		if since >= PetMotion.HOP_SECONDS then
			pet.hopStart = nil
			pet.hopAt = t + between(pet.random, MOTION.HOP_EVERY)
		end
	elseif t >= pet.hopAt then
		pet.hopStart = t
	end
	return stretch, lift
end

-- Where each part of `pet` goes this frame: appends the parts and their frames.
local function move(pet: Pet, t: number, dt: number, root: BasePart?, parts: { BasePart }, frames: { CFrame })
	local ph = pet.phase
	-- Turn to a player close by, smoothly, never further than LOOK_LIMIT (the pet faces -Z).
	local wanted = 0
	if root then
		local away = pet.base:PointToObjectSpace(root.Position)
		if Vector2.new(away.X, away.Z).Magnitude < MOTION.LOOK_RADIUS + pet.radius then
			wanted = math.clamp(math.atan2(-away.X, -away.Z), -LOOK_LIMIT, LOOK_LIMIT)
		end
	end
	pet.yaw += (wanted - pet.yaw) * math.min(1, dt * 2.5)
	local stretch, lift = 0, 0
	local floor = pet.jellyFloor
	if pet.family == "slime" and floor then
		stretch, lift = jelly(pet, t)
	end
	local sy = 1 + stretch
	local sxz = 1 / math.sqrt(sy)
	local c = CFrame.new(pet.centre)
	local cInv = c:Inverse()
	local bob = pet.base
		* CFrame.new(0, math.sin(t * 2 + ph) * MOTION.BOB * pet.scale + lift * pet.height, 0)
		* c
		* CFrame.Angles(0, pet.yaw, 0)
		* cInv
		* CFrame.Angles(math.sin(t * 1.1 + ph) * 0.05, math.sin(t * 0.6 + ph) * 0.14, math.sin(t * 1.4 + ph) * 0.05)
	local beat = math.sin(t * 5 + ph)
	-- From the wings' 38° rest sweep: 11° to 45° back.
	local swing = -0.17 + 0.3 * beat
	local stroke = if pet.beat > 0 and beat <= 0
		then pet.dustOpen
		elseif pet.beat < 0 and beat >= 0 then pet.dustFold
		else nil
	if stroke then
		for _, dust in stroke do
			dust:Emit(if string.match(dust.Name, "Star$") then 2 else 10)
		end
	end
	pet.beat = beat
	local open = eyeOpen(pet, t)
	-- Every pet's jaws keep their rhythm; only the ones it has (a crab's, pincers, a devourer's
	-- mandibles, its drones' too) use it.
	local jaws: { [string]: number } = { L = jawOpen(pet, pet.jaws.L, t), R = jawOpen(pet, pet.jaws.R, t) }
	local headTurn: CFrame? = nil
	local neck = pet.hinges.head
	if pet.family == "worm" and neck then
		local yaw = 0.2 * math.sin(t * 0.8 + ph) + 0.08 * math.sin(t * 2.1 + ph * 2)
		local pitch = 0.07 * math.sin(t * 1.3 + ph)
		headTurn = about(neck, CFrame.Angles(pitch, yaw, 0))
	end
	for i, part in pet.parts do
		local role, offset = pet.roles[i], pet.offsets[i]
		-- Where the part sits in the pet's own space this frame; nil for what stays put in the
		-- world (the hidden floor ring, the turning rune circle).
		local here: CFrame? = nil
		local fixed: CFrame? = nil
		local side = string.sub(role, -1)
		-- The hinges this part may turn on (nil where the pet has none).
		local own = pet.hinges[role]
		local rotorAt = pet.groups.rotor
		local jawHinge = pet.hinges["jaw" .. side]
		local finRoot = pet.hinges["fin" .. side]
		local flukes = pet.hinges.flukes
		if role == "ring" then
			fixed = pet.base * offset
		elseif role == "halo" then
			fixed = pet.base * CFrame.new(offset.Position) * CFrame.Angles(0, t * 0.35, 0)
		elseif role == "rotor" and rotorAt then
			here = about(rotorAt, CFrame.Angles(0, t * 14, 0)) * offset
		elseif role == "orbit" then
			here = c * CFrame.Angles(0, t * 0.9, 0) * cInv * offset
		elseif role == "rays" then
			here = c * CFrame.Angles(0, 0, t * 0.5) * cInv * offset
		elseif (role == "wingL" or role == "wingR") and own then
			local out = if own.X > 0 then 1 else -1
			here = about(own, CFrame.Angles(0, -out * swing, out * 0.12 * beat)) * offset
		elseif string.match(role, "^jaw%u%a%a[LR]$") and jawHinge then
			-- A crab's jaw turns on its hinge: the top one up, the bottom one down a little less
			-- (the pet faces -Z, so a turn about X lifts the jaw's tip).
			local angle = jaws[side] * (if string.sub(role, 4, 6) == "Top" then 1 else -0.6)
			here = about(jawHinge, CFrame.Angles(angle, 0, 0)) * offset
		elseif (role == "mandL" or role == "mandR") and own then
			-- A devourer's jaws open outwards and snap together (the jaw's tip points ahead, so a
			-- turn about Y towards its own side opens it).
			local out = if own.X > 0 then 1 else -1
			here = about(own, CFrame.Angles(0, -out * jaws[side] * 0.8, 0)) * offset
		elseif string.match(role, "^leg[LR]%u$") and own then
			-- A crab steps in the air: each leg swings forward and back on its hip, lifting as it
			-- swings forward; every other leg in step, the two sides opposite (as crabs walk).
			local hinge = own
			local out = if hinge.X > 0 then 1 else -1
			local index = string.byte(role, 5) - 64 + (if string.sub(role, 4, 4) == "L" then 0 else 1)
			local phase = t * 4 + ph + index * math.pi
			here = about(hinge, CFrame.Angles(0, 0.16 * math.sin(phase), out * 0.07 * (1 + math.cos(phase)))) * offset
		elseif string.match(role, "^seg%u$") then
			-- A worm crawls through the air: a wave runs from the head down the segments, wider
			-- towards the tail; neighbours stay touching (a small step in phase and size).
			local k = string.byte(role, 4) - 64
			local wave = t * 2.2 + ph - k * 0.6
			local amp = pet.height * 0.018 * k
			here = CFrame.new(amp * math.sin(wave), amp * 0.4 * math.sin(wave + 1.2), 0) * offset
		elseif string.match(role, "^fin") and finRoot then
			-- A ray beats its fins slow and wide, as in water: the inner part from the body, the
			-- outer one following a little later, so the fin bends like a wave.
			local rootAt = finRoot
			local out = if rootAt.X > 0 then 1 else -1
			local beatPhase = t * 1.8 + ph
			local rootTurn = about(rootAt, CFrame.Angles(0, 0, out * 0.22 * math.sin(beatPhase)))
			here = rootTurn * offset
			local joint = pet.hinges["finOuter" .. side]
			if string.sub(role, 1, 8) == "finOuter" and joint then
				here = rootTurn * about(joint, CFrame.Angles(0, 0, out * 0.28 * math.sin(beatPhase - 0.9))) * offset
			end
		elseif string.match(role, "^tail%u$") then
			-- A ray's tail of beads wags as a wave, wider towards its end (small: a wide wag would
			-- pull the chain apart).
			local k = string.byte(role, 5) - 64
			here = CFrame.new(pet.height * 0.005 * k * math.sin(t * 3 + ph - k * 0.4), 0, 0) * offset
		elseif (role == "buzzL" or role == "buzzR") and own then
			-- The lead drone's little wings buzz.
			local out = if own.X > 0 then 1 else -1
			here = about(own, CFrame.Angles(0, 0, out * 0.45 * math.sin(t * 28 + ph))) * offset
		elseif (role == "flipperL" or role == "flipperR") and own then
			-- A whale rows with its side flippers, the two a little out of step.
			local out = if own.X > 0 then 1 else -1
			local row = t * 1.6 + ph + (if out > 0 then 0 else 0.5)
			here = about(own, CFrame.Angles(0.35 * math.sin(row), 0, out * 0.1 * math.cos(row))) * offset
		elseif role == "flukes" and flukes then
			-- The tail flukes beat up and down, slowly.
			here = about(flukes, CFrame.Angles(0.3 * math.sin(t * 1.3 + ph), 0, 0)) * offset
		elseif role == "wisp" then
			-- A comet circles the pet; its orbit was measured at the dressing scale.
			local tilt = tonumber(part:GetAttribute("Tilt")) or 0
			local angle = t * (tonumber(part:GetAttribute("Speed")) or 1.6)
				+ (tonumber(part:GetAttribute("Phase")) or 0)
			here = c
				* CFrame.Angles(tilt, 0, tilt * 0.5)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new((tonumber(part:GetAttribute("Orbit")) or 0) * pet.scale, 0, 0)
		elseif string.match(role, "^drone%d") then
			-- A little drone flies its own loop round the pet, nose first, bobbing; its jaws and
			-- wings (drone1MandL, drone1BuzzR…) move on the way.
			local n = tonumber(string.match(role, "%d+")) or 0
			local hover = math.sin(t * 4 + n) * MOTION.DRONE_BOB * pet.scale
			local fly = CFrame.new(0, hover, 0)
			local path = pet.paths[n]
			if path then
				local u = t / path.period + n * 0.37
				local at = loop(path.points, u)
				local ahead = loop(path.points, u + 0.01) - at
				fly = CFrame.new(at + Vector3.new(0, hover, 0))
					* CFrame.Angles(0, math.atan2(-ahead.X, -ahead.Z), 0)
					* CFrame.new(-path.home)
			end
			local centre = pet.groups["drone" .. n]
			if string.match(role, "Mand[LR]$") and own and centre then
				local out = if own.X > centre.X then 1 else -1
				here = fly * about(own, CFrame.Angles(0, -out * jaws[side] * 0.8, 0)) * offset
			elseif string.match(role, "Buzz[LR]$") and own and centre then
				local out = if own.X > centre.X then 1 else -1
				here = fly * about(own, CFrame.Angles(0, 0, out * 0.45 * math.sin(t * 30 + n * 2))) * offset
			else
				here = fly * offset
			end
		else
			here = offset
		end
		local size = pet.sizes[i]
		local frame = fixed or bob
		if here then
			local at: CFrame = here
			-- A worm's head (and all it wears) looks round on its neck; the segments wave apart.
			if headTurn and not string.match(role, "^seg%u$") and role ~= "orbit" and role ~= "wisp" then
				at = headTurn * at
			end
			-- The jelly squashes everything above its floor: the dome, the face, what rides on top.
			if stretch ~= 0 and floor and offset.Position.Y > floor then
				at = squashed(at, floor, pet.centre, sy, sxz)
				if role == "body" and part.Name ~= EFFECTS_PART then
					size = squashedSize(size, offset, sy, sxz)
				end
			end
			frame = bob * at
		end
		if pet.eyes[i] then
			size = Vector3.new(size.X, size.Y * open, size.Z)
		end
		if part.Size ~= size then
			part.Size = size
		end
		table.insert(parts, part)
		table.insert(frames, frame)
	end
	if pet.light then
		pet.light.Brightness = pet.brightness + math.sin(t * 3 + ph) * 0.4
	end
	for _, image in pet.images do
		local spin = tonumber(image:GetAttribute("Spin"))
		image.Rotation = if spin then t * spin else math.sin(t * 0.8 + (tonumber(image:GetAttribute("Sway")) or 0)) * 2
	end
end

function AlienMotionController.new(): AlienMotionController
	local pets: { [Model]: Pet } = {}

	local function forget(instance: Instance)
		if instance:IsA("Model") then
			pets[instance] = nil
		end
	end

	-- A pet arrives whole (streamed atomically, World/AlienModel): read it on the next step, once
	-- its parts are in.
	local function watch(instance: Instance)
		task.defer(function()
			if not (instance:IsA("Model") and instance:IsDescendantOf(workspace)) then
				return
			end
			local pet = petOf(instance)
			if not pet then
				return
			end
			pets[instance] = pet
			-- Many new meshes at once: ask for them all, or some stay unloaded (half a pet missing).
			local meshes: { Instance } = {}
			for _, part in pet.parts do
				if part:IsA("MeshPart") then
					table.insert(meshes, part)
				end
			end
			pcall(ContentProvider.PreloadAsync, ContentProvider, meshes)
		end)
	end

	local last = os.clock()
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
		for _, pet in pets do
			-- Far pets stand still: nobody sees them move.
			if (pet.base.Position - eye).Magnitude <= MOTION.RADIUS + pet.radius then
				move(pet, t, dt, root, parts, frames)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	local function start()
		for _, instance in CollectionService:GetTagged(BayConfig.ALIEN_TAG) do
			watch(instance)
		end
		CollectionService:GetInstanceAddedSignal(BayConfig.ALIEN_TAG):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(BayConfig.ALIEN_TAG):Connect(forget)
		RunService.RenderStepped:Connect(step)
	end

	return {
		name = "AlienMotionController",
		start = start,
	}
end

return table.freeze(AlienMotionController)
