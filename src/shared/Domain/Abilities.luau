--!strict
-- The abilities' numbers and geometry: cooldowns, the strike corridor, the harpoon cone, the
-- bomb radius. Positions are plain {x, y, z} tables so this runs in Lune. Pure Luau.

local Abilities = {}

export type Vector = { x: number, y: number, z: number }

export type Strike = {
	read windupSeconds: number,
	read lungeStuds: number,
	read reachStuds: number,
	read halfAngleRadians: number,
	read cooldownSeconds: number,
	read missStallSeconds: number,
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
	read radiusStuds: number,
	read cooldownSeconds: number,
}

export type Shield = {
	read seconds: number,
	read cooldownSeconds: number,
}

export type Dash = {
	read seconds: number,
	read multiplier: number,
	read cooldownSeconds: number,
}

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
