--!strict
-- Server events on the client. Reads each event's state from the attributes the server keeps in
-- ReplicatedStorage (EventService), and shows it: the countdown line at the top, a big
-- announcement when an event is about to start or starts (naming the zone, if it has one), and a
-- pin to where it happens (UI/ScreenPin). An event in many places at once (the meteor shower's
-- craters) gets a pin per zone instead, to its spot there nearest to the player
-- (Domain/EventSpots), and each new spot is announced; pins are moved apart so none covers
-- another (Domain/ScreenMarker).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EventBanner = require(script.Parent.Parent.UI.EventBanner)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventLooks = require(ReplicatedStorage.Shared.Config.EventLooks)
local EventSpots = require(ReplicatedStorage.Shared.Domain.EventSpots)
local ScreenMarker = require(ReplicatedStorage.Shared.Domain.ScreenMarker)
local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
local FOLDER_WAIT_TIMEOUT = 30
-- Countdowns are whole seconds; four times a second keeps them from lagging behind.
local REFRESH_SECONDS = 0.25

export type EventController = {
	name: string,
	start: () -> (),
	-- For an event's own controller (the star serpent's): the big line in the event's color.
	say: (id: EventConfig.EventId, message: string) -> (),
	-- The title over the event's pin instead of its name; nil puts the name back.
	setPinTitle: (id: EventConfig.EventId, title: string?) -> (),
}

-- One event as the client sees it.
type Seen = {
	event: EventConfig.Event,
	folder: Instance,
	-- The pin to the event's point.
	pin: ScreenPin.Pin,
	-- Its spots, if it can have any (EventConfig.SPOTS_FOLDER_NAME), and their pins by zone,
	-- made as zones come up.
	spots: Instance?,
	zonePins: { [string]: ScreenPin.Pin },
	-- It has had spots in this phase: from then on its point is not marked (the spots are where
	-- it is), even once they are all gone.
	spotted: boolean,
	-- Spots announced in this run of the event, by name.
	announcedSpots: { [string]: boolean },
}

-- A pin to show this frame.
type Shown = {
	pin: ScreenPin.Pin,
	point: Vector3,
	studs: number,
}

local EventController = {}

