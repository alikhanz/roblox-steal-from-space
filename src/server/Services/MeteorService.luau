--!strict
-- The meteor shower's gameplay, on its event's clock (EventService): the shower comes down at
-- one guardian's post, picked as it is announced. While it lasts, meteors fall around that
-- guardian's nest one after another, each leaving a meteor egg floating where it landed. The
-- eggs belong to that nest, so its guardian guards them like its own egg; they hatch into
-- meteor aliens of its grade (CarryService, MeteorConfig). Eggs nobody took are gone when the
-- shower ends; eggs in a thief's hands stay there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local CarryService = require(script.Parent.CarryService)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local EventClock = require(ReplicatedStorage.Shared.Domain.EventClock)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventService = require(script.Parent.EventService)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local MeteorConfig = require(ReplicatedStorage.Shared.Config.MeteorConfig)
local MeteorShower = require(ReplicatedStorage.Shared.Domain.MeteorShower)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
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
	getNestSites: () -> { WorldService.NestSite },
	spawnLooseEgg: (egg: CarryService.Egg, position: Vector3, launch: Vector3?, lifetime: number?) -> (),
	clearLooseEggs: (variant: AlienConfig.VariantId) -> (),
}

export type MeteorService = {
	name: string,
	start: () -> (),
}

local MeteorService = {}

function MeteorService.new(dependencies: Dependencies): MeteorService
	local random = Random.new()
	-- Counts showers: meteors planned for a shower that has ended do not fall.
	local shower = 0
	local folder: Folder? = nil

	-- The shower comes down at a random guardian's nest.
	local function pickPlace(): EventService.Place?
		local sites = dependencies.getNestSites()
		if #sites == 0 then
			return nil
		end
		local site = sites[random:NextInteger(1, #sites)]
		return { zone = site.zone, position = site.eggCFrame.Position }
	end

	-- The nest of the place's zone nearest to it (a Studio command picks only a zone).
	local function siteAt(place: EventService.Place): WorldService.NestSite?
		local nearest: WorldService.NestSite? = nil
		local nearestDistance = math.huge
		for _, site in dependencies.getNestSites() do
			local distance = (site.eggCFrame.Position - place.position).Magnitude
			if site.zone == place.zone and distance < nearestDistance then
				nearest, nearestDistance = site, distance
			end
		end
		return nearest
	end

	local function landingNear(center: Vector3): Vector3
		local angle = random:NextNumber() * math.pi * 2
		-- The square root spreads landings evenly over the disc instead of crowding the middle.
		local distance = math.sqrt(random:NextNumber()) * MeteorConfig.SCATTER_RADIUS
		local lift = random:NextNumber(-MeteorConfig.SCATTER_HEIGHT, MeteorConfig.SCATTER_HEIGHT)
		return center + Vector3.new(math.cos(angle) * distance, lift, math.sin(angle) * distance)
	end

	-- A burning streak falling onto `landing`; `landed` runs when it gets there.
	local function fall(landing: Vector3, landed: () -> ())
		local looks = EggLooks.METEOR_STREAK
		local slant = Vector3.new(random:NextNumber(-MAX_SLANT, MAX_SLANT), 1, random:NextNumber(-MAX_SLANT, MAX_SLANT))
		local start = CFrame.lookAt(landing + slant.Unit * looks.height, landing)

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
			{ CFrame = start.Rotation + landing }
		)
		tween.Completed:Connect(function(state)
			meteor:Destroy()
			if state == Enum.PlaybackState.Completed then
				landed()
			end
		end)
		tween:Play()
	end

	-- One meteor at `site`, with an egg from its zone's loot, out of play when the shower ends.
	local function dropEgg(current: number, site: WorldService.NestSite, endsAt: number)
		local landing = landingNear(site.eggCFrame.Position)
		fall(landing, function()
			if shower ~= current then
				return
			end
			local zone = ZoneConfig.ZONES[site.zone]
			dependencies.spawnLooseEgg({
				rarity = Loot.pick(zone.rarityLoot, random:NextNumber()),
				size = Loot.pick(zone.sizeLoot, random:NextNumber()),
				nestId = site.id,
				variant = "Meteor",
				fromNest = false,
			}, landing, nil, math.max(endsAt - os.clock(), 0))
		end)
	end

	local function begin()
		shower += 1
		local current = shower
		local place = dependencies.placeOf("Meteor")
		local site = if place then siteAt(place) else nil
		if not site then
			warn("[MeteorService] No nest for the meteor shower")
			return
		end
		local active = EVENT.schedule.activeSeconds
		local endsAt = os.clock() + active
		local count = MeteorShower.eggCount(#Players:GetPlayers(), MeteorConfig)
		for _, delay in MeteorShower.fallTimes(count, active, MeteorConfig) do
			task.delay(delay, function()
				if shower == current then
					dropEgg(current, site, endsAt)
				end
			end)
		end
	end

	local function finish()
		shower += 1
		dependencies.clearLooseEggs("Meteor")
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
