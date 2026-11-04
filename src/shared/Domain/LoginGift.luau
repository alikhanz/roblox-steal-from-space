--!strict
-- The login gift: one gift a UTC day, on a streak of up to `length` days in a row. Coming back
-- the next day moves the streak on; after the last day a new round starts; a missed day starts
-- the streak over. Pure: days are passed in (Quests.dayOf).

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
}

function LoginGift.empty(): State
	return { lastDay = 0, streak = 0 }
end

function LoginGift.status(state: State, today: number, length: number): Status
	if state.lastDay == today and state.streak >= 1 then
		return { available = false, day = state.streak, reset = false }
	elseif state.lastDay > 0 and state.lastDay == today - 1 then
		return { available = true, day = state.streak % length + 1, reset = false }
	end
	-- Never taken, missed a day or more, or a clock that went back: a fresh start.
	return { available = true, day = 1, reset = state.lastDay > 0 }
end

-- Takes today's gift: the streak day it was, or nil when it is already taken.
function LoginGift.claim(state: State, today: number, length: number): number?
	local status = LoginGift.status(state, today, length)
	if not status.available then
		return nil
	end
	state.lastDay = today
	state.streak = status.day
	return status.day
end

return table.freeze(LoginGift)
