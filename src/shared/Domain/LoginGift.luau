--!strict
-- The login gift: one gift a UTC day, on a streak of up to `length` days in a row. Coming back
-- the next day moves the streak on; after the last day a new round starts; a missed day starts
-- the streak over. Pure: days are passed in (Domain/UtcDay).

local LoginGift = {}

-- As saved.
export type State = {
	-- The UTC day the last gift was taken; 0: never.
	lastDay: number,
	-- Which day of the streak that gift was (1..length); 0: none yet.
	streak: number,
}

-- Where the player stands today.
export type Status = {
	-- Today's gift is waiting.
	available: boolean,
	-- The streak day of today's gift (or of the one taken today), 1..length.
	day: number,
	-- The streak was broken: today starts over at day 1 after a missed day.
	reset: boolean,
	-- A brand-new player's first gift waits for their first delivered egg, so it does not skip
	-- the first guardians for them (it is minutes of their play: Domain/PlayReward).
	locked: boolean,
}

function LoginGift.empty(): State
	return { lastDay = 0, streak = 0 }
end

-- Where the player stands today. `delivered`: they have brought an egg home at least once; until
-- then no gift is waiting (Status.locked).
function LoginGift.status(state: State, today: number, length: number, delivered: boolean): Status
	if not delivered then
		return { available = false, day = 1, reset = false, locked = true }
	elseif state.lastDay == today and state.streak >= 1 then
		return { available = false, day = state.streak, reset = false, locked = false }
	elseif state.lastDay > 0 and state.lastDay == today - 1 then
		return { available = true, day = state.streak % length + 1, reset = false, locked = false }
	end
	-- Never taken, missed a day or more, or a clock that went back: a fresh start.
	return { available = true, day = 1, reset = state.lastDay > 0, locked = false }
end

-- Takes today's gift: the streak day it was, or nil when there is none to take (taken already,
-- or locked until the first delivery).
function LoginGift.claim(state: State, today: number, length: number, delivered: boolean): number?
	local status = LoginGift.status(state, today, length, delivered)
	if not status.available then
		return nil
	end
	state.lastDay = today
	state.streak = status.day
	return status.day
end

return table.freeze(LoginGift)
