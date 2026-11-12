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
	-- Half-angle of the aim assist's cone: the harpoon finds a carrier this far off the aim.
	read halfAngleRadians: number,
	read cooldownSeconds: number,
	read missCooldownSeconds: number,
	-- The client's lock is honoured if the server sees its target this far off, at most
	-- (Abilities.lockSlack): the lag allowed for, bodies, and a cap against cheating.
	read lockLagSeconds: number,
	read lockBaseStuds: number,
	read lockMaxStuds: number,
}

export type Bomb = {
	-- Speed away from the thrower, on top of the thrower's own velocity, studs per second.
	read throwSpeed: number,
	read fuseSeconds: number,
	-- The bomb goes off early when it comes this close to someone.
	read contactStuds: number,
	read radiusStuds: number,
	read cooldownSeconds: number,
	-- Homing: the bomb steers for the target the aim is best on within this reach and half-angle
	-- at the throw (Abilities.bestInCone), changing its velocity by at most `steerAcceleration`
	-- studs per second squared (Domain/Homing), so a sharp turn still dodges it.
	read homingRangeStuds: number,
	read homingHalfAngleRadians: number,
	read steerAcceleration: number,
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

-- The aim assist's pick (decision 106): of `targets` inside the cone, the one the aim is best on.
-- Each is scored by its angle off `facing` as a share of `halfAngle` plus its distance as a share
-- of `reach`, and the lowest score wins: the target nearest the crosshair, unless another one
-- almost as near the crosshair is much closer. Targets are {id, position}; nil when none is in.
function Abilities.bestInCone<T>(
	origin: Vector,
	facing: Vector,
	targets: { { id: T, position: Vector } },
	reach: number,
	halfAngle: number
): T?
	local best: T? = nil
	local bestScore = math.huge
	local facingLength = length(facing)
	for _, target in targets do
		if not Abilities.isInCone(origin, facing, target.position, reach, halfAngle) then
			continue
		end
		local offset = subtract(target.position, origin)
		local distance = length(offset)
		local angle = 0
		if distance > 1e-6 and facingLength > 1e-6 then
			angle = math.acos(math.clamp(dot(offset, facing) / (distance * facingLength), -1, 1))
		end
		local score = (if halfAngle > 0 then angle / halfAngle else 0) + (if reach > 0 then distance / reach else 0)
		if score < bestScore then
			best = target.id
			bestScore = score
		end
	end
	return best
end

-- Whether a client's harpoon lock may stand (decision 106): the server sees the locked target at
-- `target`, while the client saw it, and itself, up to `slack` studs elsewhere (both fly on during
-- the client's lag). The target must be within `reach + slack` of `origin` and inside the cone of
-- `halfAngle` along `facing`, widened sideways by `slack`; not behind by more than `slack`.
function Abilities.isInLaggedCone(
	origin: Vector,
	facing: Vector,
	target: Vector,
	reach: number,
	halfAngle: number,
	slack: number
): boolean
	local offset = subtract(target, origin)
	local distance = length(offset)
	if distance > reach + slack then
		return false
	end
	local facingLength = length(facing)
	if facingLength < 1e-6 then
		return distance <= slack
	end
	local along = dot(offset, facing) / facingLength
	if along < -slack then
		return false
	end
	local sideways = math.sqrt(math.max(distance * distance - along * along, 0))
	return sideways <= math.max(along, 0) * math.tan(halfAngle) + slack
end

-- How far a client's view may be off at these speeds (decision 106): what the shooter and the
-- target cover over `lagSeconds`, plus `baseStuds` for bodies, at most `maxStuds`.
function Abilities.lockSlack(
	shooterSpeed: number,
	targetSpeed: number,
	lagSeconds: number,
	baseStuds: number,
	maxStuds: number
): number
	return math.min((shooterSpeed + targetSpeed) * lagSeconds + baseStuds, maxStuds)
end

-- One step of a blast wave of `radius` round `center` (decision 106): the ids of `targets` inside
-- it that it has not struck yet, which are now marked in `struck`. Swept every frame while the
-- wave lives, it strikes each target once.
function Abilities.waveStep<T>(
	center: Vector,
	targets: { { id: T, position: Vector } },
	radius: number,
	struck: { [T]: boolean }
): { T }
	local hit = {}
	for _, target in targets do
		if not struck[target.id] and length(subtract(target.position, center)) <= radius then
			struck[target.id] = true
			table.insert(hit, target.id)
		end
	end
	return hit
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
