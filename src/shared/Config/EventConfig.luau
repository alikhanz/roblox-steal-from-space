--!strict
-- Server events (Domain/EventClock): when each comes round, what it is called and how it is
-- shown. Each server runs its own clocks; an event is announced to that server only. What an
-- event does in the game is its own service's business (stage 7 steps 7-9). Looks in EventLooks.

local EventClock = require("../Domain/EventClock")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")

export type EventId = "Storm" | "Meteor"

export type Event = {
	read id: EventId,
	read nameKey: keyof<typeof(Strings)>,
	read schedule: EventClock.Schedule,
	-- Runs on its clock in live servers; off until the event's gameplay is in (a Studio command
	-- still starts it).
	read scheduled: boolean,
	-- The countdown to it shows all the time, not only during the warning.
	read alwaysShowTimer: boolean,
}

local EVENTS: { [EventId]: Event } = {
	-- 5 minutes of normal play, a 10-second warning at the end of them, then 15 seconds of storm
	-- (StormConfig, StormService).
	Storm = {
		id = "Storm",
		nameKey = "event.storm.title",
		schedule = { gapMin = 5 * 60, gapMax = 5 * 60, warningSeconds = 10, activeSeconds = 15 },
		scheduled = true,
		alwaysShowTimer = true,
	},
	-- 15-25 minutes apart, a 30-second warning, then 2 minutes of meteor eggs falling at one
	-- guardian's post (MeteorConfig, MeteorService).
	Meteor = {
		id = "Meteor",
		nameKey = "event.meteor.title",
		schedule = { gapMin = 15 * 60, gapMax = 25 * 60, warningSeconds = 30, activeSeconds = 2 * 60 },
		scheduled = true,
		alwaysShowTimer = false,
	},
}

for _, event in EVENTS do
	table.freeze(event.schedule)
	table.freeze(event)
end

return table.freeze({
	EVENTS = table.freeze(EVENTS),
	-- Banner order, top first.
	ORDER = table.freeze({ "Storm", "Meteor" } :: { EventId }),
	-- The events' state for clients: a folder in ReplicatedStorage with one child per event,
	-- holding these attributes.
	FOLDER_NAME = "Events",
	PHASE_ATTRIBUTE = "Phase",
	-- Server time the phase ends.
	ENDS_AT_ATTRIBUTE = "EndsAt",
	-- Where the event is, if anywhere: its zone id and a point to mark on the screen.
	ZONE_ATTRIBUTE = "Zone",
	POSITION_ATTRIBUTE = "Position",
	-- The clocks are moved on this often, seconds.
	TICK_SECONDS = 0.25,
})