function EventController.new(): EventController
	local locale: Text.Locale = "en"
	local lines = source({} :: { EventBanner.Line })
	local announcement = source(nil :: EventBanner.Announcement?)
	local seen: { Seen } = {}
	local announcedUntil = 0
	local gui: Instance? = nil
	-- Titles other controllers put over an event's pin (setPinTitle), by event.
	local pinTitles: { [EventConfig.EventId]: Vide.Source<string?> } = {}
	for _, id in EventConfig.ORDER do
		pinTitles[id] = source(nil :: string?)
	end

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	-- Keys from the configs are checked where they are defined; they pass through `any`.
	local function nameOf(event: EventConfig.Event): string
		local key: any = event.nameKey
		return text(key)
	end

	local function phaseOf(entry: Seen): string
		local phase = entry.folder:GetAttribute(EventConfig.PHASE_ATTRIBUTE)
		return if type(phase) == "string" then phase else "Idle"
	end

	local function endsAtOf(entry: Seen): number
		local endsAt = entry.folder:GetAttribute(EventConfig.ENDS_AT_ATTRIBUTE)
		return if type(endsAt) == "number" then endsAt else 0
	end

	-- The name of a zone given as an attribute value; nil for anything else.
	local function zoneTitle(zone: unknown): string?
		local config = if type(zone) == "string" then (ZoneConfig.ZONES :: any)[zone] else nil
		return if config then text(config.nameKey) else nil
	end

	local function zoneName(entry: Seen): string?
		return zoneTitle(entry.folder:GetAttribute(EventConfig.ZONE_ATTRIBUTE))
	end

	-- When the event itself starts (the warning is the run-up to it).
	local function startsAt(entry: Seen): number
		local endsAt = endsAtOf(entry)
		return if phaseOf(entry) == "Idle" then endsAt + entry.event.schedule.warningSeconds else endsAt
	end

	-- The big line in the event's color, for a few seconds; the next one replaces it.
	local function sayFor(id: EventConfig.EventId, message: string)
		announcement({ text = message, color = EventLooks.COLORS[id] })
		announcedUntil = os.clock() + EventLooks.ANNOUNCE_SECONDS
	end

	local function say(entry: Seen, message: string)
		sayFor(entry.event.id, message)
	end

	local function announce(entry: Seen, phase: string)
		local name = nameOf(entry.event)
		local message: string
		if phase == "Warning" then
			local left = startsAt(entry) - workspace:GetServerTimeNow()
			message = text("event.soon.announce", { name = name, time = Duration.describe(locale, left) })
		elseif entry.event.startAnnounceKey then
			-- The event's own words; they may name its zone.
			local key: any = entry.event.startAnnounceKey
			message = text(key, { zone = zoneName(entry) or "" })
		else
			local zone = zoneName(entry)
			message = if zone
				then text("event.startedIn.announce", { name = name, zone = zone })
				else text("event.started.announce", { name = name })
		end
		say(entry, message)
	end

	-- A spot of the event came up (a new crater): announced once per spot, as it first appears;
	-- a spot that comes back (its egg was returned) is not news.
	local function announceSpot(entry: Seen, spot: Instance)
		local key: any = entry.event.spotAnnounceKey
		local zone = zoneTitle(spot:GetAttribute(EventConfig.ZONE_ATTRIBUTE))
		if not key or not zone or entry.announcedSpots[spot.Name] then
			return
		end
		entry.announcedSpots[spot.Name] = true
		say(entry, text(key, { zone = zone }))
	end

	local function refreshLines()
		local current = workspace:GetServerTimeNow()
		local result: { EventBanner.Line } = {}
		for _, entry in seen do
			local phase = phaseOf(entry)
			local name = nameOf(entry.event)
			local color = EventLooks.COLORS[entry.event.id]
			if phase == "Active" then
				local left = Duration.clock(endsAtOf(entry) - current)
				table.insert(result, { text = text("event.active.hint", { name = name, time = left }), color = color })
			elseif phase == "Warning" or (entry.event.alwaysShowTimer and endsAtOf(entry) > 0) then
				local left = Duration.clock(startsAt(entry) - current)
				table.insert(result, { text = text("event.soon.hint", { name = name, time = left }), color = color })
			end
		end
		lines(result)
		if announcedUntil > 0 and os.clock() >= announcedUntil then
			announcedUntil = 0
			announcement(nil)
		end
	end

	local function zonePin(entry: Seen, zone: string): ScreenPin.Pin
		local existing = entry.zonePins[zone]
		if existing then
			return existing
		end
		local pin = ScreenPin.new()
		entry.zonePins[zone] = pin
		local id = entry.event.id
		local title = zoneTitle(zone) or nameOf(entry.event)
		-- Pins are placed only after start() has found PlayerGui.
		Vide.mount(function()
			return pin.view({ name = `EventPin{id}{zone}`, title = title, color = EventLooks.COLORS[id] })
		end, assert(gui, "[EventController] zone pin before start"))
		return pin
	end

	-- What of `entry` to mark for a player at `from`: its spots, one per zone, or else its point.
	local function collectPins(entry: Seen, from: Vector3, shown: { Shown })
		local spots: { EventSpots.Spot<Vector3> } = {}
		for _, child in if entry.spots then entry.spots:GetChildren() else {} do
			local zone = child:GetAttribute(EventConfig.ZONE_ATTRIBUTE)
			if child:IsA("Vector3Value") and type(zone) == "string" then
				table.insert(spots, { zone = zone, distance = (child.Value - from).Magnitude, item = child.Value })
			end
		end
		if #spots > 0 then
			entry.spotted = true
			for _, spot in EventSpots.nearestPerZone(spots) do
				table.insert(shown, { pin = zonePin(entry, spot.zone), point = spot.item, studs = spot.distance })
			end
			return
		end
		local position = entry.folder:GetAttribute(EventConfig.POSITION_ATTRIBUTE)
		if not entry.spotted and phaseOf(entry) ~= "Idle" and typeof(position) == "Vector3" then
			table.insert(shown, { pin = entry.pin, point = position, studs = (position - from).Magnitude })
		end
	end

	-- Every frame: pins to the events that happen somewhere. The nearest pin stays right on its
	-- place, farther ones step aside if they would cover it.
	local function placePins()
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local shown: { Shown } = {}
		if camera and root and root:IsA("BasePart") then
			for _, entry in seen do
				collectPins(entry, root.Position, shown)
			end
		end
		table.sort(shown, function(a: Shown, b: Shown)
			return a.studs < b.studs
		end)

		local visible: { [ScreenPin.Pin]: boolean } = {}
		if camera and #shown > 0 then
			local locations: { ScreenPin.Location } = {}
			local signs: { ScreenMarker.Point } = {}
			for index, item in shown do
				local location = ScreenPin.locate(camera, item.point)
				locations[index] = location
				signs[index] = { x = location.sign.X, y = location.sign.Y }
			end
			local size = ScreenPin.SIGN_SIZE
			local apart = ScreenMarker.separate(signs, size.X, size.Y, ScreenPin.screenOf(camera))
			for index, item in shown do
				local location = locations[index]
				location.sign = Vector2.new(apart[index].x, apart[index].y)
				item.pin.show(location, ScreenPin.distanceText(locale, item.studs))
				visible[item.pin] = true
			end
		end
		for _, entry in seen do
			if not visible[entry.pin] then
				entry.pin.hide()
			end
			for _, pin in entry.zonePins do
				if not visible[pin] then
					pin.hide()
				end
			end
		end
	end

	local function watch(folder: Instance, playerGui: Instance)
		for _, id in EventConfig.ORDER do
			local child = folder:WaitForChild(id, FOLDER_WAIT_TIMEOUT)
			if not child then
				warn(`[EventController] No state for event {id}`)
				continue
			end
			local entry: Seen = {
				event = EventConfig.EVENTS[id],
				folder = child,
				pin = ScreenPin.new(),
				spots = child:WaitForChild(EventConfig.SPOTS_FOLDER_NAME, FOLDER_WAIT_TIMEOUT),
				zonePins = {},
				spotted = false,
				announcedSpots = {},
			}
			table.insert(seen, entry)
			local spots = entry.spots
			if spots then
				-- Spots already there when the player joins are not news either.
				for _, spot in spots:GetChildren() do
					entry.announcedSpots[spot.Name] = true
				end
				spots.ChildAdded:Connect(function(spot)
					announceSpot(entry, spot)
				end)
			end
			local readTitle = pinTitles[id] :: () -> string?
			local eventName = nameOf(entry.event)
			Vide.mount(function()
				return entry.pin.view({
					name = `EventPin{id}`,
					title = function(): string
						return readTitle() or eventName
					end,
					color = EventLooks.COLORS[id],
				})
			end, playerGui)
			-- Only changes from now on are announced: a player who joins mid-event just sees
			-- the countdown.
			child:GetAttributeChangedSignal(EventConfig.PHASE_ATTRIBUTE):Connect(function()
				entry.spotted = false
				local phase = phaseOf(entry)
				if phase ~= "Idle" then
					announce(entry, phase)
				else
					table.clear(entry.announcedSpots)
				end
			end)
		end
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[EventController] PlayerGui did not appear")
		gui = playerGui
		local readAnnouncement = announcement :: () -> EventBanner.Announcement?
		Vide.mount(function()
			return EventBanner({ lines = lines, announcement = readAnnouncement })
		end, playerGui)

		local folder = ReplicatedStorage:WaitForChild(EventConfig.FOLDER_NAME, FOLDER_WAIT_TIMEOUT)
		if not folder then
			warn("[EventController] No events folder; no event banner")
			return
		end
		watch(folder, playerGui)

		local sinceRefresh = 0
		RunService.RenderStepped:Connect(function(deltaTime)
			placePins()
			sinceRefresh += deltaTime
			if sinceRefresh >= REFRESH_SECONDS then
				sinceRefresh = 0
				refreshLines()
			end
		end)
	end

	return {
		name = "EventController",
		start = start,
		say = sayFor,
		setPinTitle = function(id: EventConfig.EventId, title: string?)
			pinTitles[id](title)
		end,
	}
end

return table.freeze(EventController)
