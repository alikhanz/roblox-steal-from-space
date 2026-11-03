--!strict
-- Client-side jetpack visuals for every character: flames and their glow grow with speed while
-- flying and switch off under the dome; a guardian's hit stalls the engine, which restarts with
-- a burst when the stun ends. Purely cosmetic, so it runs outside the simulation.
-- Also registers the flight pose in Studio so this client can play it (see FlightAnimation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightAnimation = require(ReplicatedStorage.Shared.Character.FlightAnimation)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

export type JetpackEffectsController = {
	name: string,
	init: () -> (),
	start: () -> (),
}

type Effects = {
	flames: { ParticleEmitter },
	lights: { PointLight },
	-- True while the character was stunned on the last update; the restart burst follows.
	stalled: boolean,
	burstUntil: number,
}

local JetpackEffectsController = {}

local function collectEffects(model: Model): Effects
	local effects: Effects = { flames = {}, lights = {}, stalled = false, burstUntil = 0 }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name == JetpackConfig.FLAME_NAME then
			table.insert(effects.flames, descendant)
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
			local maxSpeed = character:GetAttribute(SpeedConfig.FLIGHT_SPEED_ATTRIBUTE)
			local thrust = if type(maxSpeed) == "number" and maxSpeed > 0
				then math.clamp(root.AssemblyLinearVelocity.Magnitude / maxSpeed, 0, 1)
				else 0
			-- A better jetpack burns harder: its level scales the flame and the glow.
			local level = player:GetAttribute(UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE)
			local looks = JetpackLooks.forLevel(if type(level) == "number" then level else 0)
			local rate = if now < effects.burstUntil
				then JetpackConfig.FLAME_BURST_RATE
				else JetpackConfig.FLAME_RATE_IDLE
					+ (JetpackConfig.FLAME_RATE_FULL - JetpackConfig.FLAME_RATE_IDLE) * thrust

			for _, flame in effects.flames do
				flame.Enabled = flying
				flame.Rate = rate * looks.flameScale
			end
			for _, light in effects.lights do
				light.Enabled = flying
				light.Brightness = JetpackConfig.FLAME_LIGHT_BRIGHTNESS * looks.flameScale * (0.5 + 0.5 * thrust)
			end
		end
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
