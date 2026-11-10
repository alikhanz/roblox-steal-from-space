--!strict
-- Client-side jetpack visuals for every character (decision 086): a jet of beams from each nozzle
-- — a white-hot core inside a jet in the jetpack's colour, its texture scrolling — and one light
-- per jetpack. The flame grows with speed while flying and goes out under the dome; a guardian's
-- hit stalls the engine, which restarts with a burst; the strike's lunge fires it full. On the
-- jetpack stand the engine runs full, bigger with the trainer's level, and the stand's grate glows.
-- Purely cosmetic, so it runs outside the simulation and never crosses the network: the server
-- sends the bare jetpack with its nozzle attachments, each client adds the flame itself.
-- Light on resources: the beams are made once per jetpack and rewritten only when the flame's
-- state changes (JetFlame steps); far from the camera the core and then the light go.
-- Also registers the flight pose in Studio so this client can play it (see FlightAnimation).

local CollectionService = game:GetService("CollectionService")
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
	looks: JetpackLooks.Looks,
	-- The flame's state last written (burning, power, detail); nil before the first.
	written: string?,
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

-- The flame on a jetpack model, or nil while its nozzles have not arrived (streaming).
local function build(model: Model, looks: JetpackLooks.Looks): Effects?
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
	return { nozzles = nozzles, light = light, looks = looks, stalled = false, burstUntil = 0 }
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

function JetpackEffectsController.new(): JetpackEffectsController
	-- Weak keys: entries vanish together with the jetpack models of removed characters (a new
	-- jetpack is a new model, so it gets a new flame).
	local effectsByModel: { [Model]: Effects } = setmetatable({}, { __mode = "k" }) :: any

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
				local made = build(model, looks)
				if not made then
					continue
				end
				effectsByModel[model] = made
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

			local state = if burning then `{power}|{detail}` else "off"
			if state ~= effects.written then
				effects.written = state
				write(effects, burning, power, detail, torso.Size.X / JetpackConfig.TEMPLATE_TORSO_WIDTH)
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
