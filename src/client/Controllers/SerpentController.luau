--!strict
-- The star serpent on the client (decision 055).
--   * Its body: while its head (SerpentService, a persistent model in workspace.World) is out,
--     segments follow the path it flies (Domain/SerpentBody). Client-only parts, moved every
--     frame: smooth on every screen without the server sending each segment.
--   * Its hunt for the star egg, told through the event (EventController): the pin reads the
--     hits landed while the egg is inside ("Star Serpent 2/3"), then "Star egg" once it is out
--     (the server moves the pin to the egg); announcements as the egg is knocked out, comes
--     back, is delivered, and as the hunt ends. Read from the event's folder attributes
--     (SerpentConfig.EGG_ATTRIBUTE and the rest).
--   * A white flash on its head as a hit lands (SerpentConfig.LAST_HIT_ATTRIBUTE).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventController = require(script.Parent.EventController)
local SerpentBody = require(ReplicatedStorage.Shared.Domain.SerpentBody)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentLooks = require(ReplicatedStorage.Shared.Config.SerpentLooks)
local Text = require(ReplicatedStorage.Shared.Locale.Text)

local WORLD_WAIT_TIMEOUT = 30
-- A path point is kept every this many studs: fine enough for smooth turns.
local TRAIL_STEP = 1.5

export type Dependencies = {
	events: EventController.EventController,
}

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

-- A white flash over the head and the body as a hit lands.
local function flash(head: BasePart, body: Instance?)
	local looks = SerpentLooks.HIT_FLASH
	local highlight = Instance.new("Highlight")
	highlight.FillColor = looks.color
	highlight.OutlineColor = looks.color
	highlight.FillTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = head.Parent
	highlight.Parent = head
	local bodyHighlight = if body then highlight:Clone() else nil
	if body and bodyHighlight then
		bodyHighlight.Adornee = body
		bodyHighlight.Parent = body
	end
	local info = TweenInfo.new(looks.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, item in { highlight, bodyHighlight } do
		if item then
			TweenService:Create(item, info, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			task.delay(looks.seconds, function()
				item:Destroy()
			end)
		end
	end
end

function SerpentController.new(dependencies: Dependencies): SerpentController
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	-- The hunt as the event's folder tells it.
	local function narrate(folder: Instance)
		local events = dependencies.events
		local function read(name: string): unknown
			return folder:GetAttribute(name)
		end
		local function byName(): string
			local by = read(SerpentConfig.EGG_BY_ATTRIBUTE)
			return if type(by) == "string" then by else "?"
		end

		local function retitle()
			local active = read(EventConfig.PHASE_ATTRIBUTE) == "Active"
			local egg = read(SerpentConfig.EGG_ATTRIBUTE)
			local hits = read(SerpentConfig.HITS_ATTRIBUTE)
			if not active then
				events.setPinTitle("Serpent", nil)
			elseif egg == "Out" then
				events.setPinTitle("Serpent", text("serpent.egg.title"))
			else
				events.setPinTitle(
					"Serpent",
					text("serpent.hits.title", {
						hits = if type(hits) == "number" then hits else 0,
						total = SerpentConfig.HITS_TO_DROP,
					})
				)
			end
		end

		-- Only changes from now on are news: a player who joins mid-hunt just sees the pin.
		local lastEgg = read(SerpentConfig.EGG_ATTRIBUTE)
		folder:GetAttributeChangedSignal(SerpentConfig.EGG_ATTRIBUTE):Connect(function()
			local egg = read(SerpentConfig.EGG_ATTRIBUTE)
			if egg == "Out" and lastEgg == "Inside" then
				events.say("Serpent", text("serpent.knocked.announce", { name = byName() }))
			elseif egg == "Inside" and lastEgg == "Out" then
				events.say("Serpent", text("serpent.returned.announce"))
			elseif egg == "Delivered" and lastEgg ~= "Delivered" then
				events.say("Serpent", text("serpent.delivered.announce", { name = byName() }))
			end
			lastEgg = egg
			retitle()
		end)
		folder:GetAttributeChangedSignal(SerpentConfig.ENDING_ATTRIBUTE):Connect(function()
			local ending = read(SerpentConfig.ENDING_ATTRIBUTE)
			if ending == "TookEgg" then
				events.say("Serpent", text("serpent.escaped.announce"))
			elseif ending == "EggLeft" then
				events.say("Serpent", text("serpent.eggLeft.announce"))
			elseif ending == "EggKept" then
				events.say("Serpent", text("serpent.eggKept.announce"))
			end
		end)
		folder:GetAttributeChangedSignal(SerpentConfig.HITS_ATTRIBUTE):Connect(retitle)
		folder:GetAttributeChangedSignal(EventConfig.PHASE_ATTRIBUTE):Connect(retitle)
		retitle()
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		local events = ReplicatedStorage:WaitForChild(EventConfig.FOLDER_NAME, WORLD_WAIT_TIMEOUT)
		local folder = events and events:WaitForChild("Serpent", WORLD_WAIT_TIMEOUT)
		if folder then
			narrate(folder)
		else
			warn("[SerpentController] No serpent event state; no hunt news")
		end

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
		local hitConnection: RBXScriptConnection? = nil

		local function clear()
			if hitConnection then
				hitConnection:Disconnect()
			end
			if body then
				body:Destroy()
			end
			head, body, segments, trail, hitConnection = nil, nil, {}, {}, nil
		end

		local function follow(model: Instance)
			local part = model:WaitForChild(SerpentConfig.HEAD_NAME, WORLD_WAIT_TIMEOUT)
			if not part or not part:IsA("BasePart") or model.Parent == nil then
				return
			end
			clear()
			local bodyFolder = Instance.new("Folder")
			bodyFolder.Name = "SerpentBody"
			bodyFolder.Parent = workspace
			head, body, segments = part, bodyFolder, buildSegments(bodyFolder)
			hitConnection = part:GetAttributeChangedSignal(SerpentConfig.LAST_HIT_ATTRIBUTE):Connect(function()
				flash(part, body)
			end)
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
