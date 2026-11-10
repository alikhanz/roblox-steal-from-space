--!strict
-- How hard a jetpack's flame burns (decision 089): a share of its full length, from the engine's
-- state. Pure Luau; the look (lengths, colours, textures) is JetpackLooks', the beams the effects
-- controller's.

local JetFlame = {}

export type Tuning = {
	-- Share of the full flame while hovering (no thrust).
	read idle: number,
	-- Share during a burst: the restart after a stun, the strike's lunge.
	read burst: number,
	-- The flame changes in steps of this share, so its beams are rewritten only when it does.
	read step: number,
}

export type State = {
	-- Speed over top speed, 0..1.
	read thrust: number,
	read burst: boolean,
	-- On the jetpack stand: how many times bigger it burns there (Stand.flameScale); nil off it.
	read standScale: number?,
}

-- The flame's share of its full length: idle to 1 with thrust, the burst over that, and on the
-- stand the full flame times the stand's scale (the engine runs full there). Rounded to
-- `tuning.step`, so a flame that barely changes keeps its value.
function JetFlame.power(state: State, tuning: Tuning): number
	assert(tuning.step > 0, "step must be positive")
	local power
	if state.standScale then
		power = state.standScale
	elseif state.burst then
		power = tuning.burst
	else
		power = tuning.idle + (1 - tuning.idle) * math.clamp(state.thrust, 0, 1)
	end
	return math.floor(power / tuning.step + 0.5) * tuning.step
end

-- How much detail a flame `distance` studs from the camera gets: 3 all of it (core, jet, light),
-- 2 the jet and the light, 1 the jet only.
function JetFlame.detail(distance: number, near: number, far: number): number
	if distance <= near then
		return 3
	elseif distance <= far then
		return 2
	end
	return 1
end

-- How long a jetpack's trail lives, seconds, so that it is `length` studs long at `topSpeed`
-- (studs a second): a better jetpack flies faster, and its trail would grow with speed alone.
-- Slower than top speed it is shorter. Kept within `shortest`..`longest`.
function JetFlame.trailLifetime(length: number, topSpeed: number, shortest: number, longest: number): number
	assert(shortest > 0 and longest >= shortest, "need 0 < shortest <= longest")
	if topSpeed <= 0 then
		return shortest
	end
	return math.clamp(length / topSpeed, shortest, longest)
end

return table.freeze(JetFlame)
