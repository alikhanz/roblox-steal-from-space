--!strict
-- Client-side jetpack visuals for every character (decision 089): a jet of beams from each nozzle
-- — a white-hot core inside a jet in the jetpack's colour, its texture scrolling — and one light
-- per jetpack. The flame grows with speed while flying and goes out under the dome; a guardian's
-- hit stalls the engine, which restarts with a burst; the strike's lunge fires it full. On the
-- jetpack stand the engine runs full, bigger with the trainer's level, and the stand's grate glows.
-- Purely cosmetic, so it runs outside the simulation and never crosses the network: the server
-- sends the bare jetpack with its nozzle attachments, each client adds the flame itself.
-- Light on resources: the beams are made once per jetpack and rewritten only when the flame's
-- state changes (JetFlame steps); far from the camera the core and then the light go, and the core
-- also goes under reduced motion. No particles at all.
-- In flight a better jetpack also leaves a trail (JetpackLooks.TRAILS): a ribbon in its colour,
-- longer and wider with the grade, two from the wing tips on the legendary ones; one Trail per
-- source, enabled only while flying.
-- Also registers the flight pose in Studio so this client can play it (see FlightAnimation).

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local FlightAnimation = require(ReplicatedStorage.Shared.Character.FlightAnimation)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local JetFlame = require(ReplicatedStorage.Shared.Domain.JetFlame)
local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local TopSpeed = require(ReplicatedStorage.Shared.Simulation.TopSpeed)

export type JetpackEffectsController = {
	name: string,
	init: () -> (),
	start: () -> (),
}

-- One nozzle's flame: the jet and the core, each a beam from the nozzle to a tail of its own.
type Nozzle = {
	exit: Attachment,
	jet: Beam,
	jetTail: Attachment,
	core: Beam,
	coreTail: Attachment,
}

type Effects = {
	nozzles: { Nozzle },
	light: PointLight,
	trails: { Trail },
	looks: JetpackLooks.Looks,
	-- The flame's state last written (burning, power, detail); nil before the first.
	written: string?,
	-- The trails' state last written (flying, top speed, reduced motion).
	trailWritten: string?,
	-- True while the character was stunned on the last update; the restart burst follows.
	stalled: boolean,
	burstUntil: number,
}

local JET_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.05),
	NumberSequenceKeypoint.new(0.55, 0.35),
	NumberSequenceKeypoint.new(1, 1),
})
local CORE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.7, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})
local WHITE = Color3.new(1, 1, 1)
local TRAIL_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.6, 0.6),
	NumberSequenceKeypoint.new(1, 1),
})
local TRAIL_WIDTH = NumberSequence.new(1, 0.25)

local JetpackEffectsController = {}

local function beam(name: string, from: Attachment, to: Attachment, texture: string, scroll: number): Beam
	local made = Instance.new("Beam")
	made.Name = name
	made.Attachment0 = from
	made.Attachment1 = to
	made.FaceCamera = true
	made.Segments = 1
	made.Texture = texture
	made.TextureMode = Enum.TextureMode.Stretch
	made.TextureSpeed = scroll
	made.LightInfluence = 0
	made.Enabled = false
	made.Parent = from
	return made
end

local function tail(name: string, exit: Attachment): Attachment
	local made = Instance.new("Attachment")
	made.Name = name
	made.CFrame = exit.CFrame
	made.Parent = exit.Parent
	return made
end

