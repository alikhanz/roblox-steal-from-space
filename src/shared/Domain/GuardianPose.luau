--!strict
-- The numbers of a guardian's look in motion (World/GuardianVisual): how big its model stands,
-- how its pace eases from state to state, its lunge when it catches someone. Pure numbers.

local GuardianPose = {}

-- The scale that makes a model whose longest side across (X or Z) is `span` studs as long as
-- `length` studs (its kind's box, GuardianLooks.KINDS) times its post's `postScale`.
function GuardianPose.fitScale(span: number, length: number, postScale: number): number
	assert(span > 0, "a guardian model has no size")
	return length * postScale / span
end

-- `current` eased towards `target` over a frame of `dt` seconds: most of the way (95 %) within
-- `seconds`, never past it, the same whatever the frame rate.
function GuardianPose.ease(current: number, target: number, dt: number, seconds: number): number
	if seconds <= 0 then
		return target
	end
	return current + (target - current) * (1 - math.exp(-3 * dt / seconds))
end

-- Share of a catch's time the lunge takes to reach its furthest; the rest it draws back.
local LUNGE_OUT = 0.3

-- A catch `since` seconds ago, lasting `seconds`: how far the guardian lunges ahead (0 at rest,
-- 1 at its furthest: quick out, slower back) and how far its jaw snaps open (0 to 1 and shut).
function GuardianPose.strike(since: number, seconds: number): (number, number)
	if since < 0 or since >= seconds then
		return 0, 0
	end
	local u = since / seconds
	local lunge = if u < LUNGE_OUT then u / LUNGE_OUT else 1 - (u - LUNGE_OUT) / (1 - LUNGE_OUT)
	return lunge, math.sin(u * math.pi)
end

return table.freeze(GuardianPose)
