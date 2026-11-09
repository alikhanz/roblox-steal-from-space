-- Dresses the robot pets in ServerStorage.RoboPets/<kind>/<kind>-<variant> for the game look (preview
-- prototype, a ModuleScript run from Edit via MCP). The pets come from PetUnpack (unpack.luau): the
-- pet's data in its attributes, each part's paint in the part's Paint attribute. Paint
-- and size; a soft core light low under the body; particles by zone and signature, soft (fading in and out) and
-- layered (a soft glow under the sparkles); fairy wings with a see-through membrane; comets with
-- particle tails instead of orbit rings; a turning rune circle on the floor; and for a meteor a
-- smouldering basalt shell, fireball comets, a comet tail of fire, smoke and sparks and a crest of
-- fire behind its head; a legendary glows (a big soft radiance behind it) under a turning medal of rays.
local ROOT = game.ServerStorage.RoboPets

local TEX = {
	star = "rbxassetid://113891832030197",
	spark = "rbxassetid://97606944575232",
	bolt = "rbxassetid://108158096824089",
	drop = "rbxassetid://72681449255345",
	bubble = "rbxassetid://86123911810039",
	ember = "rbxassetid://82123783399839",
	flame = "rbxassetid://120732950893778",
	halo = "rbxassetid://100306136441986",
	rays = "rbxassetid://75268695809192",
	crest = "rbxassetid://73996927875354",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local SCALE = 3.3
local GOLD = Color3.fromRGB(255, 200, 70)
local FIRE = Color3.fromRGB(255, 120, 30)
local WHITE = Color3.new(1, 1, 1)
-- Blender materials that need their own treatment here (the sidecar names each part's material).
-- Light drawn as geometry in Blender (flame tongues, the medal rays): hidden, particles play it.
local STAND_INS = { Flame = true, FlameCore = true, Tongue = true, Ray = true, RayShort = true }
-- Ice and glass that glow a little in Blender: clear tinted glass here, never a solid Neon spike.
local CRYSTALS = { Shard = true, IceSpike = true, Icicle = true, Fringe = true, Spout = true, Bubble = true, Brood = true }
-- Gold in Blender (the legendary's crown, gold armour, a circlet, a badge): bright gold here.
local GOLDS = { Gold = true, GoldArmour = true, Crown = true, Circlet = true, Badge = true }
-- Faint see-through glows (a hover field, a smoke wisp): barely-there Neon.
local AURAS = { Hover = true, Smoke = true }
-- Soft pastel light in Blender (the aurora's ribbons): half see-through Neon in a richer colour, or
-- Bloom burns the pale colours to white squares.
local RIBBONS = { Aurora = true }
-- Polished metal for the pets' gold and chrome: a material variant of flat maps (white colour, about
-- 0.6 metalness, 0.3 roughness; assets/fx/pbr-*.svg). Under Realistic lighting (decision 076) it
-- catches highlights; plastic with reflectance stays flat.
local METAL = game:GetService("MaterialService"):FindFirstChild("PetMetal") or Instance.new("MaterialVariant")
METAL.Name = "PetMetal"
METAL.BaseMaterial = Enum.Material.SmoothPlastic
METAL.ColorMap = "rbxassetid://100769285128033"
METAL.MetalnessMap = "rbxassetid://98590861543766"
METAL.RoughnessMap = "rbxassetid://118069329022679"
METAL.StudsPerTile = 10
METAL.Parent = game:GetService("MaterialService")
-- A meteor's molten shell: the seamless crack texture and its emissive mask
-- (assets/blender/aliens/lava_texture.py).
local LAVA = {
	colour = "rbxassetid://76302202190340",
	glow = "rbxassetid://107726084185062",
	strength = 4,
	tint = Color3.fromRGB(255, 120, 35),
}
-- Particles fade in and out instead of popping: the soft look.
local SOFT = { { 0, 1 }, { 0.15, 0 }, { 0.75, 0.15 }, { 1, 1 } }

local function rgb(text)
	local r, g, b = text:match("(%d+),(%d+),(%d+)")
	return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
end

local function boost(c, sat, val)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * sat), math.min(1, v * val))
end

local function seq(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keys)
end

local function colours(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(keys)
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission = 1
	e.LightInfluence = 0
	e.ZOffset = 0.5
	e.Transparency = seq(SOFT)
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function attachment(parent, name, position)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	return a
end

-- A camera-facing picture on an attachment (a BillboardGui): steady, where particle copies fading in
-- and out of each other flicker. Its root (the point the picture fans out of, `rootY` down from its
-- top) sits on the attachment. Layers are { colour, share of the board, transparency, "Spin" or
-- "Sway", value }: the client turns each image (animate.luau), Spin degrees a second or a slow sway.
-- The textures are white to the last empty pixel (assets/fx): Roblox filters them without
-- premultiplying, and black empty pixels left a dark disc where the rays meet.
local function board(at, name, texture, size, rootY, layers)
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
	return gui
end

-- A comet circling the pet: a glowing head and a tail of particles left behind in the world.
local function comet(model, cf, radius, index, count, head, tail, fiery)
	local wisp = Instance.new("Part")
	wisp.Name = "Wisp" .. index
	wisp.Shape = Enum.PartType.Ball
	wisp.Size = Vector3.one * (if fiery then 0.7 else 0.55)
	wisp.Material = Enum.Material.Neon
	wisp.Color = head
	wisp.Anchored, wisp.CanCollide, wisp.CanQuery, wisp.CanTouch, wisp.CastShadow = true, false, false, false, false
	wisp.CFrame = cf
	wisp:SetAttribute("Role", "wisp")
	wisp:SetAttribute("Orbit", radius * (1.05 + 0.12 * index))
	wisp:SetAttribute("Tilt", (index - (count + 1) / 2) * 0.9)
	wisp:SetAttribute("Phase", index * math.tau / count)
	wisp:SetAttribute("Speed", if fiery then 1.9 else 1.6)
	if fiery then
		emitter(wisp, "FireTail", {
			Texture = TEX.flame,
			Color = colours({ { 0, Color3.fromRGB(255, 245, 190) }, { 0.3, Color3.fromRGB(255, 160, 40) }, { 1, Color3.fromRGB(190, 30, 10) } }),
			Size = seq({ { 0, 0.9 }, { 1, 0.15 } }),
			Lifetime = NumberRange.new(0.35, 0.55),
			Rate = 70,
			Speed = NumberRange.new(0, 0.4),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
		})
		emitter(wisp, "TailSmoke", {
			Texture = TEX.smoke,
			LightEmission = 0,
			LightInfluence = 1,
			Color = ColorSequence.new(Color3.fromRGB(70, 55, 50)),
			Transparency = seq({ { 0, 0.7 }, { 1, 1 } }),
			Size = seq({ { 0, 0.5 }, { 1, 1.6 } }),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 18,
			Speed = NumberRange.new(0, 0.3),
		})
	else
		emitter(wisp, "StarTail", {
			Texture = TEX.star,
			Color = colours({ { 0, WHITE }, { 0.4, tail }, { 1, tail } }),
			Size = seq({ { 0, 0.55 }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 45,
			Speed = NumberRange.new(0, 0.5),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
		})
		emitter(wisp, "GlowTail", {
			Texture = TEX.ember,
			Color = ColorSequence.new(tail),
			Transparency = seq({ { 0, 0.3 }, { 1, 1 } }),
			Size = seq({ { 0, 0.9 }, { 1, 0.1 } }),
			Lifetime = NumberRange.new(0.4, 0.6),
			Rate = 60,
			Speed = NumberRange.new(0, 0.1),
		})
	end
	wisp.Parent = model
end

-- Dresses the pets named in `only` (all when nil) and reports what it did.
return function(only: { [string]: boolean }?): string
	local report = {}
	for _, model in ROOT:GetDescendants() do
		if not (model:IsA("Model") and model:GetAttribute("Zone")) then
			continue
		end
		local name = model.Name
		if only and not only[name] then
			continue
		end
		for _, d in model:GetDescendants() do
			if d.Parent and (d:IsA("PackageLink") or d.Name == "Fx" or d.Name == "Halo" or d.Name:match("^Wisp") or d.Name == "Tip" or d.Name == "Tail") then
				d:Destroy()
			end
		end
		local zone, tier, meteor = model:GetAttribute("Zone"), model:GetAttribute("Tier"), model:GetAttribute("Meteor")
		local signature = model:GetAttribute("Signature") or ""
		local core, tierColor = rgb(model:GetAttribute("Core")), rgb(model:GetAttribute("TierColor"))
		local paints = {}
		for _, part in model:GetDescendants() do
			local code = part:IsA("MeshPart") and part:GetAttribute("Paint")
			if code then
				-- <kind><r>,<g>,<b>,<transparency>,<reflectance>,<Blender material>
				local kind, r, g, b, t, refl, source = code:match("^(%a)(%d+),(%d+),(%d+),([%d%.]+),([%d%.]+),?(%a*)$")
				paints[part.Name] = { kind, Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)), tonumber(t), tonumber(refl), source }
			end
		end

		-- Paint. Opaque hull a touch richer than in Blender (Roblox's light is flatter); a meteor's
		-- molten parts wear the lava crack texture, its heat also shown by light and embers.
		local wingParts, flameParts, jetParts = {}, {}, {}
		for _, part in model:GetDescendants() do
			if not part:IsA("MeshPart") then
				continue
			end
			local p = paints[part.Name]
			local role = part.Name:match("^(%a+)")
			part:SetAttribute("Role", role)
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.TextureID = ""
			if not p then
				continue
			end
			local kind, colour, transparency = p[1], p[2], p[3]
			if kind == "S" and p[4] >= 0.3 then
				-- Metal in Blender (gold, chrome, brass, a rare kind's candy paint): polished metal here
				-- (the PetMetal variant). Metal shows only what it reflects, and space is dark, so it is
				-- partly metal and gold is a bright, saturated gold, or it turns olive; other metals keep
				-- their own colour, a touch richer.
				part.Material = Enum.Material.SmoothPlastic
				part.MaterialVariant = METAL.Name
				part.Color = if GOLDS[p[5]] then Color3.fromRGB(255, 190, 45) else boost(colour, 1.15, 1.05)
				part.Reflectance = 0
				part.Transparency = 0
			elseif kind == "S" then
				part.Material = Enum.Material.SmoothPlastic
				part.Color = boost(colour, 1.25, 1.12)
				part.Reflectance = math.min(p[4], 0.15)
				part.Transparency = 0
			elseif kind == "G" then
				part.Material = Enum.Material.Glass
				part.Color = colour
				part.Transparency = if transparency >= 0.7 then 0.45 else 0.2
			elseif kind == "L" then
				-- Cooled crust with glowing lava in the cracks: the crack texture on the export's
				-- box-projected UVs, the cracks lit by the emissive mask.
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new(1, 1, 1)
				part.Reflectance = 0
				local old = part:FindFirstChildOfClass("SurfaceAppearance")
				if old then
					old:Destroy()
				end
				local lava = Instance.new("SurfaceAppearance")
				lava.ColorMap = LAVA.colour
				lava.EmissiveMaskContent = Content.fromUri(LAVA.glow)
				lava.EmissiveStrength = LAVA.strength
				lava.EmissiveTint = LAVA.tint
				lava.Parent = part
			else
				part.Material = Enum.Material.Neon
				part.Color = colour
				part.Transparency = 0
			end
			-- What the part is in Blender, where a flat Roblox material would get it wrong.
			local source = p[5]
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
			elseif role:match("^hinge") then
				part.Transparency = 1 -- a pivot marker (a wing's, a crab jaw's), never seen
			elseif role == "ring" then
				part.Transparency = 1 -- the rune circle takes its place
			elseif role == "rays" then
				part.Transparency = 1 -- Blender's sunburst spikes; a medal of light (particles) takes their place
			end
		end

		model:ScaleTo(SCALE)
		local cf, size = model:GetBoundingBox()
		local radius = math.max(size.X, size.Z) / 2
		local accent = if meteor then FIRE elseif tier == 4 then GOLD else tierColor

		-- The effects carrier: an invisible box over the body, moving with it.
		local fx = Instance.new("Part")
		fx.Name = "Fx"
		fx:SetAttribute("Role", "body")
		fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch = true, false, false, false
		fx.Transparency = 1
		fx.Size = Vector3.new(size.X * 0.7, size.Y * 0.7, size.Z * 0.7)
		fx.CFrame = cf
		fx.Parent = model
		local top = attachment(fx, "Top", Vector3.new(0, size.Y * 0.5, 0))
		-- The back of the pet: the imported model faces -Z, so its back is +Z (a meteor's tail streams from here).
		local back = attachment(fx, "Back", Vector3.new(0, size.Y * 0.05, size.Z * 0.45))

		-- The jetpack's flames (tier 2+): from each nozzle (the top of Blender's hidden flame cone), a
		-- short jet down and a little back, in the colour Blender gave it with a pale core; it streams
		-- behind as the pet bobs. The cone's length sets the jet's.
		for index, part in jetParts do
			-- The cone stands almost upright, its base half its length above its middle.
			local length = math.max(part.Size.X, part.Size.Y, part.Size.Z)
			local nozzle = attachment(fx, "Jet" .. index, fx.CFrame:PointToObjectSpace(part.Position + Vector3.new(0, length * 0.45, 0)))
			nozzle.CFrame *= CFrame.Angles(-0.29, 0, 0) -- Bottom leans to +Z, the pet's back
			local colour = paints[part.Name][2]
			emitter(nozzle, "JetFlame", {
				Texture = TEX.flame,
				EmissionDirection = Enum.NormalId.Bottom,
				LightEmission = 0.6,
				Color = colours({ { 0, WHITE }, { 0.25, boost(colour, 1, 1.2) }, { 1, colour } }),
				Transparency = seq({ { 0, 0.2 }, { 0.5, 0.35 }, { 1, 1 } }),
				Size = seq({ { 0, length * 0.4 }, { 0.3, length * 0.5 }, { 1, length * 0.1 } }),
				Lifetime = NumberRange.new(0.26, 0.36),
				Rate = 50,
				Speed = NumberRange.new(length * 5, length * 6.5),
				SpreadAngle = Vector2.new(8, 8),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
			})
			emitter(nozzle, "JetCore", {
				Texture = TEX.flame,
				EmissionDirection = Enum.NormalId.Bottom,
				LightEmission = 0.9,
				Color = ColorSequence.new(WHITE),
				Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
				Size = seq({ { 0, length * 0.24 }, { 1, length * 0.05 } }),
				Lifetime = NumberRange.new(0.14, 0.22),
				Rate = 30,
				Speed = NumberRange.new(length * 3.5, length * 4.5),
				SpreadAngle = Vector2.new(5, 5),
				Rotation = NumberRange.new(0, 360),
				ZOffset = 0.6,
			})
		end

		-- Light low under the body: it lights the floor round the pet (a bright light on the body
		-- burns its colours to white under Bloom).
		local light = Instance.new("PointLight")
		light.Name = "CoreLight"
		light.Color = if meteor then FIRE elseif tier == 4 then GOLD else boost(core, 1.2, 1)
		light.Brightness = 0.9 + tier * 0.15
		light.Range = (8 + radius * 1.5) * 0.75
		light.Shadows = false
		light.Parent = attachment(fx, "LightLow", Vector3.new(0, -fx.Size.Y * 0.6, 0))

		local k = 1 + tier * 0.6
		-- Every pet: a soft glow round it in its core colour, and twinkling stars in the tier colour.
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

		-- The zone's own effect.
		if zone == "debris" then
			emitter(top, "Sparks", {
				Texture = TEX.spark,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Transparency = seq({ { 0, 0 }, { 1, 1 } }),
				Color = colours({ { 0, Color3.fromRGB(255, 250, 200) }, { 0.5, Color3.fromRGB(255, 180, 60) }, { 1, Color3.fromRGB(255, 100, 30) } }),
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
				Color = colours({ { 0, Color3.fromRGB(255, 235, 150) }, { 0.5, Color3.fromRGB(255, 110, 40) }, { 1, Color3.fromRGB(220, 40, 90) } }),
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
				Color = colours({ { 0, WHITE }, { 0.5, Color3.fromRGB(200, 160, 255) }, { 1, Color3.fromRGB(120, 180, 255) } }),
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

		-- The signature's effect.
		for sig in signature:gmatch("[^%+]+") do
			if sig == "flames" then
				-- The candle flames burn where Blender drew their (now hidden) tongues, as tall as they
				-- were: from just above the dome (Roblox draws no particles behind Glass, so inside the
				-- dome they would vanish), a body of fire and a pale core, not too additive (on a bright
				-- background additive fire disappears).
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
				emitter(flameAt, "Flames", {
					Texture = TEX.flame,
					LightEmission = 0.4,
					Transparency = seq({ { 0, 0.6 }, { 0.15, 0.05 }, { 0.6, 0.2 }, { 1, 1 } }),
					Color = colours({ { 0, Color3.fromRGB(255, 230, 120) }, { 0.35, Color3.fromRGB(255, 140, 30) }, { 1, Color3.fromRGB(200, 40, 15) } }),
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
					Transparency = seq({ { 0, 0.6 }, { 0.15, 0.05 }, { 0.6, 0.2 }, { 1, 1 } }),
					Color = ColorSequence.new(Color3.fromRGB(255, 245, 190)),
					Size = seq({ { 0, lift * 0.4 }, { 0.5, lift * 0.35 }, { 1, lift * 0.07 } }),
					Lifetime = NumberRange.new(0.3, 0.45),
					Rate = 15,
					Speed = NumberRange.new(lift * 0.9, lift * 1.25),
					SpreadAngle = Vector2.new(12, 12),
					Rotation = NumberRange.new(-20, 20),
					RotSpeed = NumberRange.new(-40, 40),
				})
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

		-- A meteor burns on top of its tier: a comet tail behind (a fire core that widens and cools
		-- from white-yellow to red, dark smoke after it, sparks), heat embers round the body and
		-- fireball comets circling it.
		if meteor then
			emitter(back, "TailFire", {
				Texture = TEX.flame,
				EmissionDirection = Enum.NormalId.Back,
				Color = colours({
					{ 0, Color3.fromRGB(255, 250, 210) },
					{ 0.2, Color3.fromRGB(255, 200, 80) },
					{ 0.55, Color3.fromRGB(255, 110, 25) },
					{ 1, Color3.fromRGB(150, 25, 10) },
				}),
				Transparency = seq({ { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } }),
				Size = seq({ { 0, 0.8 }, { 0.4, 1.9 }, { 1, 2.8 } }),
				Lifetime = NumberRange.new(0.5, 0.9),
				Rate = 70,
				Speed = NumberRange.new(6, 9),
				Drag = 2.5,
				Acceleration = Vector3.new(0, 2, 0),
				SpreadAngle = Vector2.new(10, 10),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-45, 45),
			})
			emitter(back, "TailSmoke", {
				Texture = TEX.smoke,
				LightEmission = 0,
				LightInfluence = 1,
				EmissionDirection = Enum.NormalId.Back,
				Color = ColorSequence.new(Color3.fromRGB(60, 48, 44)),
				Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
				Size = seq({ { 0, 1.2 }, { 1, 4.5 } }),
				Lifetime = NumberRange.new(1.4, 2.2),
				Rate = 22,
				Speed = NumberRange.new(4, 6),
				Drag = 1.2,
				Acceleration = Vector3.new(0, 1.5, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-20, 20),
			})
			emitter(back, "TailSparks", {
				Texture = TEX.spark,
				EmissionDirection = Enum.NormalId.Back,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Transparency = seq({ { 0, 0 }, { 1, 1 } }),
				Color = colours({ { 0, Color3.fromRGB(255, 240, 180) }, { 1, Color3.fromRGB(255, 120, 30) } }),
				Size = seq({ { 0, 0.18 }, { 1, 0.05 } }),
				Lifetime = NumberRange.new(0.4, 0.8),
				Rate = 30,
				Speed = NumberRange.new(7, 12),
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, -6, 0),
			})
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
				comet(model, cf, radius, index, count, Color3.fromRGB(255, 190, 90), FIRE, true)
			end
		end

		-- A legendary glows: a big soft radiance behind the body (gold; fire for a meteor) that
		-- breathes slowly, a brighter heart in it and slow sparkles drifting out of it. The glow
		-- moves with the pet (locked to the carrier). Drawn at its own depth, just behind the body: pushed
		-- further back (a negative ZOffset) it shows round the body more, burns brighter and washes out the medal.
		if tier == 4 then
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
			-- The medal of rays from the Blender renders (its sunburst), on the glow: gold, or fire on
			-- a meteor; two layers turning slowly against each other.
			board(glow, "Medal", TEX.rays, radius * 2.8, 0.5, {
				{ warm, 1, 0.3, "Spin", 4 },
				{ pale, 0.7, 0.5, "Spin", -7 },
			})
		end

		-- A meteor of any tier wears a crest of fire behind its head (in the Blender renders, its comet
		-- tail seen from the front: tongues fanning up and out), growing with the tier; it sways a little.
		if meteor then
			local root = attachment(fx, "Crest", Vector3.new(0, size.Y * 0.15, size.Z * 0.3))
			board(root, "Crest", TEX.crest, radius * (1.6 + tier * 0.25), 0.78, {
				{ FIRE, 1, 0.15, "Sway", 1 },
				{ Color3.fromRGB(255, 210, 120), 0.75, 0.35, "Sway", 2 },
			})
		end

		-- A legendary showers gold glitter.
		if tier == 4 then
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

		-- Fairy wings (modelled in Blender, a role a side): the membrane is a faint tint; its glowing
		-- edge, veins and pattern carry the shape. Sparkles fall off the tip.
		for _, side in { "wingL", "wingR" } do
			-- The membrane is the part of the wing material (EnergyWing, GoldWing); the edge and veins
			-- are the glowing lines.
			local membrane
			for _, part in wingParts do
				local source = paints[part.Name] and paints[part.Name][5] or ""
				if part:GetAttribute("Role") == side and source:match("Wing$") then
					membrane = part
				end
			end
			if membrane then
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
				-- Outwards is the side the wing really sits on (the import turns the pet round, so
				-- Blender's left wing is at +X here), not its role's name.
				local sign = if fx.CFrame:PointToObjectSpace(membrane.Position).X > 0 then 1 else -1
				-- The forewing's sharp tip: up and out.
				local tip = attachment(membrane, "Tip", Vector3.new(sign * membrane.Size.X * 0.45, membrane.Size.Y * 0.45, 0))
				emitter(tip, "TipSparkles", {
					Texture = TEX.star,
					Color = colours({ { 0, WHITE }, { 1, accent } }),
					Size = seq({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } }),
					Lifetime = NumberRange.new(0.6, 1.1),
					Rate = 25,
					Speed = NumberRange.new(0.3, 1),
					Acceleration = Vector3.new(0, -1.5, 0),
					SpreadAngle = Vector2.new(180, 180),
				})
			end
		end

		-- Fairy dust off part of each wing's edge: the dust markers from Blender become emitters on
		-- the membrane (so they flap with it), throwing fine glowing dust in the wing's colour along
		-- the stroke, forwards as the wing opens and back as it folds (the client fires them).
		-- The markers are gone after the first dressing; then the Dust points they left are dressed anew.
		for _, marker in model:GetDescendants() do
			local host, at
			if marker:IsA("MeshPart") and marker.Name:match("^dust[LR]") then
				local side = "wing" .. marker.Name:sub(5, 5)
				for _, part in wingParts do
					if part:GetAttribute("Role") == side and part.Material == Enum.Material.SmoothPlastic then
						host = part
					end
				end
				if host then
					at = Instance.new("Attachment")
					at.Name = "Dust"
					at.Parent = host
					at.WorldPosition = marker.Position
				end
				marker:Destroy()
			elseif marker:IsA("Attachment") and marker.Name == "Dust" then
				host, at = marker.Parent, marker
				at:ClearAllChildren()
			end
			if host then
				local dust = boost(accent, 0.8, 1.2)
				-- The dust follows the stroke: opening, the wing edge sweeps forward (the pet faces -Z,
				-- so forward is Front); folding, it sweeps back over the pet's back.
				for _, stroke in { { "DustOpen", Enum.NormalId.Front }, { "DustFold", Enum.NormalId.Back } } do
					emitter(at, stroke[1], {
						Texture = TEX.ember,
						EmissionDirection = stroke[2],
						Color = colours({ { 0, WHITE }, { 0.3, dust }, { 1, accent } }),
						Size = seq({ { 0, 0 }, { 0.15, 0.24, 0.1 }, { 0.7, 0.15, 0.07 }, { 1, 0 } }),
						Lifetime = NumberRange.new(0.9, 1.6),
						Rate = 0,
						Speed = NumberRange.new(2, 4.5),
						Drag = 2.5,
						Acceleration = Vector3.new(0, -0.6, 0),
						SpreadAngle = Vector2.new(40, 40),
					})
					emitter(at, stroke[1] .. "Star", {
						Texture = TEX.star,
						EmissionDirection = stroke[2],
						Color = colours({ { 0, WHITE }, { 1, dust } }),
						Size = seq({ { 0, 0 }, { 0.2, 0.3, 0.12 }, { 1, 0 } }),
						Lifetime = NumberRange.new(0.6, 1.1),
						Rate = 0,
						Speed = NumberRange.new(1.5, 3.5),
						Drag = 2,
						SpreadAngle = Vector2.new(50, 50),
						RotSpeed = NumberRange.new(-180, 180),
					})
				end
			end
		end

		-- Comets instead of orbit rings (tier 3+), unless a meteor's fireballs fly already.
		if tier >= 3 and not meteor then
			for index = 1, tier - 1 do
				comet(model, cf, radius, index, tier - 1, boost(accent, 0.5, 1.2), accent, false)
			end
		end

		-- A rune circle on the floor instead of the plain tier ring: it glows in the tier colour, turns
		-- slowly, and motes rise from its rim.
		local floorY = cf.Position.Y - size.Y / 2
		local halo = Instance.new("Part")
		halo.Name = "Halo"
		halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch, halo.CastShadow = true, false, false, false, false
		halo.Transparency = 1
		local haloSize = math.max(size.X, size.Z) * 0.95
		halo.Size = Vector3.new(haloSize, 0.05, haloSize)
		halo.CFrame = CFrame.new(cf.Position.X, floorY + 0.08, cf.Position.Z)
		halo:SetAttribute("Role", "halo")
		for _, layer in { { TEX.halo, accent, 0, "Rune" }, { TEX.ember, accent, 0.55, "Glow" } } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = layer[4]
			gui.Face = Enum.NormalId.Top
			gui.LightInfluence = 0
			gui.Brightness = 2
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(256, 256)
			local image = Instance.new("ImageLabel")
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.Image = layer[1]
			image.ImageColor3 = layer[2]
			image.ImageTransparency = layer[3]
			image.Parent = gui
			gui.Parent = halo
		end
		emitter(halo, "RimMotes", {
			Texture = TEX.star,
			Color = colours({ { 0, WHITE }, { 1, accent } }),
			Size = seq({ { 0, 0 }, { 0.2, 0.32 }, { 1, 0 } }),
			Lifetime = NumberRange.new(1, 1.8),
			Rate = 10 + tier * 6,
			Speed = NumberRange.new(1.5, 2.5),
			EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		halo.Parent = model
		table.insert(report, string.format("%s: tier %d%s", name, tier, if meteor then " meteor" else ""))
	end
	return table.concat(report, "\n")
end
