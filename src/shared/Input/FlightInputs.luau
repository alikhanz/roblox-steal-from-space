--!strict
-- Input Action System setup for flight. The server creates one context per player under the
-- Player instance (Server Authority sends only these inputs to the server); the simulation
-- polls them with GetState() on both sides.

local FlightInputs = {}

FlightInputs.CONTEXT_NAME = "FlightContext"
FlightInputs.ASCEND = "Ascend"
FlightInputs.DESCEND = "Descend"
-- Hold next to an egg to grab it.
FlightInputs.GRAB = "Grab"
-- The attacks (PvP); the server reads the presses like any other input.
FlightInputs.STRIKE = "Strike"
FlightInputs.HARPOON = "Harpoon"
FlightInputs.BOMB = "Bomb"
-- The defense.
FlightInputs.SHIELD = "Shield"
-- Each press switches slow mode on or off (TopSpeed).
FlightInputs.SLOW_MODE = "SlowMode"
-- Where the camera looks. Fed by the client through a Scriptable binding; untrusted on the server.
FlightInputs.AIM = "Aim"
FlightInputs.AIM_BINDING = "Camera"
-- Name of the client-side bindings that link the on-screen buttons on touch devices.
FlightInputs.TOUCH_BINDING = "TouchButton"

local CONTEXT_PRIORITY = 1000

local function keyAction(name: string, keyCodes: { Enum.KeyCode }): InputAction
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

local function aimAction(): InputAction
	local action = Instance.new("InputAction")
	action.Name = FlightInputs.AIM
	action.Type = Enum.InputActionType.Direction3D
	local binding = Instance.new("InputBinding")
	binding.Name = FlightInputs.AIM_BINDING
	binding.Type = Enum.InputBindingType.Scriptable
	binding.Parent = action
	return action
end

-- Server only: builds the context to parent under a Player.
function FlightInputs.create(): InputContext
	local context = Instance.new("InputContext")
	context.Name = FlightInputs.CONTEXT_NAME
	context.Priority = CONTEXT_PRIORITY
	context.Sink = false
	context.Enabled = true
	keyAction(FlightInputs.ASCEND, { Enum.KeyCode.Space, Enum.KeyCode.ButtonR1 }).Parent = context
	keyAction(FlightInputs.DESCEND, { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL1 }).Parent = context
	keyAction(FlightInputs.GRAB, { Enum.KeyCode.E, Enum.KeyCode.ButtonX }).Parent = context
	keyAction(FlightInputs.STRIKE, { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonR2 }).Parent = context
	keyAction(FlightInputs.HARPOON, { Enum.KeyCode.F, Enum.KeyCode.ButtonY }).Parent = context
	keyAction(FlightInputs.BOMB, { Enum.KeyCode.G, Enum.KeyCode.ButtonB }).Parent = context
	keyAction(FlightInputs.SHIELD, { Enum.KeyCode.R, Enum.KeyCode.ButtonL2 }).Parent = context
	keyAction(FlightInputs.SLOW_MODE, { Enum.KeyCode.Q, Enum.KeyCode.ButtonL3 }).Parent = context
	aimAction().Parent = context
	return context
end

function FlightInputs.findAction(context: Instance, name: string): InputAction?
	local action = context:FindFirstChild(name)
	return if action and action:IsA("InputAction") then action else nil
end

-- The key bound to a Bool action for the given input: a gamepad button for a gamepad, any
-- other key otherwise. Nil when the action or its binding is missing. The hint in the HUD
-- reads this, so it never disagrees with what the key actually does.
function FlightInputs.boundKey(context: Instance, name: string, input: Enum.PreferredInput): Enum.KeyCode?
	local action = FlightInputs.findAction(context, name)
	if not action then
		return nil
	end
	for _, binding in action:GetChildren() do
		if binding:IsA("InputBinding") then
			local isGamepad = string.sub(binding.KeyCode.Name, 1, 6) == "Button"
			if isGamepad == (input == Enum.PreferredInput.Gamepad) then
				return binding.KeyCode
			end
		end
	end
	return nil
end

-- A Bool action's state; false when the action is missing (e.g. not replicated yet).
function FlightInputs.isPressed(context: Instance, name: string): boolean
	local action = FlightInputs.findAction(context, name)
	return action ~= nil and action:GetState() == true
end

-- The raw aim the client reported, or nil. Sanitize before use: it comes from the client.
function FlightInputs.readAim(context: Instance): Vector3?
	local action = FlightInputs.findAction(context, FlightInputs.AIM)
	if not action then
		return nil
	end
	local state = action:GetState()
	return if typeof(state) == "Vector3" then state else nil
end

return table.freeze(FlightInputs)
