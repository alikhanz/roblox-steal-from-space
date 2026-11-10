--!strict
-- The shapes of the harpoon's and the bomb's motion (brief docs/design/screens/pvp-abilities.md):
-- how far a loose egg has coasted, how the bomb spins and blinks towards its blast, how the ring
-- wave grows and fades, how a flash swells. Pure Luau: tests load it in Lune. Numbers in PvpLooks.

local PvpFx = {}

-- The bomb's look from the throw to the end of its fuse.
export type Charge = {
	-- Orbit turns a second at the throw and at the end of the fuse.
	read spinFrom: number,
	read spinTo: number,
	-- Light blinks a second at the throw and at the end of the fuse.
	read blinkFrom: number,
	read blinkTo: number,
	-- Over the fuse's last seconds the orbits close in to this share of their size.
	read collapseSeconds: number,
	read collapseScale: number,
}

-- The ring wave after the blast: it grows from `startRadius` to the blast's radius, holds, fades.
export type Wave = {
	read startRadius: number,
	read growSeconds: number,
	read holdSeconds: number,
	read fadeSeconds: number,
}

local function easeOut(share: number): number
	local rest = 1 - math.clamp(share, 0, 1)
	return 1 - rest * rest
end

-- How far an egg launched at `speed` has coasted after `seconds`, keeping `retention` of its
-- speed every second (EggConfig.DROP_RETENTION_PER_SECOND; CarryService drifts it so).
function PvpFx.driftDistance(speed: number, retention: number, seconds: number): number
	if seconds <= 0 then
		return 0
	end
	if retention >= 1 then
		return speed * seconds
	end
	return speed * (retention ^ seconds - 1) / math.log(retention)
end

-- The egg's speed then.
function PvpFx.driftSpeed(speed: number, retention: number, seconds: number): number
	return speed * retention ^ math.max(seconds, 0)
end

-- The bomb `elapsed` seconds after the throw, `fuse` seconds long: how far its orbits have turned
-- (radians), their size (1: full) and whether its light is on. Spin and blinking speed up evenly
-- over the fuse.
function PvpFx.bombCharge(elapsed: number, fuse: number, charge: Charge): (number, number, boolean)
	local t = math.clamp(elapsed, 0, fuse)
	local function cycles(from: number, to: number): number
		return from * t + (to - from) * t * t / (2 * fuse)
	end
	local angle = 2 * math.pi * cycles(charge.spinFrom, charge.spinTo)
	local blink = cycles(charge.blinkFrom, charge.blinkTo)
	local isLit = blink - math.floor(blink) < 0.5
	local collapseStart = fuse - charge.collapseSeconds
	local scale = 1
	if t > collapseStart and charge.collapseSeconds > 0 then
		local share = (t - collapseStart) / charge.collapseSeconds
		scale = 1 + (charge.collapseScale - 1) * share
	end
	return angle, scale, isLit
end

-- The ring wave `elapsed` seconds after a blast of `radius`: its radius and transparency, or nil
-- once it has faded.
function PvpFx.wave(elapsed: number, radius: number, wave: Wave): (number?, number)
	local grown = wave.growSeconds + wave.holdSeconds
	if elapsed >= grown + wave.fadeSeconds then
		return nil, 1
	end
	local size = wave.startRadius + (radius - wave.startRadius) * easeOut(elapsed / wave.growSeconds)
	local transparency = if elapsed <= grown then 0 else (elapsed - grown) / wave.fadeSeconds
	return size, transparency
end

-- A flash `elapsed` seconds into its `seconds`: its size swelling from `from` to `to` and its
-- transparency, or nil once it is over.
function PvpFx.burst(elapsed: number, seconds: number, from: number, to: number): (number?, number)
	if elapsed >= seconds then
		return nil, 1
	end
	local share = math.max(elapsed, 0) / seconds
	return from + (to - from) * easeOut(share), share
end

return table.freeze(PvpFx)
