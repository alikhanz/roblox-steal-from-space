--!strict
-- Client-side jetpack visuals for every character: flames and their glow grow with speed while
-- flying and switch off under the dome; a guardian's hit stalls the engine, which restarts with
-- a burst when the stun ends. On the jetpack stand the engine runs full, bigger with the
-- trainer's level, and the stand's grate glows. Purely cosmetic, so it runs outside the
-- simulation.
-- Also registers the flight pose in Studio so this client can play it (see FlightAnimation).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local FlightAnimation = require(ReplicatedStorage.Shared.Character.FlightAnimation)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local TopSpeed = require(ReplicatedStorage.Shared.Simulation.TopSpeed)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

export type JetpackEffectsController = {
	name: string,
	init: () -> (),
	start: () -> (),
}

type Effects = {
	flames: { ParticleEmitter },
	-- Each flame's own particle speed: the stand stretches it.
	speeds: { NumberRange },
	lights: { PointLight },
	-- True while the character was stunned on the last update; the restart burst follows.
	stalled: boolean,
	burstUntil: number,
}

local JetpackEffectsController = {}

local function collectEffects(model: Model): Effects
	local effects: Effects = { flames = {}, speeds = {}, lights = {}, stalled = false, burstUntil = 0 }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name == JetpackConfig.FLAME_NAME then
			table.insert(effects.flames, descendant)
			table.insert(effects.speeds, descendant.Speed)
		elseif descendant:IsA("PointLight") and descendant.Name == JetpackConfig.FLAME_LIGHT_NAME then
			table.insert(effects.lights, descendant)
		end
	end
	return effects
end

function JetpackEffectsController.new(): JetpackEffectsController
	-- Weak keys: entries vanish together with the jetpack models of removed characters.
	local effectsByModel: { [Model]: Effects } = setmetatable({}, { __mode = "k" }) :: any

	local function effectsFor(model: Model): Effects
		local effects = effectsByModel[model]
		if not effects then
			effects = collectEffects(model)
			effectsByModel[model] = effects
		end
		return effects
	end

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
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local model = character and character:FindFirstChild(JetpackConfig.MODEL_NAME)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not model or not model:IsA("Model") or not root or not root:IsA("BasePart") then
				continue
			end
			local effects = effectsFor(model)

			local stunned = character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil
			if effects.stalled and not stunned then
				effects.burstUntil = now + JetpackConfig.FLAME_BURST_SECONDS
			end
			effects.stalled = stunned

			local flying = character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true and not stunned
			-- On the jetpack stand the engine runs full and burns bigger with the trainer's level.
			local onStand = Stand.isTraining(Stand.parse(character:GetAttribute(StandConfig.STATE_ATTRIBUTE)))
			local trainerLevel = player:GetAttribute(StandConfig.TRAINER_LEVEL_ATTRIBUTE)
			local standScale = if onStand
				then Stand.flameScale(
					if type(trainerLevel) == "number" then trainerLevel else 0,
					StandConfig.FLAME_MAX_SCALE,
					StandConfig.FLAME_FULL_LEVEL
				)
				else 1
			if onStand then
				standsLit[player] = standScale
			end
			local maxSpeed = TopSpeed.of(character)
			local thrust = if onStand
				then 1
				elseif maxSpeed > 0 then math.clamp(root.AssemblyLinearVelocity.Magnitude / maxSpeed, 0, 1)
				else 0
			-- A better jetpack burns harder: its level scales the flame and the glow.
			local level = player:GetAttribute(UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE)
			local looks = JetpackLooks.forLevel(if type(level) == "number" then level else 0)
			-- The strike's lunge fires the engine full blast too.
			local lunge = character:GetAttribute(PvpConfig.STRIKE_LUNGE_ATTRIBUTE)
			local lunging = type(lunge) == "number" and lunge > 0
			local rate = if now < effects.burstUntil or lunging
				then JetpackConfig.FLAME_BURST_RATE
				else JetpackConfig.FLAME_RATE_IDLE
					+ (JetpackConfig.FLAME_RATE_FULL - JetpackConfig.FLAME_RATE_IDLE) * thrust
			local burning = flying or onStand

			for index, flame in effects.flames do
				flame.Enabled = burning
				flame.Rate = rate * looks.flameScale * standScale
				-- A longer flame: the particles fly faster for the same lifetime.
				local speed = effects.speeds[index]
				flame.Speed = NumberRange.new(speed.Min * standScale, speed.Max * standScale)
			end
			for _, light in effects.lights do
				light.Enabled = burning
				light.Brightness = JetpackConfig.FLAME_LIGHT_BRIGHTNESS
					* looks.flameScale
					* standScale
					* (0.5 + 0.5 * thrust)
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
