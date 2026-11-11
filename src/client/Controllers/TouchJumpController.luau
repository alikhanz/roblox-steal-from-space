--!strict
-- Keeps Roblox's touch jump button hidden while the jetpack is on (decision 096). The up button
-- takes its place in the corner (docs/design/screens/hud.md); Roblox hides its button by itself
-- once jumping is off, and the simulation switches jumping off in flight, but if Roblox ever
-- misses that, its button would sit over the up button and take its presses (Prod v1.0.3 on an
-- iPhone). This makes sure: in flight the button is hidden, and after landing it is shown again
-- if this hid it. The simulation also counts a press on it as up, should it slip through.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)

-- Roblox's PlayerModule (TouchJump) puts it at PlayerGui.TouchGui.TouchControlFrame.JumpButton.
local TOUCH_GUI_NAME = "TouchGui"
local JUMP_BUTTON_NAME = "JumpButton"

export type TouchJumpController = {
	name: string,
	start: () -> (),
}

local TouchJumpController = {}

function TouchJumpController.new(): TouchJumpController
	local player = Players.LocalPlayer
	local flying = false
	-- The button this hid, to show again on landing.
	local hidden: GuiObject? = nil
	-- Buttons whose visibility is watched (Roblox may build a new one).
	local watched: { [GuiObject]: boolean } = {}

	local function findButton(): GuiObject?
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		local touchGui = playerGui and playerGui:FindFirstChild(TOUCH_GUI_NAME)
		local button = touchGui and touchGui:FindFirstChild(JUMP_BUTTON_NAME, true)
		return if button and button:IsA("GuiObject") then button else nil
	end

	local function hide(button: GuiObject)
		if flying and button.Visible then
			button.Visible = false
			hidden = button
		end
	end

	local function apply()
		local button = findButton()
		if not button then
			return
		end
		if not watched[button] then
			watched[button] = true
			button:GetPropertyChangedSignal("Visible"):Connect(function()
				hide(button)
			end)
			button.Destroying:Once(function()
				watched[button] = nil
				if hidden == button then
					hidden = nil
				end
			end)
		end
		if flying then
			hide(button)
		elseif hidden == button then
			hidden = nil
			button.Visible = true
		end
	end

	local characterConnection: RBXScriptConnection? = nil
	local function watchCharacter(character: Model)
		if characterConnection then
			characterConnection:Disconnect()
		end
		local function read()
			flying = character:GetAttribute(FlightConfig.JETPACK_ON_ATTRIBUTE) == true
			apply()
		end
		-- Written by the simulation, so it signals on the client.
		characterConnection = character:GetAttributeChangedSignal(FlightConfig.JETPACK_ON_ATTRIBUTE):Connect(read)
		read()
	end

	local function start()
		if not UserInputService.TouchEnabled then
			return
		end
		local playerGui = player:WaitForChild("PlayerGui")
		-- Roblox builds its touch controls lazily and may rebuild them.
		playerGui.DescendantAdded:Connect(function(added)
			if added.Name == JUMP_BUTTON_NAME then
				apply()
			end
		end)
		player.CharacterAdded:Connect(watchCharacter)
		if player.Character then
			watchCharacter(player.Character)
		end
	end

	return {
		name = "TouchJumpController",
		start = start,
	}
end

return table.freeze(TouchJumpController)
