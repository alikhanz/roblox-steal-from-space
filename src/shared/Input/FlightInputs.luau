--!strict
-- Input Action System setup for flight. The server creates one context per player under the
-- Player instance (required by Server Authority); the simulation reads it on both sides.

local FlightInputs = {}

FlightInputs.CONTEXT_NAME = "FlightContext"
FlightInputs.ASCEND = "Ascend"
FlightInputs.DESCEND = "Descend"
FlightInputs.TOGGLE = "ToggleJetpack"

local CONTEXT_PRIORITY = 1000

local function boolAction(name: string, keyCodes: { Enum.KeyCode }): InputAction
	local action = Instance.new("InputAction")
	action.Name = name
	action.Type = Enum.InputActionType.Bool
	for _, keyCode in keyCodes do
		local binding = Instance.new("InputBinding")
		binding.Name = keyCode.Name
		binding.KeyCode = keyCode
		binding.Parent = action
	end
	return action
end

function FlightInputs.create(): InputContext
	local context = Instance.new("InputContext")
	context.Name = FlightInputs.CONTEXT_NAME
	context.Priority = CONTEXT_PRIORITY
	context.Enabled = true
	boolAction(FlightInputs.ASCEND, { Enum.KeyCode.E, Enum.KeyCode.ButtonR1 }).Parent = context
	boolAction(FlightInputs.DESCEND, { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 }).Parent = context
	boolAction(FlightInputs.TOGGLE, { Enum.KeyCode.F, Enum.KeyCode.ButtonY }).Parent = context
	return context
end

-- Reads a Bool action's state; false when the action is missing (e.g. not replicated yet).
function FlightInputs.isPressed(context: Instance, name: string): boolean
	local action = context:FindFirstChild(name)
	if action and action:IsA("InputAction") then
		return action:GetState() == true
	end
	return false
end

return table.freeze(FlightInputs)
