--!strict
-- The clock of one server event: a quiet spell, a short warning, the event itself, and round
-- again. Every server runs its own clocks (events are per server). Pure: times and random
-- numbers are passed in.

export type Phase = "Idle" | "Warning" | "Active"

-- How an event comes round.
export type Schedule = {
	-- From the end of one event to the start of the next, seconds, picked between these; the
	-- warning is the last part of it.
	read gapMin: number,
	read gapMax: number,
	read warningSeconds: number,
	read activeSeconds: number,
}

export type State = {
	phase: Phase,
	-- When the current phase ends (server time).
	endsAt: number,
}

local EventClock = {}

local function gap(schedule: Schedule, random: () -> number): number
	return schedule.gapMin + (schedule.gapMax - schedule.gapMin) * random()
end

-- Quiet until the next event, which starts a full gap from `now`.
function EventClock.idle(now: number, schedule: Schedule, random: () -> number): State
	return { phase = "Idle", endsAt = now + math.max(gap(schedule, random) - schedule.warningSeconds, 0) }
end

-- The event right now, with no warning (Studio commands).
function EventClock.activate(now: number, schedule: Schedule): State
	return { phase = "Active", endsAt = now + schedule.activeSeconds }
end

-- The event in `seconds` from `now`, its warning included (Studio commands). Sooner than a full
-- warning, the warning starts at once and lasts only what is left.
function EventClock.queue(now: number, seconds: number, schedule: Schedule): State
	local startsAt = now + math.max(seconds, 0)
	if seconds < schedule.warningSeconds then
		return { phase = "Warning", endsAt = startsAt }
	end
	return { phase = "Idle", endsAt = startsAt - schedule.warningSeconds }
end

local function next(state: State, schedule: Schedule, random: () -> number): State
	if state.phase == "Idle" then
		return { phase = "Warning", endsAt = state.endsAt + schedule.warningSeconds }
	elseif state.phase == "Warning" then
		return { phase = "Active", endsAt = state.endsAt + schedule.activeSeconds }
	end
	return EventClock.idle(state.endsAt, schedule, random)
end

-- Moves the clock on to `now`. Returns the new state and the phases entered on the way, in
-- order (more than one only if a long pause skipped through them).
function EventClock.step(state: State, now: number, schedule: Schedule, random: () -> number): (State, { Phase })
	assert(schedule.activeSeconds > 0, "an event must last some time")
	local entered: { Phase } = {}
	local current = state
	while now >= current.endsAt do
		current = next(current, schedule, random)
		table.insert(entered, current.phase)
	end
	return current, entered
end

return table.freeze(EventClock)
