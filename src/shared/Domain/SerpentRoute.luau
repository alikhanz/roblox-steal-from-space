--!strict
-- The star serpent's route while it carries its egg (decision 055; the winding route came after
-- the friends' playtest of 2026-11-12): a winding path round the station through the band where
-- it lives, from past the station border (so never into a dome) out to the map's edge. Roaming,
-- it heads for a waypoint some way round the station, at a fresh distance from it and a fresh
-- height, and never turns tighter than a set radius, so its path bends in long readable curves;
-- now and then it turns back the other way round. Chased, it keeps circling the station, only
-- faster, the way round away from the chaser, and swerves in and out and up and down along its
-- circle in a wide S: it never runs straight off to the map's edge, and the chaser who cuts the
-- corners gains on it. Pure: works only with the
-- vectors it is given (Lune has no Vector3 global) and rolls its dice through the function it
-- is given.

local SerpentRoute = {}

-- Where it lives: around `center`, between `inner` and `outer` studs from it across the plane
-- through `center` at right angles to `up`, and within `height` above or below that plane.
-- `up` and `across` are unit vectors at right angles to each other.
export type Band = {
	read center: Vector3,
	read up: Vector3,
	read across: Vector3,
	read inner: number,
	read outer: number,
	read height: number,
}

export type Tuning = {
	-- It never turns tighter than this, studs: the radius of its sharpest curve.
	read turnRadius: number,
	-- How far round the station the next waypoint lies, along the ring, studs.
	read minArc: number,
	read maxArc: number,
	-- How much nearer to or farther from the station the next waypoint may be, studs.
	read maxRadialStep: number,
	-- The chance that the next waypoint lies the other way round the station (a U-turn).
	read turnBackChance: number,
	-- Chased, it swerves every `swerveSeconds`: nearer to the station and then farther, by up
	-- to `swerveRadial` studs, climbing and then diving by `swerveClimb` of the way.
	read swerveRadial: number,
	read swerveSeconds: number,
	read swerveClimb: number,
}

export type Route = {
	read goal: Vector3,
	-- Which way round the station it goes: +1 or -1, about `up`.
	read turn: number,
	-- Seconds since the goal was picked.
	read age: number,
	-- Which side it swerved to last while chased (+1 or -1), 0 while nobody is after it.
	read swerve: number,
}

-- A number in [0, 1).
export type Roll = () -> number

-- How far `position` is from the band's center across its plane, and the unit vector out
-- towards it (`across` right over the center).
function SerpentRoute.locate(band: Band, position: Vector3): (number, Vector3)
	local offset = position - band.center
	local flat = offset - band.up * offset:Dot(band.up)
	local radius = flat.Magnitude
	return radius, if radius > 1e-4 then flat / radius else band.across
end

-- Unit `heading` turned towards unit `desired` by no more than `maxAngle` radians.
function SerpentRoute.turnToward(band: Band, heading: Vector3, desired: Vector3, maxAngle: number): Vector3
	local cos = math.clamp(heading:Dot(desired), -1, 1)
	if math.acos(cos) <= maxAngle then
		return desired
	end
	local side = desired - heading * cos
	if side.Magnitude < 1e-4 then
		-- Straight behind: turn across the band's plane.
		side = band.up:Cross(heading)
		if side.Magnitude < 1e-4 then
			side = band.across
		end
	end
	side = side.Unit
	return (heading * math.cos(maxAngle) + side * math.sin(maxAngle)).Unit
end

-- The next waypoint from `position`, `turn` way round the station: a random way along the ring
-- (minArc to maxArc), a random distance from the station within maxRadialStep of where it is,
-- a random height. Its curves overshoot a waypoint by up to two turn radii, so waypoints keep
-- that far from the band's edges.
function SerpentRoute.pickGoal(band: Band, tuning: Tuning, position: Vector3, turn: number, roll: Roll): Vector3
	local radius, outward = SerpentRoute.locate(band, position)
	local margin = tuning.turnRadius * 2
	local lowest = band.inner + margin
	local highest = math.max(lowest, band.outer - margin)
	local from = math.clamp(radius, lowest, highest)
	local nearest = math.max(lowest, from - tuning.maxRadialStep)
	local farthest = math.min(highest, from + tuning.maxRadialStep)
	local goalRadius = nearest + (farthest - nearest) * roll()
	local arc = tuning.minArc + (tuning.maxArc - tuning.minArc) * roll()
	local angle = turn * arc / ((from + goalRadius) / 2)
	-- `outward` turned by `angle` about `up` (it is at right angles to `up`).
	local direction = outward * math.cos(angle) + band.up:Cross(outward) * math.sin(angle)
	local height = (roll() * 2 - 1) * band.height
	return band.center + direction * goalRadius + band.up * height
end

-- Starts a route from `position`, a random way round the station.
function SerpentRoute.start(band: Band, tuning: Tuning, position: Vector3, roll: Roll): Route
	local turn = if roll() < 0.5 then 1 else -1
	local goal = SerpentRoute.pickGoal(band, tuning, position, turn, roll)
	return { goal = goal, turn = turn, age = 0, swerve = 0 }
end

-- How far a flyer heading into an edge still goes towards it while it turns, at its sharpest,
-- until it flies along it: `into` is the share of its heading that points into the edge.
local function turnRoom(tuning: Tuning, into: number): number
	return tuning.turnRadius * (1 - math.sqrt(1 - math.min(into, 1) ^ 2))
end

