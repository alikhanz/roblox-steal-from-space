--!strict
-- The curves of the pets' living motion (AlienMotionController), as the pet gallery prototype had
-- them (docs/design/prototypes/pet-look/gallery_client.luau, approved by the user). Pure numbers:
-- each takes the time since its move began, so the controller only keeps when that was.

local PetMotion = {}

-- A blink lasts this long, seconds; a double blink starts the second one this much later.
local BLINK_SECONDS = 0.14
local BLINK_AGAIN = 0.22
-- A jaw opens, holds, then snaps shut, seconds from its start; a double snap starts again later.
local JAW_OPENING = 0.35
local JAW_HOLD = 0.45
local JAW_SHUT = 0.52
local JAW_AGAIN = 0.6
-- A slime's hop, seconds from its start: a crouch, a push off, the flight, then a wobble on
-- landing that dies away.
local HOP_CROUCH = 0.2
local HOP_PUSH = 0.35
local HOP_LAND = 0.8
local HOP_AIR_FROM = 0.28
local WOBBLE_SECONDS = 1.8

-- 0 to 1 with a gentle start and end.
function PetMotion.smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- How far the eyes are open, 1 down to almost shut, `since` seconds after a blink began (a quick
-- close and open; `twice`: a second one right after).
function PetMotion.eyeOpen(since: number, twice: boolean): number
	local function once(s: number): number
		if s < 0 or s > BLINK_SECONDS then
			return 1
		end
		return 1 - 0.9 * math.sin(s / BLINK_SECONDS * math.pi)
	end
	return math.min(once(since), if twice then once(since - BLINK_AGAIN) else 1)
end

-- How far a jaw is open, 0 to `open` radians, `since` seconds after its snap began: it opens
-- slowly, holds, snaps shut (`twice`: and again).
function PetMotion.jawOpen(since: number, twice: boolean, open: number): number
	local function once(s: number): number
		if s < 0 then
			return 0
		elseif s < JAW_OPENING then
			return open * math.sin(s / JAW_OPENING * math.pi / 2)
		elseif s < JAW_HOLD then
			return open
		elseif s < JAW_SHUT then
			return open * (1 - (s - JAW_HOLD) / (JAW_SHUT - JAW_HOLD))
		end
		return 0
	end
	return math.max(once(since), if twice then once(since - JAW_AGAIN) else 0)
end

-- How long a slime's hop takes, landing wobble included, seconds.
PetMotion.HOP_SECONDS = HOP_LAND + WOBBLE_SECONDS

-- A slime's hop `since` seconds after it began: how much taller than at rest the jelly is (a share
-- of its height; negative: squashed) and how high it is lifted (a share of `height` = 1). It
-- crouches, pushes off stretched, rounds out in the air and lands with a wobble that grows from
-- nothing and dies away. Every phase starts where the last one ended: a jump in the curve shows
-- as a jerk (it did in the prototype).
function PetMotion.hop(since: number, hopHeight: number): (number, number)
	local stretch, lift = 0, 0
	local s = since
	if s < 0 or s >= PetMotion.HOP_SECONDS then
		return 0, 0
	elseif s < HOP_CROUCH then
		stretch = -0.12 * PetMotion.smooth(s / HOP_CROUCH)
	elseif s < HOP_PUSH then
		stretch = -0.12 + 0.22 * PetMotion.smooth((s - HOP_CROUCH) / (HOP_PUSH - HOP_CROUCH))
	elseif s < HOP_LAND then
		stretch = 0.1 * (1 - PetMotion.smooth((s - HOP_PUSH) / (HOP_LAND - HOP_PUSH)))
	else
		local d = s - HOP_LAND
		stretch = -0.15 * math.exp(-d * 3.5) * math.sin(d * 13)
	end
	if s > HOP_AIR_FROM and s < HOP_LAND then
		local u = (s - HOP_AIR_FROM) / (HOP_LAND - HOP_AIR_FROM)
		lift = hopHeight * 4 * u * (1 - u)
	end
	return stretch, lift
end

-- How much of a pet is drawn and moved, by its distance from the camera: 1 all of it, 2 its main
-- effects (the secondary particle layers and the light go), 3 none (it stands still and plain).
export type Detail = number

-- The detail for a pet `distance` studs from the camera and `radius` studs across half its width:
-- within `near` (past its own radius) all, within `far` the main effects, beyond none. Leaving the
-- detail it has (`current`) takes `margin` studs more, so a pet at the edge does not flicker.
function PetMotion.detail(
	distance: number,
	radius: number,
	current: Detail?,
	near: number,
	far: number,
	margin: number
): Detail
	local function level(slack: number): Detail
		if distance <= near + radius + slack then
			return 1
		elseif distance <= far + radius + slack then
			return 2
		end
		return 3
	end
	local plain = level(0)
	if not current or plain == current then
		return plain
	end
	-- Moving to less detail only past the margin; to more detail at once.
	if plain > current then
		return math.max(current, level(margin))
	end
	return plain
end

return table.freeze(PetMotion)