-- The trails of a jetpack (none for the Starter): one between its nozzles, or with `twin` one at
-- each outermost nozzle. A Trail facing the camera is as wide as its two attachments are apart,
-- so they stand `width` apart across the jetpack, at the nozzles' height.
local function buildTrails(
	model: Model,
	exits: { Attachment },
	looks: JetpackLooks.Looks,
	step: JetpackLooks.Step,
	scale: number
): { Trail }
	local look = looks.trail
	if not look then
		return {}
	end
	local pivot = model:GetPivot()
	local across = pivot.RightVector
	-- The nozzles in the jetpack's frame, left to right.
	local spots: { Vector3 } = {}
	for _, exit in exits do
		local spot: Vector3 = pivot:PointToObjectSpace(exit.WorldPosition)
		table.insert(spots, spot)
	end
	table.sort(spots, function(a: Vector3, b: Vector3): boolean
		return a.X < b.X
	end)
	local sources: { Vector3 } = {}
	if look.twin then
		sources = { spots[1], spots[#spots] }
	else
		local sum = Vector3.zero
		for _, spot in spots do
			sum += spot
		end
		sources = { sum / #spots }
	end
	local host = exits[1].Parent :: BasePart
	local half = look.width * scale / 2
	local trails = {}
	for index, source in sources do
		local at = pivot:PointToWorldSpace(source)
		local left = Instance.new("Attachment")
		left.Name = `TrailLeft{index}`
		left.Parent = host
		left.WorldPosition = at - across * half
		local right = Instance.new("Attachment")
		right.Name = `TrailRight{index}`
		right.Parent = host
		right.WorldPosition = at + across * half
		local trail = Instance.new("Trail")
		trail.Name = "JetTrail"
		trail.Attachment0 = left
		trail.Attachment1 = right
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(looks.flameStart, looks.flameEnd)
		trail.Transparency = TRAIL_TRANSPARENCY
		trail.WidthScale = TRAIL_WIDTH
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Brightness = looks.brightness * JetpackConfig.TRAIL_BRIGHTNESS
		if step.trail then
			trail.Texture = step.trail
			trail.TextureMode = Enum.TextureMode.Wrap
			trail.TextureLength = step.trailRepeat * scale
		end
		trail.Enabled = false
		trail.Parent = host
		table.insert(trails, trail)
	end
	return trails
end

-- The flame on a jetpack model, or nil while its nozzles have not arrived (streaming). `scale`
-- is the jetpack's size against the template's.
local function build(model: Model, looks: JetpackLooks.Looks, scale: number): Effects?
	local exits: { Attachment } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == JetpackConfig.NOZZLE_ATTACHMENT_NAME then
			table.insert(exits, descendant)
		end
	end
	if #exits == 0 then
		return nil
	end
	local step = JetpackLooks.stepOf(looks)
	local nozzles = {}
	for _, exit in exits do
		local jetTail = tail("JetTail", exit)
		local coreTail = tail("CoreTail", exit)
		local jet = beam("Jet", exit, jetTail, step.jet, step.jetScroll)
		jet.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, looks.flameStart),
			ColorSequenceKeypoint.new(0.3, looks.flameEnd),
			ColorSequenceKeypoint.new(1, looks.flameEnd),
		})
		jet.Transparency = JET_TRANSPARENCY
		jet.LightEmission = 0.7
		local core = beam("Core", exit, coreTail, step.core, step.coreScroll)
		core.Color = ColorSequence.new(WHITE, looks.flameStart)
		core.Transparency = CORE_TRANSPARENCY
		core.LightEmission = 1
		table.insert(nozzles, { exit = exit, jet = jet, jetTail = jetTail, core = core, coreTail = coreTail })
	end
	local light = Instance.new("PointLight")
	light.Name = "FlameLight"
	light.Color = looks.lightColor
	light.Range = JetpackConfig.FLAME_LIGHT_RANGE
	light.Shadows = false
	light.Enabled = false
	light.Parent = exits[1]
	return {
		nozzles = nozzles,
		light = light,
		trails = buildTrails(model, exits, looks, step, scale),
		looks = looks,
		stalled = false,
		burstUntil = 0,
	}
end