-- Where it must turn instead, if heading on for its goal could carry it over the band's inner
-- or outer edge: along that edge and away from it. Nil while it is clear of both.
function SerpentRoute.awayFromEdge(band: Band, tuning: Tuning, position: Vector3, heading: Vector3): Vector3?
	local radius, outward = SerpentRoute.locate(band, position)
	local buffer = tuning.turnRadius / 4
	local out = heading:Dot(outward)
	local along = heading - outward * out
	local alongUnit = if along.Magnitude > 1e-4 then along.Unit else band.up:Cross(outward)
	if out < 0 and radius - turnRoom(tuning, -out) < band.inner + buffer then
		return alongUnit + outward
	elseif out > 0 and radius + turnRoom(tuning, out) > band.outer - buffer then
		return alongUnit - outward
	end
	return nil
end

-- `position` moved into where waypoints may lie: two turn radii in from the band's edges (its
-- curves overshoot a waypoint by up to that), within its height.
local function inBand(band: Band, tuning: Tuning, position: Vector3): Vector3
	local radius, outward = SerpentRoute.locate(band, position)
	local margin = tuning.turnRadius * 2
	local lowest = band.inner + margin
	local clamped = math.clamp(radius, lowest, math.max(lowest, band.outer - margin))
	local height = math.clamp((position - band.center):Dot(band.up), -band.height, band.height)
	return band.center + outward * clamped + band.up * height
end

-- The next waypoint of a chased serpent at `position`, `turn` way round the station: as far
-- round as it flies at `speed` in `swerveSeconds`, farther from the station and higher (`side`
-- +1) or nearer and lower (-1).
function SerpentRoute.swerveGoal(
	band: Band,
	tuning: Tuning,
	position: Vector3,
	turn: number,
	side: number,
	speed: number,
	roll: Roll
): Vector3
	local radius, outward = SerpentRoute.locate(band, position)
	local arc = speed * tuning.swerveSeconds
	-- The swerve, and a drift either way, so a long chase wanders across the band too.
	local goalRadius = radius + tuning.swerveRadial * (side * (0.6 + 0.4 * roll()) + (roll() - 0.5))
	local angle = turn * arc / math.max((radius + goalRadius) / 2, 1)
	local direction = outward * math.cos(angle) + band.up:Cross(outward) * math.sin(angle)
	local height = (position - band.center):Dot(band.up) + side * tuning.swerveClimb * arc
	return inBand(band, tuning, band.center + direction * goalRadius + band.up * height)
end

-- Which way round the station a chased serpent goes: the way it flies, unless the chaser is
-- ahead that way.
local function wayFrom(band: Band, position: Vector3, heading: Vector3, threat: Vector3): number
	local _, outward = SerpentRoute.locate(band, position)
	local round = band.up:Cross(outward)
	local turn = if round:Dot(heading) >= 0 then 1 else -1
	local toThreat = threat - position
	if toThreat.Magnitude > 1e-4 and (round * turn):Dot(toThreat.Unit) > 0.5 then
		turn = -turn
	end
	return turn
end

-- Whether it is done with `goal`: close to it, or past it (behind and not far) after it had
-- time to turn round to it.
local function reached(tuning: Tuning, route: Route, position: Vector3, heading: Vector3, speed: number): boolean
	local toGoal = route.goal - position
	local distance = toGoal.Magnitude
	if distance < tuning.turnRadius then
		return true
	end
	local halfCircle = math.pi * tuning.turnRadius / math.max(speed, 1)
	return route.age > halfCircle and distance < tuning.turnRadius * 3 and toGoal:Dot(heading) < 0
end

-- One step of `deltaTime` seconds at `speed` from `position`, flying along unit `heading`,
-- chased by `threat` if any: the route (with a new waypoint when it is done with its own, or
-- a swerve when it is due) and the unit heading to fly next, turned no tighter than
-- tuning.turnRadius.
function SerpentRoute.step(
	route: Route,
	band: Band,
	tuning: Tuning,
	position: Vector3,
	heading: Vector3,
	speed: number,
	deltaTime: number,
	roll: Roll,
	threat: Vector3?
): (Route, Vector3)
	local goal, turn, age, swerve = route.goal, route.turn, route.age + deltaTime, route.swerve
	if threat then
		if swerve == 0 or age >= tuning.swerveSeconds then
			turn = wayFrom(band, position, heading, threat)
			-- The first swerve goes out (or in, if the chaser is farther out), then they take turns.
			if swerve == 0 then
				local threatRadius = SerpentRoute.locate(band, threat)
				swerve = if threatRadius <= (SerpentRoute.locate(band, position)) then 1 else -1
			else
				swerve = -swerve
			end
			goal = SerpentRoute.swerveGoal(band, tuning, position, turn, swerve, speed, roll)
			age = 0
		end
	elseif swerve ~= 0 then
		-- The chase is over: on round the station the way it flies now.
		local _, outward = SerpentRoute.locate(band, position)
		turn = if band.up:Cross(outward):Dot(heading) >= 0 then 1 else -1
		swerve = 0
		goal = SerpentRoute.pickGoal(band, tuning, position, turn, roll)
		age = 0
	elseif reached(tuning, route, position, heading, speed) then
		if roll() < tuning.turnBackChance then
			turn = -turn
		end
		goal = SerpentRoute.pickGoal(band, tuning, position, turn, roll)
		age = 0
	end
	local desired = SerpentRoute.awayFromEdge(band, tuning, position, heading) or goal - position
	local next = heading
	if desired.Magnitude > 1e-4 then
		next = SerpentRoute.turnToward(band, heading, desired.Unit, speed * deltaTime / tuning.turnRadius)
	end
	return { goal = goal, turn = turn, age = age, swerve = swerve }, next
end

return table.freeze(SerpentRoute)
