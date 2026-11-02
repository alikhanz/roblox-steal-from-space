--!strict
-- Reports where the camera looks to the flight simulation through the Scriptable aim binding.
-- The server treats the value as untrusted input (see Flight.sanitizeAim).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)

local RENDER_STEP_NAME = "FlightAim"

export type AimController = {
	name: string,
	start: () -> (),
}

local AimController = {}

local function findAimBinding(player: Player): InputBinding?
	local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
	local action = context and FlightInputs.findAction(context, FlightInputs.AIM)
	local binding = action and action:FindFirstChild(FlightInputs.AIM_BINDING)
	return if binding and binding:IsA("InputBinding") then binding else nil
end

function AimController.new(): AimController
	local function start()
		local player = Players.LocalPlayer
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Input.Value, function()
			local camera = workspace.CurrentCamera
			local binding = findAimBinding(player)
			if camera and binding then
				-- Identical states are deduplicated by the input system, so this is cheap.
				binding:Fire(camera.CFrame.LookVector)
			end
		end)
	end

	return {
		name = "AimController",
		start = start,
	}
end

return table.freeze(AimController)
