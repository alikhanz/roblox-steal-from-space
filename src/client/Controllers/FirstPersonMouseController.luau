--!strict
-- Locks the mouse to the middle of the screen and hides the cursor while the camera is zoomed all
-- the way in on a computer (decision 111): first person turns the view with the mouse, and the
-- crosshair in the middle is where the harpoon and the bomb go. Roblox's PlayerModule does this
-- by itself only when its camera counts as first person, and with our character it never does
-- (fully zoomed in, the camera stays about 1.3 studs from the head and the cursor stays free).
-- An open window frees the cursor, so its buttons can be clicked; zooming out frees it too.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RENDER_STEP_NAME = "FirstPersonMouse"
-- Closer than this to the head, studs, the camera is in first person. Fully zoomed in it sits
-- about 1.3 studs away; the nearest third-person zoom keeps it several studs back.
local FIRST_PERSON_DISTANCE = 2

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
	-- This locked the mouse and hid the cursor, and has to give them back.
	local locked = false

	local function inFirstPerson(): boolean
		local camera = workspace.CurrentCamera
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not camera or not head or not head:IsA("BasePart") then
			return false
		end
		return (camera.CFrame.Position - head.Position).Magnitude < FIRST_PERSON_DISTANCE
	end

	local function update()
		local lock = UserInputService.MouseEnabled
			and inFirstPerson()
			and dependencies.window() == nil
			and not dependencies.welcomeOpen()
		if lock then
			-- Written every frame while locked: Roblox's own camera code restores the behaviour
			-- it saved when it last overrode it, and this must win.
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
			if UserInputService.MouseIconEnabled then
				UserInputService.MouseIconEnabled = false
			end
			locked = true
		elseif locked then
			locked = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
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
