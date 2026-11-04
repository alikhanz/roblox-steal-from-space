--!strict
-- The meteor shower's plan: how many eggs fall and when (MeteorConfig). Pure.

local MeteorShower = {}

export type Tuning = {
	read EGGS_PER_PLAYER: number,
	read MIN_EGGS: number,
	read MAX_EGGS: number,
	read FALL_SHARE: number,
}

-- Eggs in one shower for `players` on the server.
function MeteorShower.eggCount(players: number, tuning: Tuning): number
	return math.clamp(players * tuning.EGGS_PER_PLAYER, tuning.MIN_EGGS, tuning.MAX_EGGS)
end

-- Seconds after the start at which each of `count` eggs falls: the first at once, the rest
-- evenly until `FALL_SHARE` of the shower has passed.
function MeteorShower.fallTimes(count: number, activeSeconds: number, tuning: Tuning): { number }
	local span = activeSeconds * tuning.FALL_SHARE
	local times = {}
	for index = 1, count do
		times[index] = if count == 1 then 0 else (index - 1) * span / (count - 1)
	end
	return times
end

return table.freeze(MeteorShower)
