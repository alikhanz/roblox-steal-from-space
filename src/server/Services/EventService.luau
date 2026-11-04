--!strict
-- Runs the server's event clocks (Domain/EventClock, EventConfig) and publishes each event's
-- state for clients as attributes on a folder in ReplicatedStorage, so a player who joins in the
-- middle sees it too. What an event does is up to the services that listen to `changed`; an
-- event that happens somewhere gets its place from the placer its service sets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventClock = require(ReplicatedStorage.Shared.Domain.EventClock)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local LOG = game:GetService("RunService"):IsStudio()

-- Where an event happens.
export type Place = {
	zone: ZoneConfig.ZoneId,
	position: Vector3,
}

-- Picks the place of an event as it is announced; nil for an event that is everywhere.
export type Placer = () -> Place?

export type Dependencies = {
	scheduler: Scheduler.Scheduler,
}

export type EventService = {
	name: string,
	init: () -> (),
	start: () -> (),
	-- An event entered a phase.
	changed: Signal.Signal<EventConfig.EventId, EventClock.Phase>,
	phaseOf: (id: EventConfig.EventId) -> EventClock.Phase,
	placeOf: (id: EventConfig.EventId) -> Place?,
	setPlacer: (id: EventConfig.EventId, placer: Placer) -> (),
	-- Studio commands: the event right now (somewhere in `zone`, if given); the event in
	-- `seconds`, warning and all; back to quiet.
	activate: (id: EventConfig.EventId, zone: ZoneConfig.ZoneId?) -> (),
	queue: (id: EventConfig.EventId, seconds: number) -> (),
	stop: (id: EventConfig.EventId) -> (),
}

type Running = {
	event: EventConfig.Event,
	clock: EventClock.State,
	place: Place?,
	placer: Placer?,
	folder: Configuration,
}

local EventService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A point in the middle of `zone`'s ring, at a random angle, level with the station.
local function pointIn(zone: ZoneConfig.ZoneId, random: Random): Vector3
	local ring = ZoneConfig.ZONES[zone]
	local radius = (ring.ringMin + ring.ringMax) / 2
	local angle = random:NextNumber() * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

function EventService.new(dependencies: Dependencies): EventService
	local changed = Signal.new() :: Signal.Signal<EventConfig.EventId, EventClock.Phase>
	local random = Random.new()
	local running: { [EventConfig.EventId]: Running } = {}

	local function roll(): number
		return random:NextNumber()
	end

	-- Quiet: until its next turn, or for good while it is not on the schedule.
	local function quiet(event: EventConfig.Event, from: number): EventClock.State
		if not event.scheduled then
			return { phase = "Idle", endsAt = math.huge }
		end
		return EventClock.idle(from, event.schedule, roll)
	end

	local function publish(entry: Running)
		local folder = entry.folder
		folder:SetAttribute(EventConfig.PHASE_ATTRIBUTE, entry.clock.phase)
		-- An endless quiet has no countdown.
		local endsAt = if entry.clock.endsAt == math.huge then 0 else entry.clock.endsAt
		folder:SetAttribute(EventConfig.ENDS_AT_ATTRIBUTE, endsAt)
		folder:SetAttribute(EventConfig.ZONE_ATTRIBUTE, if entry.place then entry.place.zone else nil)
		folder:SetAttribute(EventConfig.POSITION_ATTRIBUTE, if entry.place then entry.place.position else nil)
	end

	local function enter(entry: Running, phase: EventClock.Phase)
		if phase == "Idle" then
			entry.place = nil
			if not entry.event.scheduled then
				entry.clock = quiet(entry.event, now())
			end
		elseif not entry.place and entry.placer then
			entry.place = entry.placer()
		end
		if LOG then
			local place = entry.place
			local where = if place then ` in {place.zone}` else ""
			print(`[EventService] {entry.event.id}: {phase}{where}`)
		end
		publish(entry)
		changed.fire(entry.event.id, phase)
	end

	local function tick()
		local current = now()
		for _, entry in running do
			local clock, entered = EventClock.step(entry.clock, current, entry.event.schedule, roll)
			entry.clock = clock
			for _, phase in entered do
				enter(entry, phase)
			end
		end
	end

	local function init()
		local folder = Instance.new("Folder")
		folder.Name = EventConfig.FOLDER_NAME
		for id, event in EventConfig.EVENTS do
			local child = Instance.new("Configuration")
			child.Name = id
			child.Parent = folder
			local entry: Running = { event = event, clock = quiet(event, now()), place = nil, folder = child }
			running[id] = entry
			publish(entry)
		end
		folder.Parent = ReplicatedStorage
	end

	local function start()
		dependencies.scheduler.every(EventConfig.TICK_SECONDS, tick)
	end

	local function activate(id: EventConfig.EventId, zone: ZoneConfig.ZoneId?)
		local entry = assert(running[id], `unknown event {id}`)
		entry.clock = EventClock.activate(now(), entry.event.schedule)
		entry.place = if zone then { zone = zone, position = pointIn(zone, random) } else nil
		enter(entry, "Active")
	end

	-- Puts the event on the clock to start in `seconds`, with its warning, schedule or not.
	local function queue(id: EventConfig.EventId, seconds: number)
		local entry = assert(running[id], `unknown event {id}`)
		local warning = entry.event.schedule.warningSeconds
		entry.clock = { phase = "Idle", endsAt = now() + math.max(seconds - warning, 0) }
		entry.place = nil
		publish(entry)
	end

	local function stop(id: EventConfig.EventId)
		local entry = assert(running[id], `unknown event {id}`)
		entry.clock = quiet(entry.event, now())
		enter(entry, "Idle")
	end

	return {
		name = "EventService",
		init = init,
		start = start,
		changed = changed,
		phaseOf = function(id)
			return running[id].clock.phase
		end,
		placeOf = function(id)
			return running[id].place
		end,
		setPlacer = function(id, placer)
			running[id].placer = placer
		end,
		activate = activate,
		queue = queue,
		stop = stop,
	}
end

return table.freeze(EventService)
