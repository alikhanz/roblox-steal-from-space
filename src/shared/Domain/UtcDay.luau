--!strict
-- Game days are UTC days: daily quests and the login gift turn over at UTC midnight, the same
-- moment on every server. A day is its number since the Unix epoch.

local DAY_SECONDS = 24 * 60 * 60

local UtcDay = {}

UtcDay.SECONDS = DAY_SECONDS

-- The UTC day of a Unix time.
function UtcDay.of(unixTime: number): number
	return math.floor(unixTime / DAY_SECONDS)
end

-- Seconds until the next UTC day begins.
function UtcDay.secondsLeft(unixTime: number): number
	return (UtcDay.of(unixTime) + 1) * DAY_SECONDS - unixTime
end

return table.freeze(UtcDay)