-- Writes the flame: `power` its share of full length (JetFlame.power), `detail` what of it shows
-- (JetFlame.detail), `scale` the jetpack's size against the template's.
local function write(effects: Effects, burning: boolean, power: number, detail: number, scale: number)
	local looks = effects.looks
	local step = JetpackLooks.stepOf(looks)
	local length = looks.length * power * scale
	local width = looks.width * scale * (0.75 + 0.25 * math.min(power, 1.5))
	local brightness = looks.brightness * (0.55 + 0.45 * math.min(power, 1.5))
	for _, nozzle in effects.nozzles do
		nozzle.jet.Enabled = burning
		nozzle.core.Enabled = burning and detail >= 3
		if not burning then
			continue
		end
		nozzle.jetTail.CFrame = nozzle.exit.CFrame * CFrame.new(0, -length, 0)
		nozzle.coreTail.CFrame = nozzle.exit.CFrame * CFrame.new(0, -length * step.coreLength, 0)
		nozzle.jet.Width0 = width
		nozzle.jet.Width1 = width * 0.3
		nozzle.jet.Brightness = brightness
		nozzle.core.Width0 = width * step.coreWidth
		nozzle.core.Width1 = width * step.coreWidth * 0.4
		nozzle.core.Brightness = brightness * 1.3
	end
	effects.light.Enabled = burning and detail >= 2
	effects.light.Brightness = JetpackConfig.FLAME_LIGHT_BRIGHTNESS
		* (0.5 + 0.5 * math.min(power, 1.5))
		* (looks.brightness / JetpackLooks.LEVELS[1].brightness)
end

-- Writes the trails: on while `flying`, living long enough to be their look's length at
-- `topSpeed` (shorter under reduced motion).
local function writeTrails(effects: Effects, flying: boolean, topSpeed: number, scale: number, reduced: boolean)
	local look = effects.looks.trail
	if not look then
		return
	end
	local length = look.length * scale * (if reduced then JetpackConfig.TRAIL_REDUCED_MOTION else 1)
	local lifetime = JetFlame.trailLifetime(length, topSpeed, JetpackConfig.TRAIL_SHORTEST, JetpackConfig.TRAIL_LONGEST)
	for _, trail in effects.trails do
		trail.Lifetime = lifetime
		trail.Enabled = flying
	end
end

