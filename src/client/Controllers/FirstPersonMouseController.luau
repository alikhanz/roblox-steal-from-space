--!strict
-- Locks the mouse to the middle of the screen and hides the cursor while the camera is zoomed all
-- the way in on a computer (decision 111): first person turns the view with the mouse, and the
-- crosshair in the middle is where the harpoon and the bomb go. Roblox's PlayerModule locks the
-- mouse by itself but leaves the cursor showing in the middle, and players saw it free too; this
-- makes both sure. An open window frees the cursor, so its buttons can be clicked; zooming out
-- frees it too.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RENDER_STEP_NAME = "FirstPersonMouse"
-- Closer than this to what it looks at (its Focus, the character), studs, the camera is in first
-- person: Roblox's own threshold. Fully zoomed in it sits 0.5 away, in any pose (flying, the body
-- lies along the view, so the head is no guide).
local FIRST_PERSON_DISTANCE = 1

export type Dependencies = {
	-- The open window's id, or nil (WindowState.current).
	window: () -> string?,
	-- The welcome-back screen is up (it has buttons but is not a WindowState window).
	welcomeOpen: () -> boolean,
}

export type FirstPersonMouseController = {
	name: string,
	start: () -> (),
}

local FirstPersonMouseController = {}

function FirstPersonMouseController.new(dependencies: Dependencies): FirstPersonMouseController
	local player = Players.LocalPlayer
	-- This changed the mouse or the cursor, and has to give them back when first person ends.
	local changed = false

	local function inFirstPerson(): boolean
		local camera = workspace.CurrentCamera
		if not camera or not player.Character then
			return false
		end
		return (camera.CFrame.Position - camera.Focus.Position).Magnitude < FIRST_PERSON_DISTANCE
	end

	local function set(behavior: Enum.MouseBehavior, iconShown: boolean)
		if UserInputService.MouseBehavior ~= behavior then
			UserInputService.MouseBehavior = behavior
		end
		if UserInputService.MouseIconEnabled ~= iconShown then
			UserInputService.MouseIconEnabled = iconShown
		end
	end

	local function update()
		if UserInputService.MouseEnabled and inFirstPerson() then
			-- Written every frame: in first person Roblox's camera code locks the mouse again each
			-- frame, and this runs after it. A window needs the cursor free to click its buttons.
			local windowUp = dependencies.window() ~= nil or dependencies.welcomeOpen()
			if windowUp then
				set(Enum.MouseBehavior.Default, true)
			else
				set(Enum.MouseBehavior.LockCenter, false)
			end
			changed = true
		elseif changed then
			changed = false
			set(Enum.MouseBehavior.Default, true)
		end
	end

	local function start()
		-- After the camera has moved this frame.
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update)
	end

	return {
		name = "FirstPersonMouseController",
		start = start,
	}
end

return table.freeze(FirstPersonMouseController)
