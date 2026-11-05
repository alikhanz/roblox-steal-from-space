--!strict
-- The meteor shower's plan: how many meteors fall, when, and in which zone (MeteorConfig). Pure.

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

-- The zone of each of `count` meteors: round and round the zones from the station outwards, so
-- every zone gets its share all through the shower.
function MeteorShower.zones<T>(count: number, zoneOrder: { T }): { T }
	local result = {}
	for index = 1, count do
		result[index] = zoneOrder[(index - 1) % #zoneOrder + 1]
	end
	return result
end

return table.freeze(MeteorShower)