function JetpackEffectsController.new(): JetpackEffectsController
	-- A new jetpack is a new model, so it gets a new flame; an entry goes when its model is
	-- destroyed. Not a weak table: Luau may collect an Instance's wrapper while the Instance lives,
	-- and the entry vanished with it (the flame was rebuilt over and over; Studio, 2026-11-10).
	local effectsByModel: { [Model]: Effects } = {}

	-- Players on their stand this frame, with their flame's scale (cleared every frame).
	local standsLit: { [Player]: number } = {}

	-- The jetpack stands on the islands (docs/design/screens/jetpack-stand.md): the blast grate
	-- glows while its owner trains, the pilot lights burn while the stand is empty.
	local function lightStands()
		for _, bay in CollectionService:GetTagged(BayConfig.TAG) do
			local ownerId = bay:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE)
			local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
			local scale = if owner then standsLit[owner] else nil
			local stand = bay:FindFirstChild(BayConfig.STAND_NAME)
			if not stand then
				continue
			end
			for _, part in stand:GetChildren() do
				if not part:IsA("BasePart") then
					continue
				end
				if part.Name == BayConfig.STAND_GRATE_NAME then
					local heat = if scale then math.min(1, scale / StandConfig.FLAME_MAX_SCALE + 0.35) else 0
					part.Color = BayLooks.STAND_GRATE_COLOR:Lerp(BayLooks.STAND_GRATE_HOT_COLOR, heat)
				elseif part.Name == BayConfig.STAND_PILOT_NAME then
					part.Transparency = if scale then 1 else 0
				end
			end
		end
		table.clear(standsLit)
	end

	local function update()
		local now = os.clock()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local model = character and character:FindFirstChild(JetpackConfig.MODEL_NAME)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local torso = character and character:FindFirstChild("UpperTorso")
			if
				not character
				or not model
				or not model:IsA("Model")
				or not root
				or not root:IsA("BasePart")
				or not torso
				or not torso:IsA("BasePart")
			then
				continue
			end
			local found = effectsByModel[model]
			if not found then
				local jetpack = model:GetAttribute(JetpackConfig.JETPACK_ATTRIBUTE)
				local looks = JetpackLooks.LEVELS[math.clamp(
					if type(jetpack) == "number" then jetpack + 1 else 1,
					1,
					#JetpackLooks.LEVELS
				)]
				local made = build(model, looks, torso.Size.X / JetpackConfig.TEMPLATE_TORSO_WIDTH)
				if not made then
					continue
				end
				-- Also sweep for models that left without Destroying (builds are rare, so it's cheap).
				for other in effectsByModel do
					if not other.Parent then
						effectsByModel[other] = nil
					end
				end
				effectsByModel[model] = made
				model.Destroying:Once(function()
					effectsByModel[model] = nil
				end)
				found = made
			end
			local effects = found :: Effects

			local stunned = character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil
			if effects.stalled and not stunned then
				effects.burstUntil = now + JetpackConfig.FLAME_BURST_SECONDS
			end
			effects.stalled = stunned

			local flying = character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true and not stunned
			-- On the jetpack stand the engine runs full and burns bigger with the trainer's level.
			local onStand = Stand.isTraining(Stand.parse(character:GetAttribute(StandConfig.STATE_ATTRIBUTE)))
			local standScale: number? = nil
			if onStand then
				local trainerLevel = player:GetAttribute(StandConfig.TRAINER_LEVEL_ATTRIBUTE)
				standScale = Stand.flameScale(
					if type(trainerLevel) == "number" then trainerLevel else 0,
					StandConfig.FLAME_MAX_SCALE,
					StandConfig.FLAME_FULL_LEVEL
				)
				standsLit[player] = standScale :: number
			end
			local maxSpeed = TopSpeed.of(character)
			local thrust = if maxSpeed > 0
				then math.clamp(root.AssemblyLinearVelocity.Magnitude / maxSpeed, 0, 1)
				else 0
			-- The strike's lunge fires the engine full blast too.
			local lunge = character:GetAttribute(PvpConfig.STRIKE_LUNGE_ATTRIBUTE)
			local burst = now < effects.burstUntil or (type(lunge) == "number" and lunge > 0)
			local burning = flying or onStand
			local power =
				JetFlame.power({ thrust = thrust, burst = burst, standScale = standScale }, JetpackConfig.FLAME)
			local detail =
				JetFlame.detail((root.Position - eye).Magnitude, JetpackConfig.FLAME_NEAR, JetpackConfig.FLAME_FAR)
			-- Reduced motion drops the secondary layer (the core) first.
			if GuiService.ReducedMotionEnabled then
				detail = math.min(detail, 2)
			end

			local scale = torso.Size.X / JetpackConfig.TEMPLATE_TORSO_WIDTH
			local state = if burning then `{power}|{detail}` else "off"
			if state ~= effects.written then
				effects.written = state
				write(effects, burning, power, detail, scale)
			end
			-- The trail: only in flight, as long as its look at top speed (whole studs a second, so a
			-- small change in speed rewrites nothing).
			local reduced = GuiService.ReducedMotionEnabled
			local trailState = if flying then `{math.floor(maxSpeed)}|{reduced}` else "off"
			if #effects.trails > 0 and trailState ~= effects.trailWritten then
				effects.trailWritten = trailState
				writeTrails(effects, flying, maxSpeed, scale, reduced)
			end
		end
		lightStands()
	end

	local function init()
		-- Registration must happen on every client too: Studio's on-the-fly ids are per process.
		FlightAnimation.resolveId()
	end

	local function start()
		RunService.Heartbeat:Connect(update)
	end

	return {
		name = "JetpackEffectsController",
		init = init,
		start = start,
	}
end

return table.freeze(JetpackEffectsController)
