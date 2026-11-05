--!strict
-- The abilities' numbers and geometry: cooldowns, the strike corridor, the harpoon cone, the
-- bomb radius. Positions are plain {x, y, z} tables so this runs in Lune. Pure Luau.

local Abilities = {}

export type Vector = { x: number, y: number, z: number }

-- The strike is a lunge: the attacker shoots ahead along the aim, and whoever they touch on the
-- way takes the hit. No touch by the end of the lunge is a miss.
export type Strike = {
	read lungeSeconds: number,
	-- Speed on top of the attacker's top flight speed while lunging, studs per second.
	read lungeExtraSpeed: number,
	-- A touch: a target this close to the attacker, within this half-angle of the lunge.
	read contactStuds: number,
	read contactHalfAngleRadians: number,
	-- Counted from the start of the lunge.
	read cooldownSeconds: number,
}

-- The strike's timers, seconds left of each (0: over).
export type StrikeTimers = {
	lungeLeft: number,
	cooldownLeft: number,
}

export type Harpoon = {
	read rangeStuds: number,
	read halfAngleRadians: number,
	read cooldownSeconds: number,
	read missCooldownSeconds: number,
}

export type Bomb = {
	read throwSpeed: number,
	read fuseSeconds: number,
	-- The bomb goes off early when it comes this close to someone.
	read contactStuds: number,
	read radiusStuds: number,
	read cooldownSeconds: number,
}

-- Advances the strike timers by `deltaTime`. `wantsToStrike` is the strike input held while
-- striking is allowed; a lunge starts as soon as the cooldown allows, so holding the input
-- strikes again and again. Returns the next timers and whether a lunge started this step.
function Abilities.stepStrike(
	timers: StrikeTimers,
	wantsToStrike: boolean,
	deltaTime: number,
	tuning: Strike
): (StrikeTimers, boolean)
	local cooldownLeft = math.max(timers.cooldownLeft - deltaTime, 0)
	if wantsToStrike and cooldownLeft <= 0 then
		return { lungeLeft = tuning.lungeSeconds, cooldownLeft = tuning.cooldownSeconds }, true
	end
	return { lungeLeft = math.max(timers.lungeLeft - deltaTime, 0), cooldownLeft = cooldownLeft }, false
end

-- True once `cooldownSeconds` passed since `lastUsedAt` (0: never used).
function Abilities.isReady(lastUsedAt: number, now: number, cooldownSeconds: number): boolean
	return lastUsedAt <= 0 or now - lastUsedAt >= cooldownSeconds
end

local function subtract(a: Vector, b: Vector): Vector
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function length(v: Vector): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function dot(a: Vector, b: Vector): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

-- True when `target` lies within `reach` of `origin` and within `halfAngle` of `facing`
-- (a unit vector). A target at the origin itself counts as in the cone.
function Abilities.isInCone(origin: Vector, facing: Vector, target: Vector, reach: number, halfAngle: number): boolean
	local offset = subtract(target, origin)
	local distance = length(offset)
	if distance > reach then
		return false
	end
	if distance < 1e-6 then
		return true
	end
	local cosine = dot(offset, facing) / (distance * length(facing))
	return cosine >= math.cos(halfAngle)
end

-- Where an attack from `from` first meets a round body of `radius` around `center`: the point
-- of the body nearest to `from` (`from` itself when inside it). Attacks aim at that point, so
-- a big body is hit at its surface, not only at its middle.
function Abilities.nearestPoint(center: Vector, radius: number, from: Vector): Vector
	local offset = subtract(from, center)
	local distance = length(offset)
	if distance <= radius then
		return from
	end
	local scale = radius / distance
	return { x = center.x + offset.x * scale, y = center.y + offset.y * scale, z = center.z + offset.z * scale }
end

-- The nearest of `targets` inside the cone, or nil. Targets are {id, position}.
function Abilities.nearestInCone<T>(
	origin: Vector,
	facing: Vector,
	targets: { { id: T, position: Vector } },
	reach: number,
	halfAngle: number
): T?
	local best: T? = nil
	local bestDistance = math.huge
	for _, target in targets do
		if Abilities.isInCone(origin, facing, target.position, reach, halfAngle) then
			local distance = length(subtract(target.position, origin))
			if distance < bestDistance then
				best = target.id
				bestDistance = distance
			end
		end
	end
	return best
end

-- Everyone within `radius` of `center`: ids of `targets`.
function Abilities.withinRadius<T>(center: Vector, targets: { { id: T, position: Vector } }, radius: number): { T }
	local hit = {}
	for _, target in targets do
		if length(subtract(target.position, center)) <= radius then
			table.insert(hit, target.id)
		end
	end
	return hit
end

return table.freeze(Abilities)
