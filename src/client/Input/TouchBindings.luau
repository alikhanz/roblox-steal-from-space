--!strict
-- Links on-screen buttons to flight input actions with local-only UIButton bindings, so pressing
-- the button drives the same action the keyboard does (and reaches the server as input).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)

local CONTEXT_WAIT_TIMEOUT = 30

local TouchBindings = {}

-- Yields until the player's input context exists (it is created by the server).
function TouchBindings.bind(player: Player, actionName: string, button: GuiButton)
	local context = player:WaitForChild(FlightInputs.CONTEXT_NAME, CONTEXT_WAIT_TIMEOUT)
	local inputAction = context and FlightInputs.findAction(context, actionName)
	if not inputAction then
		warn(`[TouchBindings] Input action {actionName} not found; button {button.Name} stays unbound`)
		return
	end
	local binding = Instance.new("InputBinding")
	binding.Name = FlightInputs.TOUCH_BINDING
	binding.UIButton = button
	binding.Parent = inputAction
	-- The button may be rebuilt (e.g. a new HUD); drop the binding with it.
	button.Destroying:Once(function()
		binding:Destroy()
	end)
end

return table.freeze(TouchBindings)
