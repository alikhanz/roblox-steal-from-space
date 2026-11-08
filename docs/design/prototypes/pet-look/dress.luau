-- Dresses the imported robot pets in ServerStorage.RoboPet2 for the game look (preview prototype,
-- run in Edit via MCP; the paint data sits in ServerStorage.RoboPetData). Paint and size; a soft
-- core light low under the body; particles by zone and signature, soft (fading in and out) and
-- layered (a soft glow under the sparkles); fairy wings with a see-through membrane; comets with
-- particle tails instead of orbit rings; a turning rune circle on the floor; and for a meteor a
-- smouldering basalt shell, fireball comets and a comet tail of fire, smoke and sparks.
local DATA = game:GetService("HttpService"):JSONDecode(game.ServerStorage.RoboPetData.Value)

local TEX = {
	star = "rbxassetid://113891832030197",
	spark = "rbxassetid://97606944575232",
	bolt = "rbxassetid://108158096824089",
	drop = "rbxassetid://72681449255345",
	bubble = "rbxassetid://86123911810039",
	ember = "rbxassetid://82123783399839",
	flame = "rbxassetid://120732950893778",
	halo = "rbxassetid://100306136441986",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local SCALE = 3.3
local GOLD = Color3.fromRGB(255, 200, 70)
local FIRE = Color3.fromRGB(255, 120, 30)
local WHITE = Color3.new(1, 1, 1)
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

local report = {}
for name, entry in DATA do
	local model = game.ServerStorage.RoboPet2:FindFirstChild(name)
	if not model then
		table.insert(report, "missing " .. name)
		continue
	end
	for _, d in model:GetDescendants() do
		if d.Parent and (d:IsA("PackageLink") or d.Name == "Fx" or d.Name == "Halo" or d.Name:match("^Wisp") or d.Name == "Tip") then
			d:Destroy()
		end
	end
	local zone, _family, tier, meteor, signature, _glow, core, tierColor =
		entry[1]:match("^(%a+)|(%a+)|(%d)|(%a+)|([%a%+]*)|([%d,]+)|([%d,]+)|([%d,]+)|([%d,]+)$")
	tier = tonumber(tier)
	meteor = meteor == "true"
	core, tierColor = rgb(core), rgb(tierColor)
	local paints = {}
	for item in entry[2]:gmatch("[^;]+") do
		local part, kind, r, g, b, t, refl = item:match("^([%w_]+)=(%a)(%d+),(%d+),(%d+),([%d%.]+),([%d%.]+)$")
		paints[part] = { kind, Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)), tonumber(t), tonumber(refl) }
	end

	-- Paint. Opaque hull a touch richer than in Blender (Roblox's light is flatter); a meteor's
	-- molten parts become smouldering basalt, its heat shown by light and embers.
	local wingParts = {}
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
		if kind == "S" then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = boost(colour, 1.25, 1.12)
			part.Reflectance = math.min(p[4], 0.15)
			part.Transparency = 0
		elseif kind == "G" then
			part.Material = Enum.Material.Glass
			part.Color = colour
			part.Transparency = if transparency >= 0.7 then 0.45 else 0.2
		elseif kind == "L" then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(48, 32, 28)
			part.Reflectance = 0.05
		else
			part.Material = Enum.Material.Neon
			part.Color = colour
			part.Transparency = 0
		end
		part.CastShadow = part.Material ~= Enum.Material.Neon
		if role == "core" then
			part.Material = Enum.Material.Neon
			part.Color = boost(core, 1.2, 1.2)
		elseif role == "wingL" or role == "wingR" then
			table.insert(wingParts, part)
		elseif role == "ring" then
			part.Transparency = 1 -- the rune circle takes its place
		elseif role == "rays" then
			part.Transparency = 0.45
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
	local back = attachment(fx, "Back", Vector3.new(0, size.Y * 0.05, -size.Z * 0.45))

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
			emitter(top, "Flames", {
				Texture = TEX.flame,
				Color = colours({ { 0, Color3.fromRGB(255, 250, 200) }, { 0.3, Color3.fromRGB(255, 170, 50) }, { 1, Color3.fromRGB(220, 40, 20) } }),
				Size = seq({ { 0, 0.8 }, { 0.5, 1.3 }, { 1, 0.2 } }),
				Lifetime = NumberRange.new(0.45, 0.75),
				Rate = 45,
				Speed = NumberRange.new(3, 5),
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
			EmissionDirection = Enum.NormalId.Front,
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
			EmissionDirection = Enum.NormalId.Front,
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
			EmissionDirection = Enum.NormalId.Front,
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
	-- edge, veins and pattern carry the shape. The membrane is the smaller of a wing's two parts
	-- (the edge's tube sticks out past it). Sparkles fall off the tip.
	for _, side in { "wingL", "wingR" } do
		local membrane, area = nil, math.huge
		for _, part in wingParts do
			if part:GetAttribute("Role") == side and part.Size.X * part.Size.Y < area then
				membrane, area = part, part.Size.X * part.Size.Y
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
			local sign = if side == "wingL" then -1 else 1
			local tip = attachment(membrane, "Tip", Vector3.new(sign * membrane.Size.X * 0.42, membrane.Size.Y * 0.3, 0))
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
