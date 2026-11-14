--!strict
-- The meteor shower's plan: how many meteors fall, when, and at which guardian's post
-- (MeteorConfig). Pure.

local MeteorShower = {}

export type Tuning = {
	read EGGS_PER_PLAYER: number,
	read MIN_EGGS: number,
	read MAX_EGGS: number,
	read FALL_STEP_SECONDS: number,
}

-- Eggs in one shower for `players` on the server.
function MeteorShower.eggCount(players: number, tuning: Tuning): number
	return math.clamp(players * tuning.EGGS_PER_PLAYER, tuning.MIN_EGGS, tuning.MAX_EGGS)
end

-- Seconds after the start at which each of `count` meteors falls: one every `FALL_STEP_SECONDS`,
-- the first a step after the start, so the shower's own announcement is read before the first
-- crater's.
function MeteorShower.fallTimes(count: number, tuning: Tuning): { number }
	local times = {}
	for index = 1, count do
		times[index] = index * tuning.FALL_STEP_SECONDS
	end
	return times
end

-- What each player's craters are, in turn (decision 135): the first at the strongest guardian
-- they get away from, the next one post above (a reach for more), then one post below; so with
-- two craters each every player gets a crater of their level and one to stretch for.
local OFFSETS = { 0, 1, -1 }

-- The guardian post (global, 1..`postCount`) of each of `count` meteors, shared out in turn
-- among the active players, whose strongest beaten posts are `bestPosts` (Domain/SpeedGoal).
-- Empty with no players: nobody is there to steal.
function MeteorShower.posts(bestPosts: { number }, count: number, postCount: number): { number }
	local result = {}
	if #bestPosts == 0 then
		return result
	end
	for index = 1, count do
		local player = (index - 1) % #bestPosts + 1
		local round = (index - 1) // #bestPosts
		local offset = OFFSETS[round % #OFFSETS + 1]
		result[index] = math.clamp(bestPosts[player] + offset, 1, postCount)
	end
	return result
end

return table.freeze(MeteorShower)
