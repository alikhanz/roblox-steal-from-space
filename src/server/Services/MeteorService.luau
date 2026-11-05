--!strict
-- The meteor shower's gameplay, on its event's clock (EventService): as it is announced, a
-- direction from the station is picked; while it lasts, meteors fall along that strip, through
-- every zone in turn. Each meteor leaves a crater, a nest of its own with one meteor egg and a
-- guardian of the nearest nest's post (NestService.addCrater, GuardianService), so stealing it is
-- the same deal as stealing from that nest. Players see a pin per zone (EventService spots), from
-- the start of the shower: to where its meteors are going to fall and to its craters that still
-- hold their eggs. When the shower ends the craters are retired: each
-- goes as soon as its egg is back in it (at once if nobody took it); an egg on its way to a
-- station keeps its crater and guardian until it is delivered or comes back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EventClock = require(ReplicatedStorage.Shared.Domain.EventClock)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventService = require(script.Parent.EventService)
local MeteorConfig = require(ReplicatedStorage.Shared.Config.MeteorConfig)
local MeteorLooks = require(ReplicatedStorage.Shared.Config.MeteorLooks)
local MeteorShower = require(ReplicatedStorage.Shared.Domain.MeteorShower)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local WorldService = require(script.Parent.WorldService)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local EVENT = EventConfig.EVENTS.Meteor
local FOLDER_NAME = "Meteors"
-- How far a meteor may come in from the vertical, as a share of its height.
local MAX_SLANT = 0.5

export type Dependencies = {
	eventChanged: Signal.Signal<EventConfig.EventId, EventClock.Phase>,
	placeOf: (id: EventConfig.EventId) -> EventService.Place?,
	setPlacer: (id: EventConfig.EventId, placer: EventService.Placer) -> (),
	-- Marks for players: each crater whose egg is in it (EventService spots).
	showSpot: (id: EventConfig.EventId, key: string, zone: ZoneConfig.ZoneId, position: Vector3) -> (),
	hideSpot: (id: EventConfig.EventId, key: string) -> (),
	-- Every nest, craters included: a new crater keeps its distance from them.
	getNestSites: () -> { WorldService.NestSite },
	buildCrater: (name: string, zone: ZoneConfig.ZoneId, center: Vector3) -> WorldService.NestSite?,
	addCrater: (site: WorldService.NestSite, variant: AlienConfig.VariantId) -> boolean,
	retireCrater: (nestId: string) -> (),
	-- Players on the server who are not away (ActivityService): idle ones bring no meteors.
	activePlayers: () -> number,
}

export type MeteorService = {
	name: string,
	start: () -> (),
}

local MeteorService = {}

local CENTER = StationConfig.PLATFORM_CENTER

