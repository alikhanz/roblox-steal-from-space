--!strict
-- A sliding-window rate limit per key: at most `limit` events in any `windowSeconds`. The first
-- filter every client command goes through (CONVENTIONS, section 5). Pure: time is passed in.

export type RateLimit = {
	-- True when the event is allowed, recording it; false when the key is over its limit.
	allow: (key: string, now: number) -> boolean,
	-- Drops a key's history (a player left).
	forget: (key: string) -> (),
}

local RateLimit = {}

function RateLimit.new(limit: number, windowSeconds: number): RateLimit
	assert(limit >= 1 and limit % 1 == 0, "limit must be a positive integer")
	assert(windowSeconds > 0, "window must be positive")
	local history: { [string]: { number } } = {}

	local function allow(key: string, now: number): boolean
		local times = history[key]
		if not times then
			times = {}
			history[key] = times
		end
		-- Drop what fell out of the window; the list is short (at most `limit` entries).
		while #times > 0 and now - times[1] >= windowSeconds do
			table.remove(times, 1)
		end
		if #times >= limit then
			return false
		end
		table.insert(times, now)
		return true
	end

	return {
		allow = allow,
		forget = function(key: string)
			history[key] = nil
		end,
	}
end

return table.freeze(RateLimit)
