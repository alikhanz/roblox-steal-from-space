-- Dresses the imported robot pets in ServerStorage.RoboPet2 for the game look: paint, size, core
-- light, particles by zone and signature, beam wings. Preview prototype (run in Edit via MCP).
local DATA = game:GetService("HttpService"):JSONDecode(game.ServerStorage.RoboPetData.Value)

local TEX = {
	star = "rbxassetid://113891832030197", spark = "rbxassetid://97606944575232", bolt = "rbxassetid://108158096824089",
	drop = "rbxassetid://72681449255345", bubble = "rbxassetid://86123911810039", ember = "rbxassetid://82123783399839",
	flame = "rbxassetid://120732950893778", wing = "rbxassetid://93963522989438",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local SCALE = 3.3
local GOLD = Color3.fromRGB(255, 200, 70)
local FIRE = Color3.fromRGB(255, 120, 30)

local function rgb(text)
	local r, g, b = text:match("(%d+),(%d+),(%d+)")
	return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
end

local function boost(c: Color3, sat: number, val: number)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * sat), math.min(1, v * val))
end

local function seq(points)
	local keys = {}
	for _, p in points do table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(keys)
end

local function colours(points)
	local keys = {}
	for _, p in points do table.insert(keys, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(keys)
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission = 1
	e.LightInfluence = 0
	e.ZOffset = 0.5
	for k, v in props do e[k] = v end
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

local report = {}
for name, entry in DATA do
	local model = game.ServerStorage.RoboPet2:FindFirstChild(name)
	if not model then table.insert(report, "missing " .. name) continue end
	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") or d.Name == "Fx" then d:Destroy() end
	end
	local zone, family, tier, meteor, signature, glow, core, tierColor, shell = entry[1]:match("^(%a+)|(%a+)|(%d)|(%a+)|([%a%+]*)|([%d,]+)|([%d,]+)|([%d,]+)|([%d,]+)$")
	tier = tonumber(tier)
	meteor = meteor == "true"
	glow, core, tierColor = rgb(glow), rgb(core), rgb(tierColor)
	local paints = {}
	for item in entry[2]:gmatch("[^;]+") do
		local part, kind, r, g, b, t, refl = item:match("^([%w_]+)=(%a)(%d+),(%d+),(%d+),([%d%.]+),([%d%.]+)$")
		paints[part] = { kind, Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)), tonumber(t), tonumber(refl) }
	end

	-- Paint. Opaque hull: a touch richer than in Blender, since Roblox's lighting is flatter.
	local cores, wingParts = {}, {}
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then continue end
		local p = paints[part.Name]
		local role = part.Name:match("^(%a+)")
		part:SetAttribute("Role", role)
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.TextureID = ""
		if not p then continue end
		local kind, colour, transparency = p[1], p[2], p[3]
		if kind == "S" then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = boost(colour, 1.25, 1.12)
			part.Reflectance = math.min(p[4], 0.15)
			part.Transparency = 0
		elseif kind == "G" then
			part.Material = Enum.Material.Glass
			part.Color = colour
			-- Domes stay see-through but solid enough to read; crystal is close to solid.
			part.Transparency = if transparency >= 0.7 then 0.45 else 0.2
		elseif kind == "L" then
			part.Material = Enum.Material.CrackedLava
			part.Color = Color3.fromRGB(120, 40, 15)
		else
			part.Material = Enum.Material.Neon
			part.Color = colour
			part.Transparency = 0
		end
		part.CastShadow = part.Material ~= Enum.Material.Neon
		if role == "core" then
			part.Material = Enum.Material.Neon
			part.Color = boost(core, 1.2, 1.2)
			part.Transparency = 0
			table.insert(cores, part)
		elseif role == "wing" then
			table.insert(wingParts, part)
			part.Transparency = 1 -- beams take their place
		elseif role == "ring" then
			part.Transparency = 0.15
		elseif role == "rays" then
			part.Transparency = 0.3
		end
	end

	model:ScaleTo(SCALE)
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2

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
	local mid = attachment(fx, "Mid", Vector3.zero)

	-- Light from the core: the pet glows and lights the floor round it.
	local light = Instance.new("PointLight")
	light.Name = "CoreLight"
	light.Color = if meteor then FIRE elseif tier == 4 then GOLD else boost(core, 1.2, 1)
	light.Brightness = 2.5 + tier * 0.5
	light.Range = 8 + radius * 1.5
	light.Shadows = false
	light.Parent = cores[1] or fx

	local k = 1 + tier * 0.7
	-- Every pet: twinkling stars in the tier colour, more with each tier.
	emitter(fx, "Twinkle", {
		Texture = TEX.star, Color = colours({ { 0, tierColor }, { 1, Color3.new(1, 1, 1) } }),
		Size = seq({ { 0, 0 }, { 0.3, 0.45 + tier * 0.08 }, { 1, 0 } }), Lifetime = NumberRange.new(0.7, 1.3),
		Rate = 2 + 3 * k, Speed = NumberRange.new(0.2, 0.6), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	-- The zone's own effect.
	if zone == "debris" then
		emitter(top, "Sparks", {
			Texture = TEX.spark, Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = colours({ { 0, Color3.fromRGB(255, 240, 160) }, { 1, Color3.fromRGB(255, 120, 30) } }),
			Size = seq({ { 0, 0.18 }, { 1, 0.05 } }), Squash = seq({ { 0, -1.5 }, { 1, -1.5 } }),
			Lifetime = NumberRange.new(0.35, 0.6), Rate = 4 * k, Speed = NumberRange.new(7, 12),
			SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -35, 0),
		})
	elseif zone == "ice" then
		emitter(fx, "Frost", {
			Texture = TEX.star, Color = colours({ { 0, Color3.fromRGB(200, 245, 255) }, { 1, Color3.fromRGB(120, 200, 255) } }),
			Size = seq({ { 0, 0 }, { 0.2, 0.3 }, { 1, 0 } }), Lifetime = NumberRange.new(1.2, 2), Rate = 6 * k,
			Speed = NumberRange.new(0.2, 0.5), Acceleration = Vector3.new(0, -1.5, 0), RotSpeed = NumberRange.new(-90, 90),
			Shape = Enum.ParticleEmitterShape.Sphere,
		})
		emitter(top, "Splash", {
			Texture = TEX.drop, LightEmission = 0.4, Color = colours({ { 0, Color3.fromRGB(220, 250, 255) }, { 1, Color3.fromRGB(120, 210, 255) } }),
			Size = seq({ { 0, 0.22 }, { 1, 0.1 } }), Lifetime = NumberRange.new(0.6, 0.9), Rate = 3 * k,
			Speed = NumberRange.new(5, 7), SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, -22, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
		})
	elseif zone == "nebula" then
		emitter(fx, "Embers", {
			Texture = TEX.ember, Color = colours({ { 0, Color3.fromRGB(255, 230, 140) }, { 0.5, Color3.fromRGB(255, 110, 40) }, { 1, Color3.fromRGB(220, 40, 80) } }),
			Size = seq({ { 0, 0.3 }, { 1, 0 } }), Lifetime = NumberRange.new(1, 1.8), Rate = 8 * k,
			Speed = NumberRange.new(0.5, 1.5), Acceleration = Vector3.new(0, 3, 0), Drag = 1,
			EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Sphere,
		})
	elseif zone == "horizon" then
		emitter(fx, "Stardust", {
			Texture = TEX.ember, Color = colours({ { 0, Color3.new(1, 1, 1) }, { 0.5, Color3.fromRGB(200, 160, 255) }, { 1, Color3.fromRGB(120, 180, 255) } }),
			Size = seq({ { 0, 0 }, { 0.2, 0.18 }, { 1, 0 } }), Lifetime = NumberRange.new(2, 3), Rate = 10 * k,
			Speed = NumberRange.new(0.3, 0.8), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		emitter(fx, "BigStars", {
			Texture = TEX.star, Color = colours({ { 0, Color3.fromRGB(230, 200, 255) }, { 1, Color3.new(1, 1, 1) } }),
			Size = seq({ { 0, 0 }, { 0.5, 0.9 }, { 1, 0 } }), Lifetime = NumberRange.new(0.8, 1.2), Rate = 0.7 * k,
			Speed = NumberRange.new(0, 0), RotSpeed = NumberRange.new(-30, 30), Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
	end

	-- The signature's effect.
	for sig in signature:gmatch("[^%+]+") do
		if sig == "flames" then
			emitter(top, "Flames", {
				Texture = TEX.flame, Color = colours({ { 0, Color3.fromRGB(255, 245, 170) }, { 0.4, Color3.fromRGB(255, 150, 40) }, { 1, Color3.fromRGB(220, 40, 20) } }),
				Size = seq({ { 0, 0.7 }, { 0.5, 1.1 }, { 1, 0 } }), Lifetime = NumberRange.new(0.4, 0.7), Rate = 28,
				Speed = NumberRange.new(3, 5), SpreadAngle = Vector2.new(12, 12), Rotation = NumberRange.new(-15, 15),
			})
		elseif sig == "lightning" then
			emitter(fx, "Bolts", {
				Texture = TEX.bolt, Color = colours({ { 0, Color3.fromRGB(255, 255, 200) }, { 1, Color3.fromRGB(120, 220, 255) } }),
				Size = NumberSequence.new(1.6), Lifetime = NumberRange.new(0.06, 0.14), Rate = 9, Speed = NumberRange.new(0, 0),
				Rotation = NumberRange.new(0, 360), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			})
		elseif sig == "spout" then
			emitter(top, "Spout", {
				Texture = TEX.drop, LightEmission = 0.5, Color = colours({ { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(140, 210, 255) } }),
				Size = seq({ { 0, 0.3 }, { 1, 0.15 } }), Lifetime = NumberRange.new(0.6, 0.9), Rate = 22,
				Speed = NumberRange.new(9, 11), SpreadAngle = Vector2.new(12, 12), Acceleration = Vector3.new(0, -28, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel,
			})
			emitter(top, "Bubbles", {
				Texture = TEX.bubble, LightEmission = 0.3, Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
				Size = seq({ { 0, 0.2 }, { 1, 0.45 } }), Lifetime = NumberRange.new(1.2, 2), Rate = 4, Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(40, 40),
			})
		elseif sig == "bubbles" then
			emitter(top, "Bubbles", {
				Texture = TEX.bubble, LightEmission = 0.5, Color = ColorSequence.new(boost(core, 1, 1.2)),
				Size = seq({ { 0, 0.2 }, { 1, 0.5 } }), Lifetime = NumberRange.new(1.5, 2.5), Rate = 7, Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(25, 25),
			})
		elseif sig == "exhausts" then
			emitter(top, "Smoke", {
				Texture = TEX.smoke, LightEmission = 0, LightInfluence = 1, Color = ColorSequence.new(Color3.fromRGB(120, 110, 105)),
				Size = seq({ { 0, 0.4 }, { 1, 1.6 } }), Transparency = seq({ { 0, 0.4 }, { 1, 1 } }), Lifetime = NumberRange.new(1, 1.6),
				Rate = 5, Speed = NumberRange.new(2, 3), SpreadAngle = Vector2.new(10, 10),
			})
		elseif sig == "galaxy" then
			emitter(fx, "Galaxy", {
				Texture = TEX.star, Color = colours({ { 0, Color3.fromRGB(255, 220, 140) }, { 1, Color3.fromRGB(200, 150, 255) } }),
				Size = seq({ { 0, 0 }, { 0.3, 0.35 }, { 1, 0 } }), Lifetime = NumberRange.new(1, 1.6), Rate = 14,
				Speed = NumberRange.new(0.2, 0.6), Shape = Enum.ParticleEmitterShape.Sphere,
			})
		end
	end

	-- A meteor burns on top of its tier: a comet tail of fire behind, embers and smoke.
	if meteor then
		emitter(back, "CometTail", {
			Texture = TEX.flame, EmissionDirection = Enum.NormalId.Front,
			Color = colours({ { 0, Color3.fromRGB(255, 240, 170) }, { 0.35, Color3.fromRGB(255, 140, 30) }, { 1, Color3.fromRGB(200, 30, 10) } }),
			Size = seq({ { 0, 1.4 }, { 1, 0.2 } }), Lifetime = NumberRange.new(0.5, 0.8), Rate = 45,
			Speed = NumberRange.new(6, 9), SpreadAngle = Vector2.new(14, 14), Rotation = NumberRange.new(0, 360),
		})
		emitter(fx, "MeteorEmbers", {
			Texture = TEX.ember, Color = colours({ { 0, Color3.fromRGB(255, 220, 120) }, { 1, Color3.fromRGB(255, 70, 20) } }),
			Size = seq({ { 0, 0.35 }, { 1, 0 } }), Lifetime = NumberRange.new(0.8, 1.4), Rate = 25,
			Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(0, 4, 0), Shape = Enum.ParticleEmitterShape.Sphere,
		})
		emitter(back, "MeteorSmoke", {
			Texture = TEX.smoke, LightEmission = 0, LightInfluence = 1, EmissionDirection = Enum.NormalId.Front,
			Color = ColorSequence.new(Color3.fromRGB(60, 45, 40)), Transparency = seq({ { 0, 0.5 }, { 1, 1 } }),
			Size = seq({ { 0, 0.8 }, { 1, 2.5 } }), Lifetime = NumberRange.new(1, 1.5), Rate = 10, Speed = NumberRange.new(3, 5),
		})
	end

	-- A legendary showers gold glitter.
	if tier == 4 then
		emitter(top, "GoldGlitter", {
			Texture = TEX.star, Color = colours({ { 0, Color3.fromRGB(255, 250, 200) }, { 1, GOLD } }),
			Size = seq({ { 0, 0 }, { 0.2, 0.4 }, { 1, 0 } }), Lifetime = NumberRange.new(1.2, 1.8), Rate = 18,
			Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -4, 0),
			RotSpeed = NumberRange.new(-120, 120),
		})
	end

	-- Beam wings where the outfit has wings: two glowing fans a side, with a bright leading edge
	-- and sparkles off the tips. The client flaps them by moving the tip attachments.
	if #wingParts > 0 then
		local wingColour = if meteor then FIRE elseif tier == 4 then GOLD else tierColor
		local span = 0
		for _, part in wingParts do
			span = math.max(span, part.Size.X / 2)
		end
		for _, side in { -1, 1 } do
			local root = attachment(fx, "WingRoot" .. side, Vector3.new(side * radius * 0.25, size.Y * 0.12, -size.Z * 0.18))
			for index, shape in { { 1.0, 0.5, 0.95 }, { 0.8, -0.05, 0.7 } } do
				local tip = attachment(fx, "WingTip" .. side .. "_" .. index, Vector3.new(side * span * shape[1], size.Y * 0.12 + span * shape[2], -size.Z * 0.35))
				tip:SetAttribute("Flap", index)
				local beam = Instance.new("Beam")
				beam.Name = "Wing"
				beam.Attachment0, beam.Attachment1 = root, tip
				beam.Texture = TEX.wing
				beam.TextureMode = Enum.TextureMode.Stretch
				beam.TextureSpeed = 0.5
				beam.FaceCamera = true
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Width0, beam.Width1 = 0.4, span * 0.55 * shape[3]
				beam.CurveSize0, beam.CurveSize1 = span * 0.25, -span * 0.15
				beam.Segments = 16
				beam.Color = colours({ { 0, Color3.new(1, 1, 1) }, { 0.4, wingColour }, { 1, boost(wingColour, 1.3, 1) } })
				beam.Transparency = seq({ { 0, 0.05 }, { 1, 0.25 } })
				beam.Parent = fx
				emitter(tip, "TipSparkles", {
					Texture = TEX.star, Color = colours({ { 0, Color3.new(1, 1, 1) }, { 1, wingColour } }),
					Size = seq({ { 0, 0 }, { 0.3, 0.35 }, { 1, 0 } }), Lifetime = NumberRange.new(0.4, 0.8), Rate = 10,
					Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
				})
			end
		end
	end
	table.insert(report, string.format("%s: %d emitters, wings %d", name, #fx:GetDescendants(), #wingParts))
end
return table.concat(report, "\n")
