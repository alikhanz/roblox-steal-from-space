--!strict
-- Client-side jetpack visuals for every character: flames and their glow grow with speed while
-- flying and switch off under the dome. Purely cosmetic, so it runs outside the simulation.
-- Also registers the flight pose in Studio so this client can play it (see FlightAnimation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightAnimation = require(ReplicatedStorage.Shared.Character.FlightAnimation)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)

export type JetpackEffectsController = {
	name: string,
	init: () -> (),
	start: () -> (),
}

type Effects = {
	flames: { ParticleEmitter },
	lights: { PointLight },
}

local JetpackEffectsController = {}

local function collectEffects(model: Model): Effects
	local effects: Effects = { flames = {}, lights = {} }
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
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local model = character and character:FindFirstChild(JetpackConfig.MODEL_NAME)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not model or not model:IsA("Model") or not root or not root:IsA("BasePart") then
				continue
			end

			local flying = character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
			local thrust = math.clamp(root.AssemblyLinearVelocity.Magnitude / FlightConfig.TUNING.maxSpeed, 0, 1)
			local rate = JetpackConfig.FLAME_RATE_IDLE
				+ (JetpackConfig.FLAME_RATE_FULL - JetpackConfig.FLAME_RATE_IDLE) * thrust

			local effects = effectsFor(model)
			for _, flame in effects.flames do
				flame.Enabled = flying
				flame.Rate = rate
			end
			for _, light in effects.lights do
				light.Enabled = flying
				light.Brightness = JetpackConfig.FLAME_LIGHT_BRIGHTNESS * (0.5 + 0.5 * thrust)
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