-- The strip's direction from the station, level with it.
local function directionOf(position: Vector3): Vector3
	local flat = Vector3.new(position.X - CENTER.X, 0, position.Z - CENTER.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
end

function MeteorService.new(dependencies: Dependencies): MeteorService
	local random = Random.new()
	-- Counts showers: meteors planned for a shower that has ended do not fall.
	local shower = 0
	local craterCount = 0
	-- This shower's craters, to retire when it ends.
	local craters: { string } = {}
	-- Where this shower's meteors that have not landed yet will land, by the name of their
	-- crater-to-be: taken, like the craters, and marked for players from the start.
	local landing: { [string]: Vector3 } = {}
	local folder: Folder? = nil

	-- The strip: a random direction; the mark is in the middle of the first zone along it.
	local function pickPlace(): EventService.Place?
		local angle = random:NextNumber() * math.pi * 2
		local first = ZoneConfig.ZONES[ZoneConfig.ZONE_ORDER[1]]
		local distance = (first.ringMin + first.ringMax) / 2
		return { position = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance }
	end

	local function isFree(point: Vector3): boolean
		for _, site in dependencies.getNestSites() do
			if (site.eggCFrame.Position - point).Magnitude < MeteorConfig.MIN_SPACING then
				return false
			end
		end
		for _, taken in landing do
			if (taken - point).Magnitude < MeteorConfig.MIN_SPACING then
				return false
			end
		end
		return true
	end

	-- A free spot on the strip within `zone`'s ring, at a nest's height range; nil if none found.
	local function spotIn(zone: ZoneConfig.ZoneId, direction: Vector3): Vector3?
		local ring = ZoneConfig.ZONES[zone]
		local across = direction:Cross(Vector3.yAxis)
		for _ = 1, MeteorConfig.PLACE_ATTEMPTS do
			local point = CENTER
				+ direction * random:NextNumber(ring.ringMin, ring.ringMax)
				+ across * random:NextNumber(-MeteorConfig.STRIP_HALF_WIDTH, MeteorConfig.STRIP_HALF_WIDTH)
				+ Vector3.yAxis * random:NextNumber(-ring.heightSpread, ring.heightSpread)
			if isFree(point) then
				return point
			end
		end
		return nil
	end

	-- A burning streak falling onto `target`; `landed` runs when it gets there.
	local function fall(target: Vector3, landed: () -> ())
		local looks = MeteorLooks.STREAK
		local slant = Vector3.new(random:NextNumber(-MAX_SLANT, MAX_SLANT), 1, random:NextNumber(-MAX_SLANT, MAX_SLANT))
		local start = CFrame.lookAt(target + slant.Unit * looks.height, target)

		local meteor = Instance.new("Part")
		meteor.Name = "Meteor"
		meteor.Shape = Enum.PartType.Ball
		meteor.Size = Vector3.one * looks.width
		meteor.Color = looks.color
		meteor.Material = Enum.Material.Neon
		meteor.Anchored = true
		meteor.CanCollide = false
		meteor.CanTouch = false
		meteor.CanQuery = false
		meteor.CastShadow = false
		meteor.CFrame = start
		-- The tail: a trail between two points across the meteor's path.
		local left = Instance.new("Attachment")
		left.Position = Vector3.new(-looks.width / 2, 0, 0)
		left.Parent = meteor
		local right = Instance.new("Attachment")
		right.Position = Vector3.new(looks.width / 2, 0, 0)
		right.Parent = meteor
		local trail = Instance.new("Trail")
		trail.Attachment0 = left
		trail.Attachment1 = right
		trail.Color = ColorSequence.new(looks.color)
		trail.Lifetime = looks.seconds / 2
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Parent = meteor
		meteor.Parent = folder

		local tween = TweenService:Create(
			meteor,
			TweenInfo.new(looks.seconds, Enum.EasingStyle.Linear),
			{ CFrame = start.Rotation + target }
		)
		tween.Completed:Connect(function(state)
			meteor:Destroy()
			if state == Enum.PlaybackState.Completed then
				landed()
			end
		end)
		tween:Play()
	end

	-- A crater is marked for players while its egg is in it, so the pin of its zone moves on to
	-- the next crater once the egg is taken. NestService keeps the egg's state on the model.
	local function markCrater(site: WorldService.NestSite)
		local model = site.model
		local function sync()
			if model:GetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE) == true then
				dependencies.showSpot("Meteor", site.id, site.zone, site.eggCFrame.Position)
			else
				dependencies.hideSpot("Meteor", site.id)
			end
		end
		model:GetAttributeChangedSignal(EggConfig.NEST_HAS_EGG_ATTRIBUTE):Connect(sync)
		model.Destroying:Connect(function()
			dependencies.hideSpot("Meteor", site.id)
		end)
		sync()
	end

	-- The crater `name` where its meteor landed; its mark stays on (markCrater takes it over).
	local function makeCrater(name: string, zone: ZoneConfig.ZoneId, center: Vector3)
		local site = dependencies.buildCrater(name, zone, center)
		if site and dependencies.addCrater(site, "Meteor") then
			table.insert(craters, site.id)
			markCrater(site)
			return
		end
		if site then
			site.model:Destroy()
		end
		dependencies.hideSpot("Meteor", name)
	end

	-- Every meteor's landing spot is picked and marked as the shower starts, so players see all
	-- the zones at once and can head out to the far ones before their meteors come down.
	local function begin()
		shower += 1
		local current = shower
		local place = dependencies.placeOf("Meteor")
		local direction = directionOf(if place then place.position else CENTER + Vector3.xAxis)
		local active = EVENT.schedule.activeSeconds
		local count = MeteorShower.eggCount(dependencies.activePlayers(), MeteorConfig)
		local zones = MeteorShower.zones(count, ZoneConfig.ZONE_ORDER)
		for index, delay in MeteorShower.fallTimes(count, active, MeteorConfig) do
			local zone = zones[index]
			local spot = spotIn(zone, direction)
			if not spot then
				continue
			end
			craterCount += 1
			local name = `MeteorCrater{craterCount}`
			landing[name] = spot
			dependencies.showSpot("Meteor", name, zone, spot)
			task.delay(delay, function()
				if shower ~= current then
					return
				end
				fall(spot, function()
					landing[name] = nil
					if shower == current then
						makeCrater(name, zone, spot)
					end
				end)
			end)
		end
	end

	local function finish()
		shower += 1
		for _, nestId in craters do
			dependencies.retireCrater(nestId)
		end
		table.clear(craters)
		-- Meteors that have not landed will not.
		for name in landing do
			dependencies.hideSpot("Meteor", name)
		end
		table.clear(landing)
		if folder then
			folder:ClearAllChildren()
		end
	end

	local function start()
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = workspace:FindFirstChild("World") or workspace
		folder = created

		dependencies.setPlacer("Meteor", pickPlace)
		dependencies.eventChanged.connect(function(id, phase)
			if id ~= "Meteor" then
				return
			end
			if phase == "Active" then
				begin()
			elseif phase == "Idle" then
				finish()
			end
		end)
	end

	return {
		name = "MeteorService",
		start = start,
	}
end

return table.freeze(MeteorService)
