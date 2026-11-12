--!strict
-- Oxygen supply: drains in space, refills under the station dome. Pure Luau.

local Speed = require("./Speed")

local Oxygen = {}

export type Tuning = {
	-- Units lost per second in space.
	read drainPerSecond: number,
	-- Units restored per second under the dome.
	read refillPerSecond: number,
}

-- Share of a full tank a hunter's catch takes, by how it stands against the thief
-- (Speed.challenge). The ends of each tier: `weak` at the Weak edge and above, `fair` right at
-- the recommended stat, `strong` just short of the skull, `tooStrong` past it.
export type CatchShares = {
	read weak: number,
	read fair: number,
	read strong: number,
	read tooStrong: number,
}

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * math.clamp(alpha, 0, 1)
end

-- The share a catch takes from a thief whose standing against the hunter is `standing`
-- (Speed.standing, -1..1) and tier `challenge` (Speed.challenge of the same stats; the tier
-- decides the band, so the cost always agrees with the pill over the hunter). It grows smoothly
-- inside a band: Fair from `weak` (a thief a tenfold ahead) to `fair` (level), Strong from
-- `fair` to `strong` at the skull's edge. Weak and TooStrong are flat. So the pill tells the
-- most a catch can cost: Fair up to `fair`, Strong up to `strong`, the skull `tooStrong`.
function Oxygen.catchShare(challenge: Speed.Challenge, standing: number, shares: CatchShares): number
	if challenge == "Weak" then
		return shares.weak
	elseif challenge == "Fair" then
		return lerp(shares.fair, shares.weak, standing)
	elseif challenge == "Strong" then
		return lerp(shares.fair, shares.strong, -standing)
	end
	return shares.tooStrong
end

function Oxygen.step(current: number, capacity: number, inSpace: boolean, deltaTime: number, tuning: Tuning): number
	local change = if inSpace then -tuning.drainPerSecond else tuning.refillPerSecond
	return math.clamp(current + change * deltaTime, 0, capacity)
end

-- What is left after a hit that takes `share` of a full tank (a guardian's catch): never below
-- empty. A hit on a nearly empty tank empties it, and the thief suffocates like any other.
function Oxygen.afterHit(current: number, capacity: number, share: number): number
	return math.max(current - capacity * math.max(share, 0), 0)
end

function Oxygen.isEmpty(current: number): boolean
	return current <= 0
end

-- Share of a full tank, for the HUD: 0..1.
function Oxygen.fraction(current: number, capacity: number): number
	if capacity <= 0 then
		return 0
	end
	return math.clamp(current / capacity, 0, 1)
end

return table.freeze(Oxygen)
