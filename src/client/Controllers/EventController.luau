--!strict
-- Server events on the client. Reads each event's state from the attributes the server keeps in
-- ReplicatedStorage (EventService), and shows it: the countdown line at the top, a big
-- announcement when an event is about to start or starts (naming the zone, if it has one), and a
-- pin to where it happens (UI/ScreenPin).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EventBanner = require(script.Parent.Parent.UI.EventBanner)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventLooks = require(ReplicatedStorage.Shared.Config.EventLooks)
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
}

-- One event as the client sees it.
type Seen = {
	event: EventConfig.Event,
	folder: Instance,
	pin: ScreenPin.Pin,
}

local EventController = {}

function EventController.new(): EventController
	local locale: Text.Locale = "en"
	local lines = source({} :: { EventBanner.Line })
	local announcement = source(nil :: EventBanner.Announcement?)
	local seen: { Seen } = {}
	local announcedUntil = 0

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

	local function zoneName(entry: Seen): string?
		local zone = entry.folder:GetAttribute(EventConfig.ZONE_ATTRIBUTE)
		local config = if type(zone) == "string" then (ZoneConfig.ZONES :: any)[zone] else nil
		return if config then text(config.nameKey) else nil
	end

	-- When the event itself starts (the warning is the run-up to it).
	local function startsAt(entry: Seen): number
		local endsAt = endsAtOf(entry)
		return if phaseOf(entry) == "Idle" then endsAt + entry.event.schedule.warningSeconds else endsAt
	end

	local function announce(entry: Seen, phase: string)
		local name = nameOf(entry.event)
		local message: string
		if phase == "Warning" then
			local left = startsAt(entry) - workspace:GetServerTimeNow()
			message = text("event.soon.announce", { name = name, time = Duration.describe(locale, left) })
		else
			local zone = zoneName(entry)
			message = if zone
				then text("event.startedIn.announce", { name = name, zone = zone })
				else text("event.started.announce", { name = name })
		end
		announcement({ text = message, color = EventLooks.COLORS[entry.event.id] })
		announcedUntil = os.clock() + EventLooks.ANNOUNCE_SECONDS
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

	-- Every frame: pins to the events that happen somewhere.
	local function placePins()
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		for _, entry in seen do
			local position = entry.folder:GetAttribute(EventConfig.POSITION_ATTRIBUTE)
			local live = phaseOf(entry) ~= "Idle"
			if camera and root and root:IsA("BasePart") and live and typeof(position) == "Vector3" then
				local studs = (position - root.Position).Magnitude
				entry.pin.place(camera, position, ScreenPin.distanceText(locale, studs))
			else
				entry.pin.hide()
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
			local entry: Seen = { event = EventConfig.EVENTS[id], folder = child, pin = ScreenPin.new() }
			table.insert(seen, entry)
			Vide.mount(function()
				return entry.pin.view({
					name = `EventPin{id}`,
					title = nameOf(entry.event),
					color = EventLooks.COLORS[id],
				})
			end, playerGui)
			-- Only changes from now on are announced: a player who joins mid-event just sees
			-- the countdown.
			child:GetAttributeChangedSignal(EventConfig.PHASE_ATTRIBUTE):Connect(function()
				local phase = phaseOf(entry)
				if phase ~= "Idle" then
					announce(entry, phase)
				end
			end)
		end
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[EventController] PlayerGui did not appear")
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
	}
end

return table.freeze(EventController)
