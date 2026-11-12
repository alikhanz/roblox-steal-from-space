--!strict
-- The star serpent's route while it carries its egg (decision 055; the winding route came after
-- the friends' playtest of 2026-11-12): a winding path round the station through the band where
-- it lives, from past the station border (so never into a dome) out to the map's edge. It heads for a waypoint some way round the station, at a fresh
-- distance from it and a fresh height, and never turns tighter than a set radius, so its path
-- bends in long readable curves; now and then it turns back the other way round. Fleeing a
-- player it keeps winding, only faster, and once its waypoint lies towards them it picks one
-- the other way. Pure: works only with the vectors it is given (Lune has no Vector3 global) and
-- rolls its dice through the function it is given.

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
	-- Fleeing, it picks a new waypoint once its waypoint lies within this angle of the threat
	-- (radians), at most once in `repickSeconds`.
	read threatAngle: number,
	read repickSeconds: number,
}

export type Route = {
	read goal: Vector3,
	-- Which way round the station it goes: +1 or -1, about `up`.
	read turn: number,
	-- Seconds since the goal was picked.
	read age: number,
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
-- that far from the band's edges. Fleeing `threat`, the waypoint is no nearer to it across the
-- band than where the serpent is.
function SerpentRoute.pickGoal(
	band: Band,
	tuning: Tuning,
	position: Vector3,
	turn: number,
	roll: Roll,
	threat: Vector3?
): Vector3
	local radius, outward = SerpentRoute.locate(band, position)
	local margin = tuning.turnRadius * 2
	local lowest = band.inner + margin
	local highest = math.max(lowest, band.outer - margin)
	local from = math.clamp(radius, lowest, highest)
	local nearest = math.max(lowest, from - tuning.maxRadialStep)
	local farthest = math.min(highest, from + tuning.maxRadialStep)
	if threat then
		local threatRadius = SerpentRoute.locate(band, threat)
		if threatRadius < radius then
			nearest = from
		else
			farthest = from
		end
	end
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
	return { goal = SerpentRoute.pickGoal(band, tuning, position, turn, roll, nil), turn = turn, age = 0 }
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

-- Whether it is done with `goal`: close to it, or past it (behind and not far).
local function reached(tuning: Tuning, position: Vector3, heading: Vector3, goal: Vector3): boolean
	local toGoal = goal - position
	local distance = toGoal.Magnitude
	return distance < tuning.turnRadius or (distance < tuning.turnRadius * 3 and toGoal:Dot(heading) < 0)
end

-- Whether the goal lies towards `threat`.
local function towards(tuning: Tuning, position: Vector3, goal: Vector3, threat: Vector3): boolean
	local toGoal, toThreat = goal - position, threat - position
	if toGoal.Magnitude < 1e-4 or toThreat.Magnitude < 1e-4 then
		return false
	end
	return toGoal.Unit:Dot(toThreat.Unit) > math.cos(tuning.threatAngle)
end

-- One step of `deltaTime` seconds at `speed` from `position`, flying along unit `heading`,
-- fleeing `threat` if any: the route (with a new waypoint when it is done with its own, or
-- that one lies towards the threat) and the unit heading to fly next, turned no tighter than
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
	local goal, turn, age = route.goal, route.turn, route.age + deltaTime
	local fleeing = threat ~= nil and age >= tuning.repickSeconds and towards(tuning, position, goal, threat)
	if fleeing and threat then
		-- Round the station away from the threat, and the way it already flies unless that
		-- leads towards the threat: no U-turn into the chaser's arms.
		local _, outward = SerpentRoute.locate(band, position)
		local away = position - threat
		turn = if band.up:Cross(outward):Dot(away.Unit + heading) >= 0 then 1 else -1
		goal = SerpentRoute.pickGoal(band, tuning, position, turn, roll, threat)
		age = 0
	elseif reached(tuning, position, heading, goal) then
		-- It turns back only while nobody is after it.
		if not threat and roll() < tuning.turnBackChance then
			turn = -turn
		end
		goal = SerpentRoute.pickGoal(band, tuning, position, turn, roll, threat)
		age = 0
	end
	local desired = SerpentRoute.awayFromEdge(band, tuning, position, heading) or goal - position
	local next = heading
	if desired.Magnitude > 1e-4 then
		next = SerpentRoute.turnToward(band, heading, desired.Unit, speed * deltaTime / tuning.turnRadius)
	end
	return { goal = goal, turn = turn, age = age }, next
end

return table.freeze(SerpentRoute)
