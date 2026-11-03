--!strict
-- Shakes the camera while a guardian's hit stuns the local player. Cosmetic: runs after the
-- camera has been placed and only nudges it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)

local RENDER_STEP_NAME = "HitShake"
-- Largest nudge at the start of the stun, studs; it fades to nothing by the end.
local SHAKE_AMPLITUDE = 0.6

export type HitEffectsController = {
	name: string,
	start: () -> (),
}

local HitEffectsController = {}

function HitEffectsController.new(): HitEffectsController
	local random = Random.new()
	local stunStartedAt: number? = nil

	local function shake()
		local character = Players.LocalPlayer.Character
		local camera = workspace.CurrentCamera
		local stunned = character ~= nil and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil
		if not stunned or not camera then
			stunStartedAt = nil
			return
		end
		local startedAt = stunStartedAt or os.clock()
		stunStartedAt = startedAt
		local remaining = 1 - math.clamp((os.clock() - startedAt) / GuardianConfig.STUN_SECONDS, 0, 1)
		local amplitude = SHAKE_AMPLITUDE * remaining
		camera.CFrame = camera.CFrame
			* CFrame.new(random:NextNumber(-amplitude, amplitude), random:NextNumber(-amplitude, amplitude), 0)
	end

	local function start()
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, shake)
	end

	return {
		name = "HitEffectsController",
		start = start,
	}
end

return table.freeze(HitEffectsController)
