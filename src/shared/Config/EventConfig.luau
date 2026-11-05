--!strict
-- Server events (Domain/EventClock): when each comes round, what it is called and how it is
-- shown. Each server runs its own clocks; an event is announced to that server only. What an
-- event does in the game is its own service's business (stage 7 steps 7-9). Looks in EventLooks.

local EventClock = require("../Domain/EventClock")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")

export type EventId = "Storm" | "Meteor" | "Serpent"

export type Event = {
	read id: EventId,
	read nameKey: keyof<typeof(Strings)>,
	read schedule: EventClock.Schedule,
	-- Runs on its clock in live servers; off until the event's gameplay is in (a Studio command
	-- still starts it).
	read scheduled: boolean,
	-- The countdown to it shows all the time, not only during the warning.
	read alwaysShowTimer: boolean,
	-- Once its gap is over it waits for this event to end and starts its warning right then, so
	-- the two never overlap (its warning and run must fit in the other's quiet spell).
	read after: EventId?,
	-- Announced as each of its spots first comes up (SPOTS_FOLDER_NAME), with `{zone}`.
	read spotAnnounceKey: keyof<typeof(Strings)>?,
	-- Announced as it starts instead of the usual "{name} is here" line, when it has more to
	-- tell; `{zone}` is its place's zone.
	read startAnnounceKey: keyof<typeof(Strings)>?,
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
	-- 15-25 minutes apart (and then up to one storm cycle more: it starts as a storm ends), a
	-- 30-second warning, then 2 minutes of meteors along a strip through every zone
	-- (MeteorConfig, MeteorService); each crater they leave is a spot.
	Meteor = {
		id = "Meteor",
		nameKey = "event.meteor.title",
		schedule = { gapMin = 15 * 60, gapMax = 25 * 60, warningSeconds = 30, activeSeconds = 2 * 60 },
		scheduled = true,
		alwaysShowTimer = false,
		after = "Storm",
		-- Inference loses the key's literal type in an optional field.
		spotAnnounceKey = "event.crater.announce" :: keyof<typeof(Strings)>,
	},
	-- 15-25 minutes apart, right after a storm like the meteor shower (the two may come
	-- together), a 30-second warning, then 3 minutes of the star serpent carrying the star egg
	-- in one zone past the first (SerpentConfig, SerpentService; decision 055).
	Serpent = {
		id = "Serpent",
		nameKey = "event.serpent.title",
		schedule = { gapMin = 15 * 60, gapMax = 25 * 60, warningSeconds = 30, activeSeconds = 3 * 60 },
		scheduled = true,
		alwaysShowTimer = false,
		after = "Storm",
		startAnnounceKey = "event.serpent.announce" :: keyof<typeof(Strings)>,
	},
}

for _, event in EVENTS do
	table.freeze(event.schedule)
	table.freeze(event)
end

return table.freeze({
	EVENTS = table.freeze(EVENTS),
	-- Banner order, top first.
	ORDER = table.freeze({ "Storm", "Meteor", "Serpent" } :: { EventId }),
	-- The events' state for clients: a folder in ReplicatedStorage with one child per event,
	-- holding these attributes.
	FOLDER_NAME = "Events",
	PHASE_ATTRIBUTE = "Phase",
	-- Server time the phase ends.
	ENDS_AT_ATTRIBUTE = "EndsAt",
	-- Where the event is, if anywhere: its zone id and a point to mark on the screen.
	ZONE_ATTRIBUTE = "Zone",
	POSITION_ATTRIBUTE = "Position",
	-- An event that is in many places at once (the meteor shower's craters) lists them in a
	-- folder of this name inside its child: a Vector3Value per spot, with the ZONE_ATTRIBUTE.
	-- While it has spots, they are marked one pin per zone (Domain/EventSpots) instead of the
	-- event's point.
	SPOTS_FOLDER_NAME = "Spots",
	-- An event that moves (the star serpent) points this ObjectValue in its child at the part
	-- it is on: the pin follows that part every frame while the client has it, and the
	-- POSITION_ATTRIBUTE (a few updates a second) only when it does not (streamed out).
	FOLLOW_NAME = "Follow",
	-- The clocks are moved on this often, seconds.
	TICK_SECONDS = 0.25,
})
