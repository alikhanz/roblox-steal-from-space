--!strict
-- Dresses a bare pet model (assets/aliens, lune/aliens.luau) for the game, as the pet gallery
-- prototype did (docs/design/prototypes/pet-look/dress.luau, the look the user approved), in two
-- halves so that the network carries only the first:
--   * prepare (the server, World/AlienModel): paint and materials from each part's Paint code
--     (metal, glass, lava, the wings' glowing edge and faint membrane), the hidden parts, the wing
--     dust points, and the Body box the bay's label and prompts hang on. Part properties only, and
--     the lava skin: nothing heavy goes to the clients.
--   * adorn (each client, AlienMotionController, on a local copy: adornLocally): a soft light low
--     under the body, particles by zone and signature (soft: fading in and out), the jetpacks'
--     flames, the wings' glowing strokes, comets with glowing tails, a turning rune circle on the
--     floor; a meteor's heat embers, fireball comets and a crest of fire behind its head; a legendary's glow under a turning medal of rays. These were half of a
--     pet's instances and the heaviest ones (2026-11-10).
--
-- The pet comes with its data in attributes (Zone, Family, Tier 0-4, Meteor, Signature, Core,
-- TierColor) and each part's paint in its Paint attribute:
-- <kind letter><r>,<g>,<b>,<transparency>,<reflectance>,<Blender material>. Preparing is total: a
-- prepared pet prepared again comes out the same. Everything is made at
-- AlienLooks.MODELS.DRESS_SCALE (where it was tuned); the pet is scaled to its size after. Motion
-- (bobbing, wings, comets, the medal's turn) is the client's: the parts carry their Role, the
-- comets their orbit (in studs at the dressing scale), the pictures their Spin or Sway.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)

local AlienDress = {}

local MODELS = AlienLooks.MODELS
local TEX = MODELS.TEXTURES
local MOTION_LOOKS = AlienLooks.MOTION
local WING_STROKE = MOTION_LOOKS.WING_STROKE
local GOLD = Color3.fromRGB(255, 200, 70)
local FIRE = Color3.fromRGB(255, 120, 30)
local WHITE = Color3.new(1, 1, 1)
-- Blender materials that need their own treatment here (the paint code names each part's).
-- Light drawn as geometry in Blender (flame tongues, the medal's rays): hidden, particles play it.
local STAND_INS = { Flame = true, FlameCore = true, Tongue = true, Ray = true, RayShort = true }
-- Ice and glass that glow a little in Blender: clear tinted glass here, never a solid Neon spike.
local CRYSTALS = {
	Shard = true,
	IceSpike = true,
	Icicle = true,
	Fringe = true,
	Spout = true,
	Bubble = true,
	Brood = true,
}
-- Gold in Blender (the legendary's crown, gold armour, a circlet, a badge): bright gold here.
local GOLDS = { Gold = true, GoldArmour = true, Crown = true, Circlet = true, Badge = true }
-- Faint see-through glows (a hover field, a smoke wisp): barely-there Neon.
local AURAS = { Hover = true, Smoke = true }
-- Soft pastel light in Blender (the aurora's ribbons): half see-through Neon in a richer colour,
-- or Bloom burns the pale colours to white squares.
local RIBBONS = { Aurora = true }
-- Parts never seen (and hinge markers, `hinge…`: a wing's or a crab jaw's pivot): the floor
-- ring (the rune circle takes its place) and Blender's sunburst spikes (a medal of light does).
local HIDDEN_ROLES = { ring = true, rays = true }
-- The paint source of a part joined from parts of several colours, its colours baked into its mesh.
-- The export (export_robo_roblox.py, `baked`) bakes the colours this file gives each paint: keep the
-- two in step (the boosts in `paint`, GOLDS, the sources treated by name above).
local BAKED = "Baked"
-- What a dressing adds to the model: taken away before dressing again.
local ADDED_NAMES = { Fx = true, Body = true, Halo = true, Tip = true, Tail = true }
-- Particles fade in and out instead of popping: the soft look.
local SOFT = { { 0, 1 }, { 0.15, 0 }, { 0.75, 0.15 }, { 1, 1 } }

type Paint = {
	-- S solid, G glass, L lava, anything else glows (Neon).
	kind: string,
	colour: Color3,
	transparency: number,
	reflectance: number,
	-- The Blender material's name.
	source: string,
}

-- Polished metal for the pets' gold and chrome, and the meteor's lava skin: their texture maps
-- can be set only from Studio, not by a game server, so they come ready from default.project.json
-- (MaterialService.PetMetal, ServerStorage.AlienSkins.Lava). Under Realistic lighting (decision
-- 076) metal catches highlights; plastic with reflectance stays flat. Nil, with a warning once,
-- where the place lacks them: the part stays plain.
local warned: { [string]: boolean } = {}
local function ready(parent: Instance, name: string): Instance?
	local found = parent:FindFirstChild(name)
	if not found and not warned[name] then
		warned[name] = true
		warn(`[AlienDress] {parent:GetFullName()}.{name} is missing (default.project.json); pets go without it`)
	end
	return found
end

local function metalName(): string
	return if ready(MaterialService, MODELS.METAL_VARIANT) then MODELS.METAL_VARIANT else ""
end

local function lavaSkin(): SurfaceAppearance?
	local skins = ready(ServerStorage, MODELS.SKINS_FOLDER)
	local lava = if skins then ready(skins, MODELS.LAVA_SKIN) else nil
	return if lava and lava:IsA("SurfaceAppearance") then lava else nil
end

local function rgb(text: any): Color3
	local r, g, b = string.match(tostring(text), "(%d+),(%d+),(%d+)")
	return Color3.fromRGB(tonumber(r) or 255, tonumber(g) or 255, tonumber(b) or 255)
end

local function boost(colour: Color3, saturation: number, value: number): Color3
	local h, s, v = colour:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * saturation), math.min(1, v * value))
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
	end
	return NumberSequence.new(keys)
end

local function colours(points: { { any } }): ColorSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, ColorSequenceKeypoint.new(point[1], point[2]))
	end
	return ColorSequence.new(keys)
end

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission = 1
	e.LightInfluence = 0
	e.ZOffset = 0.5
	e.Transparency = seq(SOFT)
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function attachment(parent: Instance, name: string, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	return a
end

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- A camera-facing picture on an attachment (a BillboardGui): steady, where particle copies fading
-- in and out of each other flicker. Its root (the point the picture fans out of, `rootY` down from
-- its top) sits on the attachment. Layers are { colour, share of the board, transparency, "Spin"
-- or "Sway", value }: the client turns each image, Spin degrees a second or a slow sway. The
-- textures are white to the last empty pixel (assets/fx): Roblox filters them without
-- premultiplying, and black empty pixels left a dark disc where the rays meet.
local function board(at: Attachment, name: string, texture: string, size: number, rootY: number, layers: { { any } })
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(size, size)
	gui.StudsOffset = Vector3.new(0, size * (rootY - 0.5), 0)
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.MaxDistance = 300
	for _, layer in layers do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = texture
		image.ImageColor3 = layer[1]
		image.ImageTransparency = layer[3]
		image.AnchorPoint = Vector2.new(0.5, rootY)
		image.Position = UDim2.fromScale(0.5, rootY)
		image.Size = UDim2.fromScale(layer[2], layer[2])
		image:SetAttribute(layer[4], layer[5])
		image.Parent = gui
	end
	gui.Parent = at
end

-- A comet's tail: a glowing ribbon left behind the head as it circles, facing the camera, white at
-- the head and fading out in the tail's colours. It was a stream of particles (~65 a comet); one
-- ribbon draws it smoother (2026-11-10).
local function cometTail(
	wisp: BasePart,
	name: string,
	colour: ColorSequence,
	look: {
		read width: number,
		read seconds: number,
		read transparency: number,
		read brightness: number,
	}
)
	local half = wisp.Size.Y * look.width / 2
	local front = attachment(wisp, "TailTop", Vector3.new(0, half, 0))
	local back = attachment(wisp, "TailBottom", Vector3.new(0, -half, 0))
	local tail = Instance.new("Trail")
	tail.Name = name
	tail.Attachment0 = front
	tail.Attachment1 = back
	tail.FaceCamera = true
	tail.Lifetime = look.seconds
	tail.MinLength = 0
	tail.LightEmission = 1
	tail.LightInfluence = 0
	tail.Brightness = look.brightness
	tail.Color = colour
	tail.Transparency = seq({ { 0, look.transparency }, { 1, 1 } })
	tail.WidthScale = seq({ { 0, 1 }, { 1, 0.1 } })
	tail.Parent = wisp
end

-- A comet circling the pet: a glowing head and a glowing tail left behind in the world.
local function comet(
	pet: Model,
	cf: CFrame,
	radius: number,
	index: number,
	count: number,
	head: Color3,
	tail: Color3,
	fiery: boolean
)
	local wisp = Instance.new("Part")
	wisp.Name = "Wisp" .. index
	wisp.Shape = Enum.PartType.Ball
	wisp.Size = Vector3.one * (if fiery then 0.7 else 0.55)
	wisp.Material = Enum.Material.Neon
	wisp.Color = head
	ghost(wisp)
	wisp.CastShadow = false
	wisp.CFrame = cf
	wisp:SetAttribute("Role", "wisp")
	wisp:SetAttribute("Orbit", radius * (1.05 + 0.12 * index))
	wisp:SetAttribute("Tilt", (index - (count + 1) / 2) * 0.9)
	wisp:SetAttribute("Phase", index * 2 * math.pi / count)
	wisp:SetAttribute("Speed", if fiery then 1.9 else 1.6)
	if fiery then
		cometTail(
			wisp,
			"FireTail",
			colours({
				{ 0, Color3.fromRGB(255, 245, 190) },
				{ 0.3, Color3.fromRGB(255, 160, 40) },
				{ 1, Color3.fromRGB(190, 30, 10) },
			}),
			MOTION_LOOKS.FIRE_TAIL
		)
	else
		cometTail(wisp, "StarTail", colours({ { 0, WHITE }, { 0.4, tail }, { 1, tail } }), MOTION_LOOKS.COMET_TAIL)
	end
	wisp.Parent = pet
end

-- Takes away what an earlier dressing added (the bare model has none of it).
local function undress(pet: Model)
	for _, instance in pet:GetDescendants() do
		if instance.Parent == nil then
			continue
		end
		if
			ADDED_NAMES[instance.Name]
			or string.match(instance.Name, "^Wisp") ~= nil
			or instance:IsA("ParticleEmitter")
			or instance:IsA("Light")
			or instance:IsA("SurfaceAppearance")
		then
			instance:Destroy()
		end
	end
end

-- Paint: the hull a touch richer than in Blender (Roblox's light is flatter); a meteor's molten
-- parts wear the lava crack texture, its heat also shown by light and embers. Returns the parts
-- the later steps need: the wings, Blender's flame tongues and the jetpack flames.
local function paint(pet: Model, paints: { [string]: Paint }, core: Color3): ({ MeshPart }, { MeshPart }, { MeshPart })
	local wingParts, flameParts, jetParts = {}, {}, {}
	local metal = metalName()
	-- The lava skin is fetched only for a part that wears it: it lives in ServerStorage, which a
	-- client painting a guardian (AlienDress.paintModel) cannot see.
	local lava: SurfaceAppearance? = nil
	local lavaLooked = false
	for _, instance in pet:GetDescendants() do
		if not instance:IsA("MeshPart") then
			continue
		end
		local part = instance :: MeshPart
		-- The role is the name before its number (`drone2_41` → drone2, `legLA_7` → legLA): a role
		-- may hold digits of its own (a little drone's number).
		local role = string.match(part.Name, "^(.-)_%d+$") or string.match(part.Name, "^(%a+)") or part.Name
		part:SetAttribute("Role", role)
		ghost(part)
		part.TextureID = ""
		part.MaterialVariant = ""
		local p = paints[part.Name]
		if not p then
			continue
		end
		local colour = p.colour
		if p.kind == "S" and p.reflectance >= 0.3 then
			-- Metal in Blender (gold, chrome, brass, a rare kind's candy paint): polished metal here.
			-- Metal shows only what it reflects, and space is dark, so gold is a bright, saturated
			-- gold, or it turns olive; other metals keep their own colour, a touch richer.
			part.Material = Enum.Material.SmoothPlastic
			part.MaterialVariant = metal
			part.Color = if GOLDS[p.source] then Color3.fromRGB(255, 190, 45) else boost(colour, 1.15, 1.05)
			part.Reflectance = 0
			part.Transparency = 0
		elseif p.kind == "S" then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = boost(colour, 1.25, 1.12)
			part.Reflectance = math.min(p.reflectance, 0.15)
			part.Transparency = 0
		elseif p.kind == "G" then
			part.Material = Enum.Material.Glass
			part.Color = colour
			part.Reflectance = 0
			part.Transparency = if p.transparency >= 0.7 then 0.45 else 0.2
		elseif p.kind == "L" then
			-- Cooled crust with glowing lava in the cracks: the crack texture on the export's
			-- box-projected UVs, the cracks lit by the glow mask.
			part.Material = Enum.Material.SmoothPlastic
			part.Color = WHITE
			part.Reflectance = 0
			part.Transparency = 0
			if not lavaLooked then
				lava, lavaLooked = lavaSkin(), true
			end
			if lava then
				lava:Clone().Parent = part
			end
		else
			part.Material = Enum.Material.Neon
			part.Color = colour
			part.Reflectance = 0
			part.Transparency = 0
		end
		-- Parts of several colours joined into one: their colours, as painted above, are in the
		-- mesh's vertices, and the part's colour multiplies them (export_robo_roblox.py, "Baked").
		if p.source == BAKED then
			part.Color = WHITE
		end
		-- What the part is in Blender, where a flat Roblox material would get it wrong.
		local source = p.source
		if STAND_INS[source] then
			part.Transparency = 1 -- light drawn as geometry in Blender; particles play it here
		elseif CRYSTALS[source] then
			part.Material = Enum.Material.Glass
			part.Color = boost(colour, 1.15, 1)
			part.Transparency = 0.3
		elseif AURAS[source] then
			part.Material = Enum.Material.Neon
			part.Transparency = 0.8
		elseif RIBBONS[source] then
			part.Material = Enum.Material.Neon
			part.Color = boost(colour, 1.8, 1)
			part.Transparency = 0.45
		elseif source == "Jet" then
			-- A jetpack's flame: a solid cone reads as a spike; a jet of particles fires from its base.
			part.Transparency = 1
			table.insert(jetParts, part)
		elseif source == "Galaxy" then
			-- A lilac nebula in Blender: lilac here (glass turned it magenta), its stars are particles.
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(150, 115, 230)
			part.Transparency = 0
		end
		part.CastShadow = part.Material ~= Enum.Material.Neon
		if role == "core" then
			part.Material = Enum.Material.Neon
			part.Color = boost(core, 1.2, 1.2)
		elseif role == "wingL" or role == "wingR" then
			table.insert(wingParts, part)
		elseif role == "flame" then
			table.insert(flameParts, part)
			part.Transparency = 1
		elseif string.match(role, "^hinge") or HIDDEN_ROLES[role] then
			part.Transparency = 1
		end
	end
	return wingParts, flameParts, jetParts
end

-- The jetpack's flames (tier 2+): from each nozzle (the top of Blender's hidden flame cone), a
-- short jet down and a little back, in the colour Blender gave it with a pale core. The cone's
-- length sets the jet's.
-- One beam of a jet's flame: its name (MOTION.MAIN_EFFECTS keeps it in the middle distance), its
-- size and scroll (AlienLooks.MOTION), its colours and how much it glows.
type JetLayer = {
	name: string,
	look: { read length: number, read width: number, read transparency: number, read scroll: number },
	colour: ColorSequence,
	emission: number,
}

local function jets(fx: BasePart, jetParts: { MeshPart }, paints: { [string]: Paint })
	for index, part in jetParts do
		-- The cone stands almost upright, its base half its length above its middle.
		local length = math.max(part.Size.X, part.Size.Y, part.Size.Z)
		local nozzle = attachment(
			fx,
			"Jet" .. index,
			fx.CFrame:PointToObjectSpace(part.Position + Vector3.new(0, length * 0.45, 0))
		)
		nozzle.CFrame *= CFrame.Angles(-0.29, 0, 0) -- Bottom leans to +Z, the pet's back
		local colour = paints[part.Name].colour
		-- Two beams down from the nozzle, facing the camera, the fire scrolling along them: the
		-- flame in its colour and a white core over it.
		local flameColour = colours({ { 0, WHITE }, { 0.25, boost(colour, 1, 1.2) }, { 1, colour } })
		local layers: { JetLayer } = {
			{ name = "JetFlame", look = MOTION_LOOKS.JET_FLAME, colour = flameColour, emission = 0.7 },
			{ name = "JetCore", look = MOTION_LOOKS.JET_CORE, colour = ColorSequence.new(WHITE), emission = 1 },
		}
		for _, layer in layers do
			local look = layer.look
			local tail = attachment(fx, layer.name .. "End" .. index, Vector3.zero)
			tail.CFrame = nozzle.CFrame * CFrame.new(0, -length * look.length, 0)
			local beam = Instance.new("Beam")
			beam.Name = layer.name
			beam.Attachment0 = nozzle
			beam.Attachment1 = tail
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Texture = TEX.jet
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.TextureSpeed = look.scroll
			beam.LightEmission = layer.emission
			beam.LightInfluence = 0
			beam.Color = layer.colour
			beam.Transparency = seq({ { 0, look.transparency }, { 0.6, 0.4 }, { 1, 1 } })
			beam.Width0 = length * look.width
			beam.Width1 = length * look.width * 0.25
			beam.Parent = fx
		end
	end
end

-- Every pet: a soft glow round it in its core colour, twinkling stars and motes in the tier colour,
-- and its zone's own effect.
local function aura(
	fx: BasePart,
	top: Attachment,
	radius: number,
	tier: number,
	meteor: boolean,
	zone: string,
	core: Color3,
	tierColor: Color3
)
	local k = 1 + tier * 0.6
	emitter(fx, "SoftGlow", {
		Texture = TEX.ember,
		Color = ColorSequence.new(if meteor then FIRE else boost(core, 1.1, 1.1)),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } }),
		Size = seq({ { 0, radius * 0.6 }, { 1, radius * 1.1 } }),
		Lifetime = NumberRange.new(1.6, 2.4),
		Rate = 3 + tier,
		Speed = NumberRange.new(0, 0.2),
		ZOffset = -1,
	})
	emitter(fx, "Twinkle", {
		Texture = TEX.star,
		Color = colours({ { 0, WHITE }, { 0.5, tierColor }, { 1, tierColor } }),
		Size = seq({ { 0, 0 }, { 0.3, 0.5 + tier * 0.1, 0.15 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 8 * k,
		Speed = NumberRange.new(0.2, 0.7),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-80, 80),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	emitter(fx, "Motes", {
		Texture = TEX.ember,
		Color = ColorSequence.new(boost(tierColor, 1.1, 1)),
		Size = seq({ { 0, 0 }, { 0.2, 0.22, 0.08 }, { 1, 0 } }),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 10 * k,
		Speed = NumberRange.new(0.3, 0.8),
		Acceleration = Vector3.new(0, 0.8, 0),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	if zone == "debris" then
		emitter(top, "Sparks", {
			Texture = TEX.spark,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Transparency = seq({ { 0, 0 }, { 1, 1 } }),
			Color = colours({
				{ 0, Color3.fromRGB(255, 250, 200) },
				{ 0.5, Color3.fromRGB(255, 180, 60) },
				{ 1, Color3.fromRGB(255, 100, 30) },
			}),
			Size = seq({ { 0, 0.22 }, { 1, 0.06 } }),
			Squash = seq({ { 0, -1.5 }, { 1, -1.5 } }),
			Lifetime = NumberRange.new(0.4, 0.7),
			Rate = 10 * k,
			Speed = NumberRange.new(7, 13),
			SpreadAngle = Vector2.new(65, 65),
			Acceleration = Vector3.new(0, -32, 0),
		})
	elseif zone == "ice" then
		emitter(fx, "Frost", {
			Texture = TEX.star,
			Color = colours({ { 0, Color3.fromRGB(220, 250, 255) }, { 1, Color3.fromRGB(120, 200, 255) } }),
			Size = seq({ { 0, 0 }, { 0.2, 0.35 }, { 1, 0 } }),
			Lifetime = NumberRange.new(1.4, 2.2),
			Rate = 14 * k,
			Speed = NumberRange.new(0.2, 0.5),
			Acceleration = Vector3.new(0, -1.2, 0),
			RotSpeed = NumberRange.new(-90, 90),
			Shape = Enum.ParticleEmitterShape.Sphere,
		})
		emitter(top, "Splash", {
			Texture = TEX.drop,
			LightEmission = 0.5,
			Color = colours({ { 0, Color3.fromRGB(230, 252, 255) }, { 1, Color3.fromRGB(120, 210, 255) } }),
			Size = seq({ { 0, 0.25 }, { 1, 0.1 } }),
			Lifetime = NumberRange.new(0.6, 0.9),
			Rate = 8 * k,
			Speed = NumberRange.new(5, 8),
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -22, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
		})
	elseif zone == "nebula" then
		emitter(fx, "Embers", {
			Texture = TEX.ember,
			Color = colours({
				{ 0, Color3.fromRGB(255, 235, 150) },
				{ 0.5, Color3.fromRGB(255, 110, 40) },
				{ 1, Color3.fromRGB(220, 40, 90) },
			}),
			Size = seq({ { 0, 0.35 }, { 1, 0 } }),
			Lifetime = NumberRange.new(1.2, 2),
			Rate = 20 * k,
			Speed = NumberRange.new(0.5, 1.5),
			Acceleration = Vector3.new(0, 3, 0),
			Drag = 1,
			Shape = Enum.ParticleEmitterShape.Sphere,
		})
	elseif zone == "horizon" then
		emitter(fx, "Stardust", {
			Texture = TEX.ember,
			Color = colours({
				{ 0, WHITE },
				{ 0.5, Color3.fromRGB(200, 160, 255) },
				{ 1, Color3.fromRGB(120, 180, 255) },
			}),
			Size = seq({ { 0, 0 }, { 0.2, 0.2 }, { 1, 0 } }),
			Lifetime = NumberRange.new(2, 3),
			Rate = 24 * k,
			Speed = NumberRange.new(0.3, 0.8),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		emitter(fx, "BigStars", {
			Texture = TEX.star,
			Color = colours({ { 0, Color3.fromRGB(230, 200, 255) }, { 1, WHITE } }),
			Size = seq({ { 0, 0 }, { 0.5, 1 }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 2 * k,
			Speed = NumberRange.new(0, 0),
			RotSpeed = NumberRange.new(-30, 30),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
	end
end

-- The candle flames burn where Blender drew their (now hidden) tongues, as tall as they were:
-- from just above the dome (Roblox draws no particles behind Glass, so inside the dome they would
-- vanish), a body of fire and a pale core, not too additive (on a bright background additive fire
-- disappears).
local function candleFlames(fx: BasePart, top: Attachment, flameParts: { MeshPart })
	local base, low, height = Vector3.zero, math.huge, 0
	for _, part in flameParts do
		base += part.Position
		low = math.min(low, part.Position.Y - part.Size.Y / 2)
		height = math.max(height, part.Size.Y)
	end
	local flameAt = top
	if #flameParts > 0 then
		base /= #flameParts
		flameAt = Instance.new("Attachment")
		flameAt.Name = "FlameBase"
		flameAt.Parent = fx
		flameAt.WorldPosition = Vector3.new(base.X, low + height * 0.45, base.Z)
	end
	local lift = math.max(height, 2)
	local burn = seq({ { 0, 0.6 }, { 0.15, 0.05 }, { 0.6, 0.2 }, { 1, 1 } })
	emitter(flameAt, "Flames", {
		Texture = TEX.flame,
		LightEmission = 0.4,
		Transparency = burn,
		Color = colours({
			{ 0, Color3.fromRGB(255, 230, 120) },
			{ 0.35, Color3.fromRGB(255, 140, 30) },
			{ 1, Color3.fromRGB(200, 40, 15) },
		}),
		Size = seq({ { 0, lift * 0.66 }, { 0.4, lift * 0.77 }, { 1, lift * 0.14 } }),
		Lifetime = NumberRange.new(0.45, 0.75),
		Rate = 25,
		Speed = NumberRange.new(lift * 1.1, lift * 1.6),
		SpreadAngle = Vector2.new(12, 12),
		Rotation = NumberRange.new(-20, 20),
		RotSpeed = NumberRange.new(-40, 40),
	})
	emitter(flameAt, "FlameCore", {
		Texture = TEX.flame,
		LightEmission = 0.8,
		Transparency = burn,
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 190)),
		Size = seq({ { 0, lift * 0.4 }, { 0.5, lift * 0.35 }, { 1, lift * 0.07 } }),
		Lifetime = NumberRange.new(0.3, 0.45),
		Rate = 15,
		Speed = NumberRange.new(lift * 0.9, lift * 1.25),
		SpreadAngle = Vector2.new(12, 12),
		Rotation = NumberRange.new(-20, 20),
		RotSpeed = NumberRange.new(-40, 40),
	})
end

-- The kind's signature effects ("flames+bubbles").
local function signatures(
	fx: BasePart,
	top: Attachment,
	back: Attachment,
	signature: string,
	core: Color3,
	flameParts: { MeshPart }
)
	for sig in string.gmatch(signature, "[^%+]+") do
		if sig == "flames" then
			candleFlames(fx, top, flameParts)
		elseif sig == "lightning" then
			-- Crackling: many quick bolts round the body, big ones now and then, sparks flying.
			emitter(fx, "Bolts", {
				Texture = TEX.bolt,
				Transparency = NumberSequence.new(0),
				Color = colours({ { 0, Color3.fromRGB(255, 255, 220) }, { 1, Color3.fromRGB(130, 220, 255) } }),
				Size = seq({ { 0, 1.9, 0.6 }, { 1, 1.9, 0.6 } }),
				Lifetime = NumberRange.new(0.05, 0.12),
				Rate = 30,
				Speed = NumberRange.new(0, 0),
				Rotation = NumberRange.new(0, 360),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			})
			emitter(fx, "BigBolts", {
				Texture = TEX.bolt,
				Transparency = NumberSequence.new(0),
				Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
				Size = NumberSequence.new(3.4),
				Lifetime = NumberRange.new(0.06, 0.1),
				Rate = 6,
				Speed = NumberRange.new(0, 0),
				Rotation = NumberRange.new(0, 360),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			})
			emitter(fx, "ElectricSparks", {
				Texture = TEX.spark,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Transparency = seq({ { 0, 0 }, { 1, 1 } }),
				Color = colours({ { 0, WHITE }, { 1, Color3.fromRGB(120, 210, 255) } }),
				Size = seq({ { 0, 0.18 }, { 1, 0.04 } }),
				Lifetime = NumberRange.new(0.15, 0.3),
				Rate = 40,
				Speed = NumberRange.new(9, 15),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			})
		elseif sig == "spout" then
			emitter(top, "Spout", {
				Texture = TEX.drop,
				LightEmission = 0.5,
				Color = colours({ { 0, WHITE }, { 1, Color3.fromRGB(140, 210, 255) } }),
				Size = seq({ { 0, 0.32 }, { 1, 0.15 } }),
				Lifetime = NumberRange.new(0.6, 0.9),
				Rate = 40,
				Speed = NumberRange.new(9, 12),
				SpreadAngle = Vector2.new(12, 12),
				Acceleration = Vector3.new(0, -28, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel,
			})
			emitter(top, "Bubbles", {
				Texture = TEX.bubble,
				LightEmission = 0.4,
				Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
				Size = seq({ { 0, 0.2 }, { 1, 0.5 } }),
				Lifetime = NumberRange.new(1.2, 2),
				Rate = 10,
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(40, 40),
			})
		elseif sig == "bubbles" then
			emitter(top, "Bubbles", {
				Texture = TEX.bubble,
				LightEmission = 0.5,
				Color = ColorSequence.new(boost(core, 1, 1.2)),
				Size = seq({ { 0, 0.2 }, { 1, 0.55 } }),
				Lifetime = NumberRange.new(1.5, 2.5),
				Rate = 14,
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(25, 25),
			})
		elseif sig == "exhausts" then
			emitter(top, "Smoke", {
				Texture = TEX.smoke,
				LightEmission = 0,
				LightInfluence = 1,
				Color = ColorSequence.new(Color3.fromRGB(120, 110, 105)),
				Size = seq({ { 0, 0.4 }, { 1, 1.8 } }),
				Transparency = seq({ { 0, 0.5 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1, 1.6),
				Rate = 8,
				Speed = NumberRange.new(2, 3),
				SpreadAngle = Vector2.new(10, 10),
			})
		elseif sig == "smoke" then
			-- Blender's violet wisps of shadow rising behind (dropped from the export).
			emitter(back, "Wisps", {
				Texture = TEX.smoke,
				LightEmission = 0.3,
				Color = ColorSequence.new(Color3.fromRGB(130, 80, 200)),
				Size = seq({ { 0, 0.6 }, { 1, 2.2 } }),
				Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1.6, 2.4),
				Rate = 6,
				Speed = NumberRange.new(1, 1.6),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(15, 15),
			})
		elseif sig == "flakes" then
			-- Blender's glowing snowflakes over the pet (dropped from the export).
			emitter(top, "Flakes", {
				Texture = TEX.star,
				Color = ColorSequence.new(Color3.fromRGB(190, 240, 255)),
				Size = seq({ { 0, 0 }, { 0.2, 0.4 }, { 1, 0 } }),
				Lifetime = NumberRange.new(2, 3),
				Rate = 8,
				Speed = NumberRange.new(0.3, 0.8),
				SpreadAngle = Vector2.new(70, 70),
				Acceleration = Vector3.new(0, -0.8, 0),
				RotSpeed = NumberRange.new(-60, 60),
			})
		elseif sig == "galaxy" then
			emitter(fx, "Galaxy", {
				Texture = TEX.star,
				Color = colours({ { 0, Color3.fromRGB(255, 220, 140) }, { 1, Color3.fromRGB(200, 150, 255) } }),
				Size = seq({ { 0, 0 }, { 0.3, 0.4 }, { 1, 0 } }),
				Lifetime = NumberRange.new(1, 1.6),
				Rate = 30,
				Speed = NumberRange.new(0.2, 0.6),
				Shape = Enum.ParticleEmitterShape.Sphere,
			})
		end
	end
end

-- A meteor burns on top of its tier: heat embers round the body, fireball comets circling it and a
-- crest of fire behind its head (in the Blender renders, its comet tail seen from the front:
-- tongues fanning up and out), growing with the tier. No comet tail streaming out behind it (fire,
-- smoke and sparks shot out sideways all the time: "looks off", user, 2026-11-10).
local function meteorFire(pet: Model, fx: BasePart, cf: CFrame, size: Vector3, radius: number, tier: number)
	emitter(fx, "HeatEmbers", {
		Texture = TEX.ember,
		Color = colours({ { 0, Color3.fromRGB(255, 220, 120) }, { 1, Color3.fromRGB(255, 70, 20) } }),
		Size = seq({ { 0, 0.3 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 35,
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 4, 0),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local count = 2 + math.floor(tier / 2)
	for index = 1, count do
		comet(pet, cf, radius, index, count, Color3.fromRGB(255, 190, 90), FIRE, true)
	end
	local root = attachment(fx, "Crest", Vector3.new(0, size.Y * 0.15, size.Z * 0.3))
	board(root, "Crest", TEX.crest, radius * (1.6 + tier * 0.25), 0.78, {
		{ FIRE, 1, 0.15, "Sway", 1 },
		{ Color3.fromRGB(255, 210, 120), 0.75, 0.35, "Sway", 2 },
	})
end

-- A legendary glows: a big soft radiance behind the body (gold; fire for a meteor) that breathes
-- slowly, a brighter heart in it and slow sparkles drifting out of it, under a medal of rays (the
-- Blender renders' sunburst) turning slowly; it showers gold glitter. The glow moves with the pet
-- (locked to the carrier) and is drawn at its own depth, just behind the body: pushed further back
-- it shows round the body more, burns brighter and washes out the medal.
local function legendaryGlow(fx: BasePart, top: Attachment, size: Vector3, radius: number, meteor: boolean)
	local warm = if meteor then FIRE else GOLD
	local pale = if meteor then Color3.fromRGB(255, 200, 120) else Color3.fromRGB(255, 240, 180)
	local glow = attachment(fx, "Radiance", Vector3.new(0, size.Y * 0.1, size.Z * 0.25))
	emitter(glow, "Radiance", {
		Texture = TEX.ember,
		Color = colours({ { 0, pale }, { 1, warm } }),
		Transparency = seq({ { 0, 1 }, { 0.35, 0.82 }, { 0.7, 0.85 }, { 1, 1 } }),
		Size = seq({ { 0, radius * 2.4 }, { 1, radius * 3.2 } }),
		Lifetime = NumberRange.new(2.5, 3.5),
		Rate = 1, -- sparse: overlapping copies add up and wash out the medal
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-10, 10),
		LockedToPart = true,
		ZOffset = 0,
	})
	emitter(glow, "RadianceHeart", {
		Texture = TEX.ember,
		Color = ColorSequence.new(pale),
		Transparency = seq({ { 0, 1 }, { 0.4, 0.78 }, { 1, 1 } }),
		Size = seq({ { 0, radius * 1.3 }, { 1, radius * 1.7 } }),
		Lifetime = NumberRange.new(1.8, 2.4),
		Rate = 1,
		Speed = NumberRange.new(0, 0),
		LockedToPart = true,
		ZOffset = 0,
	})
	emitter(glow, "RadianceMotes", {
		Texture = TEX.star,
		Color = colours({ { 0, WHITE }, { 0.4, pale }, { 1, warm } }),
		Size = seq({ { 0, 0 }, { 0.3, 0.35, 0.15 }, { 1, 0 } }),
		Lifetime = NumberRange.new(2, 3),
		Rate = 14,
		Speed = NumberRange.new(0.6, 1.4),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		ZOffset = -1,
	})
	board(glow, "Medal", TEX.rays, radius * 2.8, 0.5, {
		{ warm, 1, 0.3, "Spin", 4 },
		{ pale, 0.7, 0.5, "Spin", -7 },
	})
	emitter(top, "GoldGlitter", {
		Texture = TEX.star,
		Color = colours({ { 0, Color3.fromRGB(255, 250, 210) }, { 1, GOLD } }),
		Size = seq({ { 0, 0 }, { 0.2, 0.45, 0.1 }, { 1, 0 } }),
		Lifetime = NumberRange.new(1.2, 1.8),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -4, 0),
		RotSpeed = NumberRange.new(-120, 120),
	})
end

-- Fairy wings (modelled in Blender, a role a side): the membrane is a faint tint; its glowing edge,
-- veins and pattern carry the shape. The dust markers from Blender along each wing's outer edge
-- become Dust points on the membrane (so they flap with it); the client strings a glowing stroke
-- through them (wings).
-- The membrane of a wing (`side`): the part of the wing material (EnergyWing, GoldWing); the edge
-- and veins are the glowing lines.
local function membraneOf(side: string, wingParts: { MeshPart }, paints: { [string]: Paint }): MeshPart?
	local membrane: MeshPart? = nil
	for _, part in wingParts do
		local source = if paints[part.Name] then paints[part.Name].source else ""
		if part:GetAttribute("Role") == side and string.match(source, "Wing$") then
			membrane = part
		end
	end
	return membrane
end

-- The wings' colour (the server): the edge and veins glow in the accent, the membrane is a faint
-- tint. Blender's dust markers become Dust points on the membrane (so they flap with it).
local function colorWings(pet: Model, wingParts: { MeshPart }, paints: { [string]: Paint }, accent: Color3)
	for _, side in { "wingL", "wingR" } do
		local membrane = membraneOf(side, wingParts, paints)
		if not membrane then
			continue
		end
		for _, part in wingParts do
			if part:GetAttribute("Role") == side then
				part.Material = Enum.Material.Neon
				part.Color = boost(accent, 1.2, 1.1)
				part.Transparency = 0
			end
		end
		membrane.Material = Enum.Material.SmoothPlastic
		membrane.Color = boost(accent, 1.2, 1.1)
		membrane.Transparency = 0.8
		membrane.CastShadow = false
	end
	for _, marker in pet:GetDescendants() do
		if marker:IsA("MeshPart") and string.match(marker.Name, "^dust[LR]") then
			local host = membraneOf("wing" .. string.sub(marker.Name, 5, 5), wingParts, paints)
			if host then
				local point = Instance.new("Attachment")
				point.Name = "Dust"
				-- Where it lies along the wing's edge (1 at the tip): the wing's stroke runs through
				-- the points in this order.
				point:SetAttribute("Order", tonumber(string.match(marker.Name, "^dust[LR](%d+)")) or 0)
				point.Parent = host
				point.WorldPosition = marker.Position
			end
			marker:Destroy()
		end
	end
end

local function wings(wingParts: { MeshPart }, paints: { [string]: Paint }, accent: Color3)
	-- The wing's outer edge leaves a glowing stroke behind it as the wing beats: a ribbon between
	-- every two neighbouring Dust points (they lie along the edge, from the tip down), so the whole
	-- edge sweeps a soft afterimage, fading in a moment. It was a spray of sparkles at the tip
	-- (2026-11-10): one ribbon a stretch of edge draws the beat softer for a fraction of the cost.
	for _, side in { "wingL", "wingR" } do
		local membrane = membraneOf(side, wingParts, paints)
		if not membrane then
			continue
		end
		local points: { Attachment } = {}
		for _, child in membrane:GetChildren() do
			if child:IsA("Attachment") and child.Name == "Dust" then
				table.insert(points, child)
			end
		end
		local function order(point: Attachment): number
			return tonumber(point:GetAttribute("Order")) or 0
		end
		table.sort(points, function(a: Attachment, b: Attachment): boolean
			return order(a) < order(b)
		end)
		for index = 1, #points - 1 do
			local stroke = Instance.new("Trail")
			stroke.Name = "WingStroke"
			stroke.Attachment0 = points[index]
			stroke.Attachment1 = points[index + 1]
			stroke.Lifetime = WING_STROKE.seconds
			stroke.MinLength = 0
			stroke.LightEmission = 1
			stroke.LightInfluence = 0
			stroke.Brightness = WING_STROKE.brightness
			stroke.Color = colours({ { 0, WHITE }, { 0.3, accent }, { 1, accent } })
			stroke.Transparency = seq({ { 0, WING_STROKE.transparency }, { 1, 1 } })
			stroke.Parent = membrane
		end
	end
end

-- The height of the pet's feet: the lowest corner of its visible parts. Its bounding box reaches
-- lower, round hidden stand-ins and a legendary's spikes, and the rune laid there sank under the
-- place's pad.
local function feetOf(pet: Model): number
	local low = math.huge
	for _, part in pet:GetDescendants() do
		if not part:IsA("MeshPart") or part.Transparency >= 1 then
			continue
		end
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					low = math.min(low, (part.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
				end
			end
		end
	end
	return low
end

-- A rune circle on the floor instead of the plain tier ring: it glows in the tier colour and turns
-- slowly (the client). Its picture is crisp at 1024 px with a faint glow under it: the blurred
-- 256 px one smeared under a big pet, and the motes off its rim went unseen (user, 2026-11-10).
-- Laid at the pet's feet; adornLocally lifts it to RUNE_LIFT over them at the pet's own size.
local function rune(pet: Model, cf: CFrame, size: Vector3, accent: Color3)
	local feet = feetOf(pet)
	local floorY = if feet < math.huge then feet else cf.Position.Y - size.Y / 2
	local halo = Instance.new("Part")
	halo.Name = "Halo"
	ghost(halo)
	halo.CastShadow = false
	halo.Transparency = 1
	local haloSize = math.max(size.X, size.Z) * 0.95
	halo.Size = Vector3.new(haloSize, 0.05, haloSize)
	halo.CFrame = CFrame.new(cf.Position.X, floorY + 0.08, cf.Position.Z)
	halo:SetAttribute("Role", "halo")
	for _, layer in { { TEX.rune, 0, "Rune", 1024 }, { TEX.ember, 0.72, "Glow", 256 } } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = layer[3] :: string
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(layer[4] :: number, layer[4] :: number)
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = layer[1] :: string
		image.ImageColor3 = accent
		image.ImageTransparency = layer[2] :: number
		image.Parent = gui
		gui.Parent = halo
	end
	halo.Parent = pet
end

-- The parts the effects need, as prepare left them: the wings, Blender's flame tongues and the
-- jetpack flames.
local function partsOf(pet: Model, paints: { [string]: Paint }): ({ MeshPart }, { MeshPart }, { MeshPart })
	local wingParts, flameParts, jetParts = {}, {}, {}
	for _, instance in pet:GetDescendants() do
		if not instance:IsA("MeshPart") then
			continue
		end
		local role = instance:GetAttribute("Role")
		if role == "wingL" or role == "wingR" then
			table.insert(wingParts, instance)
		elseif role == "flame" then
			table.insert(flameParts, instance)
		end
		local code = paints[instance.Name]
		if code and code.source == "Jet" then
			table.insert(jetParts, instance)
		end
	end
	return wingParts, flameParts, jetParts
end

-- Each part's paint, from its Paint code.
local function paintsOf(pet: Model): { [string]: Paint }
	local paints: { [string]: Paint } = {}
	for _, part in pet:GetDescendants() do
		local code = if part:IsA("MeshPart") then part:GetAttribute("Paint") else nil
		if type(code) ~= "string" then
			continue
		end
		local kind, r, g, b, t, reflectance, source =
			string.match(code, "^(%a)(%d+),(%d+),(%d+),([%d%.]+),([%d%.]+),?(%a*)$")
		if kind then
			paints[part.Name] = {
				kind = kind,
				colour = Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0),
				transparency = tonumber(t) or 0,
				reflectance = tonumber(reflectance) or 0,
				source = source or "",
			}
		end
	end
	return paints
end

-- What a pet's look hangs on: its tier, whether it is a meteor one, its colours.
local function looksOf(pet: Model): (number, boolean, Color3, Color3, Color3)
	local tier = tonumber(pet:GetAttribute("Tier")) or 0
	local meteor = pet:GetAttribute("Meteor") == true
	local core, tierColor = rgb(pet:GetAttribute("Core")), rgb(pet:GetAttribute("TierColor"))
	local accent = if meteor then FIRE elseif tier == 4 then GOLD else tierColor
	return tier, meteor, core, tierColor, accent
end

-- The server's half (a bare or already prepared model, scaled to the dressing scale): paint,
-- materials, wings, dust points, the Body box.
function AlienDress.prepare(pet: Model)
	undress(pet)
	pet:ScaleTo(MODELS.DRESS_SCALE)
	local _, _, core, _, accent = looksOf(pet)
	local paints = paintsOf(pet)
	local wingParts = paint(pet, paints, core)
	colorWings(pet, wingParts, paints, accent)

	-- What the bay's label and prompts hang on (BayViewController, "Body"): the pet's whole box.
	local cf, size = pet:GetBoundingBox()
	local body = Instance.new("Part")
	body.Name = "Body"
	ghost(body)
	body.Transparency = 1
	body.CastShadow = false
	body.Size = size
	body.CFrame = cf
	body.Parent = pet
	pet.PrimaryPart = body
end

-- Paints another bare model of the robots' pipeline the way a pet's parts are painted (a
-- guardian's, assets/guardians: World/GuardianVisual): materials, metal, glass, baked colours,
-- Blender's stand-ins and markers hidden, each part's Role. `core`: the colour its core glows.
function AlienDress.paintModel(model: Model, core: Color3)
	paint(model, paintsOf(model), core)
end

-- The fine dust as twinkling clusters (AlienLooks.FX): each particle of these layers carries a
-- flipbook of a few specks or stars twinkling, so the layer emits several times less often with
-- bigger particles, and the grains look as they did. They are born on a shell the pet's own size
-- (`cf`, `size`: its box), not on the effects carrier inside it: on a big round pet that one lies
-- within the body, and a whole cluster appeared and faded hidden in it (user, 2026-11-10).
local function clusters(pet: Model, cf: CFrame, size: Vector3)
	local FX = AlienLooks.FX
	local shell: BasePart? = nil
	for _, item in pet:GetDescendants() do
		local sheet = if item:IsA("ParticleEmitter") then FX.CLUSTERS[item.Name] else nil
		if not sheet then
			continue
		end
		if not shell then
			local part = Instance.new("Part")
			part.Name = "DustShell"
			part:SetAttribute("Role", "body")
			ghost(part)
			part.Transparency = 1
			part.CastShadow = false
			part.Size = size * FX.CLUSTER_SHELL
			part.CFrame = cf
			part.Parent = pet
			shell = part
		end
		local particles = item :: ParticleEmitter
		particles.Parent = shell
		particles.Shape = Enum.ParticleEmitterShape.Sphere
		particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		particles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		particles.Texture = (TEX :: any)[sheet]
		particles.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		particles.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		particles.FlipbookFramerate = NumberRange.new(FX.CLUSTER_FRAMERATE[1], FX.CLUSTER_FRAMERATE[2])
		particles.FlipbookStartRandom = true
		particles.Rotation = NumberRange.new(0, 360)
		particles.Rate *= FX.CLUSTER_RATE
		local keys = {}
		for _, key in particles.Size.Keypoints do
			local scale = FX.CLUSTER_SIZE
			table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale))
		end
		particles.Size = NumberSequence.new(keys)
	end
end

-- The effects carrier: an invisible box over the body (`cf`, `size`: its box), moving with it,
-- with the points on top and at the back the effects start from.
local function carrier(pet: Model, cf: CFrame, size: Vector3): (BasePart, Attachment, Attachment)
	local fx = Instance.new("Part")
	fx.Name = "Fx"
	fx:SetAttribute("Role", "body")
	ghost(fx)
	fx.Transparency = 1
	fx.Size = size * 0.7
	fx.CFrame = cf
	fx.Parent = pet
	local top = attachment(fx, "Top", Vector3.new(0, size.Y * 0.5, 0))
	-- The back of the pet: it faces -Z, so its back is +Z (signatures that trail behind start here).
	local back = attachment(fx, "Back", Vector3.new(0, size.Y * 0.05, size.Z * 0.45))
	return fx, top, back
end

-- The client's half, on a prepared pet at the dressing scale: every effect.
function AlienDress.adorn(pet: Model)
	local zone = tostring(pet:GetAttribute("Zone"))
	local signature = tostring(pet:GetAttribute("Signature") or "")
	local tier, meteor, core, tierColor, accent = looksOf(pet)
	local paints = paintsOf(pet)
	local wingParts, flameParts, jetParts = partsOf(pet, paints)

	local cf, size = pet:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2
	local fx, top, back = carrier(pet, cf, size)

	jets(fx, jetParts, paints)

	-- Light low under the body: it lights the floor round the pet (a bright light on the body burns
	-- its colours to white under Bloom). Its range is set again for the pet's size (adornLocally).
	local light = Instance.new("PointLight")
	light.Name = "CoreLight"
	light.Color = if meteor then FIRE elseif tier == 4 then GOLD else boost(core, 1.2, 1)
	light.Brightness = 0.9 + tier * 0.15
	light.Range = (8 + radius * 1.5) * 0.75
	light.Shadows = false
	light.Parent = attachment(fx, "LightLow", Vector3.new(0, -fx.Size.Y * 0.6, 0))

	aura(fx, top, radius, tier, meteor, zone, core, tierColor)
	signatures(fx, top, back, signature, core, flameParts)
	if meteor then
		meteorFire(pet, fx, cf, size, radius, tier)
	end
	if tier == 4 then
		legendaryGlow(fx, top, size, radius, meteor)
	end
	wings(wingParts, paints, accent)
	-- Comets instead of orbit rings (tier 3+), unless a meteor's fireballs fly already.
	if tier >= 3 and not meteor then
		for index = 1, tier - 1 do
			comet(pet, cf, radius, index, tier - 1, boost(accent, 0.5, 1.2), accent, false)
		end
	end
	rune(pet, cf, size, accent)
	clusters(pet, cf, size)
end

-- A guardian's effects (decision 090), on a model painted by paintModel, at the dressing scale:
-- only its kind's signature (flames, bubbles, a spout, smoke...) and its jets, the pet's; no aura,
-- light, comets or rune: 132 guardians stand on the map.
function AlienDress.adornSignature(model: Model, core: Color3)
	local paints = paintsOf(model)
	local _, flameParts, jetParts = partsOf(model, paints)
	local cf, size = model:GetBoundingBox()
	local fx, top, back = carrier(model, cf, size)
	jets(fx, jetParts, paints)
	signatures(fx, top, back, tostring(model:GetAttribute("Signature") or ""), core, flameParts)
end

-- Adorns `model`, a prepared pet the server placed at its own size, on this client only. The
-- effects are tuned at the dressing scale, so they are made on a local copy scaled there; the copy
-- is scaled back and what was made on it moves onto the model (a part's attachments onto the same
-- part of the model: a copy keeps its children in order). The glow under it does not grow with it.
function AlienDress.adornLocally(model: Model)
	local copy = model:Clone()
	local twins: { [Instance]: Instance } = {}
	local function pair(a: Instance, b: Instance)
		twins[a] = b
		local theirs = b:GetChildren()
		for index, child in a:GetChildren() do
			local other = theirs[index]
			if other then
				pair(child, other)
			end
		end
	end
	pair(copy, model)
	local scale = model:GetScale()
	copy:ScaleTo(MODELS.DRESS_SCALE)
	AlienDress.adorn(copy)
	copy:ScaleTo(scale)
	copy:PivotTo(model:GetPivot())
	local ratio = scale / MODELS.DRESS_SCALE
	for _, made in copy:GetDescendants() do
		local parent = made.Parent
		local home = if twins[made] == nil and parent then twins[parent] else nil
		if home then
			made.Parent = home
		end
		-- A ribbon tied to points the model already had (the wings' Dust points) is tied to the
		-- model's own ones, not the copy's (gone with it).
		if made:IsA("Trail") then
			local trail = made :: Trail
			local a0, a1 = trail.Attachment0, trail.Attachment1
			if a0 and twins[a0] then
				trail.Attachment0 = twins[a0] :: Attachment
			end
			if a1 and twins[a1] then
				trail.Attachment1 = twins[a1] :: Attachment
			end
		end
	end
	for _, light in model:GetDescendants() do
		if light:IsA("PointLight") then
			light.Range = math.clamp(light.Range * ratio, MODELS.LIGHT_RANGE_MIN, MODELS.LIGHT_RANGE_MAX)
		end
	end
	-- The rune's lift scaled with the pet: a small one's sat in its pad. The same height for all.
	local halo = model:FindFirstChild("Halo")
	local feet = feetOf(model)
	if halo and halo:IsA("BasePart") and feet < math.huge then
		local at = halo.Position
		halo.CFrame = halo.CFrame - at + Vector3.new(at.X, feet + MODELS.RUNE_LIFT - halo.Size.Y / 2, at.Z)
	end
	copy:Destroy()
end

return table.freeze(AlienDress)
