--!strict
-- Whether a player is actually playing or away from the keyboard. A player is active while they
-- have moved some way or done something (a command) lately; standing on the trainer or idling at
-- the station is not activity. Moving is measured from an anchor point: drift and small
-- fidgeting around it do not count, going somewhere does (and moves the anchor). Pure: times and
-- positions are passed in (ActivityConfig has the numbers).

local Activity = {}

export type State = {
	-- When the player last did something (same clock as `now`).
	lastActiveAt: number,
	-- Where they were then; nil until the first position after joining or respawning.
	anchorX: number?,
	anchorY: number?,
	anchorZ: number?,
}

export type Tuning = {
	-- Counts as moving once this far from the anchor, studs.
	read MOVE_STUDS: number,
	-- Away after this long without activity, seconds.
	read IDLE_SECONDS: number,
}

-- A player who just joined counts as active.
function Activity.new(now: number): State
	return { lastActiveAt = now, anchorX = nil, anchorY = nil, anchorZ = nil }
end

-- The player did something.
function Activity.touch(state: State, now: number)
	state.lastActiveAt = now
end

-- A new character somewhere else (a respawn): the next position becomes the anchor, and the jump
-- there is not activity.
function Activity.forgetAnchor(state: State)
	state.anchorX, state.anchorY, state.anchorZ = nil, nil, nil
end

-- The player's character is at (x, y, z) now.
function Activity.observe(state: State, now: number, x: number, y: number, z: number, tuning: Tuning)
	local anchorX, anchorY, anchorZ = state.anchorX, state.anchorY, state.anchorZ
	if anchorX and anchorY and anchorZ then
		local dx, dy, dz = x - anchorX, y - anchorY, z - anchorZ
		if dx * dx + dy * dy + dz * dz < tuning.MOVE_STUDS * tuning.MOVE_STUDS then
			return
		end
		Activity.touch(state, now)
	end
	state.anchorX, state.anchorY, state.anchorZ = x, y, z
end

function Activity.idleSeconds(state: State, now: number): number
	return math.max(now - state.lastActiveAt, 0)
end

function Activity.isActive(state: State, now: number, tuning: Tuning): boolean
	return Activity.idleSeconds(state, now) < tuning.IDLE_SECONDS
end

return table.freeze(Activity)
