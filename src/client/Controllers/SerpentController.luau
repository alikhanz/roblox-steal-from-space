--!strict
-- Draws the star serpent's body: while its head (SerpentService, a persistent model in
-- workspace.World) is out, segments follow the path it flies (Domain/SerpentBody). Client-only
-- parts, moved every frame: smooth on every screen without the server sending each segment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SerpentBody = require(ReplicatedStorage.Shared.Domain.SerpentBody)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentLooks = require(ReplicatedStorage.Shared.Config.SerpentLooks)

local WORLD_WAIT_TIMEOUT = 30
-- A path point is kept every this many studs: fine enough for smooth turns.
local TRAIL_STEP = 1.5

export type SerpentController = {
	name: string,
	start: () -> (),
}

local SerpentController = {}

local function buildSegments(parent: Instance): { BasePart }
	local looks = SerpentLooks.BODY
	local parts: { BasePart } = {}
	for index = 1, looks.segments do
		local share = if looks.segments > 1 then (index - 1) / (looks.segments - 1) else 0
		local size = looks.firstSize + (looks.lastSize - looks.firstSize) * share
		local star = index % looks.starEvery == 0
		local part = Instance.new("Part")
		part.Name = `Segment{index}`
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * size
		part.Color = if star then looks.starColor else looks.colors[(index - 1) % #looks.colors + 1]
		part.Material = if star then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = parent
		table.insert(parts, part)
	end
	return parts
end

function SerpentController.new(): SerpentController
	local function start()
		local world = workspace:WaitForChild("World", WORLD_WAIT_TIMEOUT)
		if not world then
			warn("[SerpentController] No world folder; no serpent body")
			return
		end
		local looks = SerpentLooks.BODY
		local length = looks.segments * looks.spacing

		-- The body of the serpent that is out now.
		local head: BasePart? = nil
		local body: Folder? = nil
		local segments: { BasePart } = {}
		local trail: { Vector3 } = {}

		local function clear()
			if body then
				body:Destroy()
			end
			head, body, segments, trail = nil, nil, {}, {}
		end

		local function follow(model: Instance)
			local part = model:WaitForChild(SerpentConfig.HEAD_NAME, WORLD_WAIT_TIMEOUT)
			if not part or not part:IsA("BasePart") or model.Parent == nil then
				return
			end
			clear()
			local folder = Instance.new("Folder")
			folder.Name = "SerpentBody"
			folder.Parent = workspace
			head, body, segments = part, folder, buildSegments(folder)
		end

		world.ChildAdded:Connect(function(child)
			if child.Name == SerpentConfig.MODEL_NAME then
				follow(child)
			end
		end)
		world.ChildRemoved:Connect(function(child)
			if child.Name == SerpentConfig.MODEL_NAME then
				clear()
			end
		end)
		local present = world:FindFirstChild(SerpentConfig.MODEL_NAME)
		if present then
			task.spawn(follow, present)
		end

		RunService.RenderStepped:Connect(function()
			local current = head
			if not current or #segments == 0 then
				return
			end
			-- The neck joins the back of the head, not its middle.
			local neck = current.Position - current.CFrame.LookVector * (current.Size.Z / 2)
			SerpentBody.record(trail, neck, TRAIL_STEP, length)
			local points = SerpentBody.place(neck, trail, looks.spacing, #segments)
			local frames: { CFrame } = {}
			for index, point in points do
				frames[index] = CFrame.new(point)
			end
			workspace:BulkMoveTo(segments, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end

	return {
		name = "SerpentController",
		start = start,
	}
end

return table.freeze(SerpentController)
