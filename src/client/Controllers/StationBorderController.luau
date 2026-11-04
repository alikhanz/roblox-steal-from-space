--!strict
-- The station border in the solar storm: while flight is held within it (the workspace range
-- limit the storm sets), every client turns the border red, thickens its shell and widens its
-- ring, so it is plain that nobody gets past; after the storm it fades back (BorderLooks). A
-- sphere's shell does not show from inside, so a player flying at the border also sees a wall of
-- the force field grow solid on it, right where they are heading.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BorderLooks = require(ReplicatedStorage.Shared.Config.BorderLooks)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

export type StationBorderController = {
	name: string,
	start: () -> (),
}

local StationBorderController = {}

local function isStorm(): boolean
	return workspace:GetAttribute(FlightConfig.RANGE_LIMIT_ATTRIBUTE) ~= nil
end

function StationBorderController.new(): StationBorderController
	-- Each ring segment's calm size, to widen it from and back to.
	local calmSizes: { [BasePart]: Vector3 } = {}

	local function look(part: BasePart, storm: boolean, seconds: number)
		local goal: { [string]: any } = { Color = if storm then BorderLooks.STORM_COLOR else BorderLooks.COLOR }
		if part.Name == BorderLooks.SHELL_NAME then
			goal.Transparency = if storm then BorderLooks.STORM_SHELL_TRANSPARENCY else BorderLooks.SHELL_TRANSPARENCY
		else
			local calm = calmSizes[part]
			if not calm then
				calm = part.Size
				calmSizes[part] = calm
			end
			local scale = if storm then BorderLooks.STORM_RING_SCALE else 1
			-- Thicker across, the same length along the ring.
			goal.Size = Vector3.new(calm.X * scale, calm.Y * scale, calm.Z)
		end
		if seconds > 0 then
			TweenService:Create(part, TweenInfo.new(seconds), goal):Play()
		else
			for property, value in goal do
				(part :: any)[property] = value
			end
		end
	end

	local function lookAll(storm: boolean, seconds: number)
		for _, folder in CollectionService:GetTagged(BorderLooks.TAG) do
			for _, part in folder:GetChildren() do
				if part:IsA("BasePart") then
					look(part, storm, seconds)
				end
			end
		end
	end

	local function watch(folder: Instance)
		-- Parts that stream in later take the current look at once.
		folder.ChildAdded:Connect(function(part)
			if part:IsA("BasePart") then
				look(part, isStorm(), 0)
			end
		end)
		folder.ChildRemoved:Connect(function(part)
			if part:IsA("BasePart") then
				calmSizes[part] = nil
			end
		end)
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				look(part, isStorm(), 0)
			end
		end
	end

	-- The wall ahead: a disc on the border where the player would cross it, growing solid as
	-- they come close. Only this client sees its own wall.
	local wall = Instance.new("Part")
	wall.Name = "StormWall"
	wall.Shape = Enum.PartType.Cylinder
	wall.Size = Vector3.new(BorderLooks.WALL_THICKNESS, BorderLooks.WALL_DIAMETER, BorderLooks.WALL_DIAMETER)
	wall.Material = Enum.Material.ForceField
	wall.Color = BorderLooks.STORM_COLOR
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false

	local function placeWall()
		local limit = workspace:GetAttribute(FlightConfig.RANGE_LIMIT_ATTRIBUTE)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if type(limit) ~= "number" or not root or not root:IsA("BasePart") then
			wall.Parent = nil
			return
		end
		local center = StationConfig.STATION.domeCenter
		local offset = root.Position - center
		local fromEdge = limit - offset.Magnitude
		if fromEdge > BorderLooks.WALL_SHOW_DISTANCE or offset.Magnitude < 1 then
			wall.Parent = nil
			return
		end
		local outward = offset.Unit
		local closeness = 1 - math.clamp(fromEdge / BorderLooks.WALL_SHOW_DISTANCE, 0, 1)
		wall.Transparency = 1 - (1 - BorderLooks.WALL_MIN_TRANSPARENCY) * closeness
		-- A cylinder's axis is its X: turn it along the way out, so the disc lies on the border.
		local point = center + outward * limit
		wall.CFrame = CFrame.lookAt(point, point + outward) * CFrame.Angles(0, math.rad(90), 0)
		wall.Parent = workspace
	end

	local function start()
		for _, folder in CollectionService:GetTagged(BorderLooks.TAG) do
			watch(folder)
		end
		RunService.RenderStepped:Connect(placeWall)
		CollectionService:GetInstanceAddedSignal(BorderLooks.TAG):Connect(watch)
		workspace:GetAttributeChangedSignal(FlightConfig.RANGE_LIMIT_ATTRIBUTE):Connect(function()
			lookAll(isStorm(), BorderLooks.FADE_SECONDS)
		end)
	end

	return {
		name = "StationBorderController",
		start = start,
	}
end

return table.freeze(StationBorderController)
