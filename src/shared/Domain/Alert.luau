--!strict
-- A nest's alert meter (0..1): noise near the nest raises it, quiet lets it settle.
-- At 1 the guardian wakes up. Sneaking in slowly keeps the noise below the natural decay.

local Alert = {}

export type Tuning = {
	-- Beyond this distance from the nest a player makes no noise for it, studs.
	read noiseRadius: number,
	-- Alert gained per second at full noise (top speed right next to the nest).
	read noisePerSecond: number,
	-- Alert gained per second while a player is grabbing the egg.
	read grabPerSecond: number,
	-- Alert lost per second, always.
	read decayPerSecond: number,
}

-- How loud one player is for a nest, 0..1: faster and closer is louder.
function Alert.noise(distance: number, speedFraction: number, tuning: Tuning): number
	if distance >= tuning.noiseRadius then
		return 0
	end
	local closeness = 1 - distance / tuning.noiseRadius
	return math.clamp(speedFraction, 0, 1) * closeness
end

-- `noise` is the loudest player's noise; `grabbing` is true while anyone holds the grab.
function Alert.step(level: number, noise: number, grabbing: boolean, deltaTime: number, tuning: Tuning): number
	local gain = noise * tuning.noisePerSecond + (if grabbing then tuning.grabPerSecond else 0)
	return math.clamp(level + (gain - tuning.decayPerSecond) * deltaTime, 0, 1)
end

function Alert.isAwake(level: number): boolean
	return level >= 1
end

return table.freeze(Alert)
