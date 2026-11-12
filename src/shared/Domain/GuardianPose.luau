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

-- The share of the way to a target that easing covers in a frame of `dt` seconds when it gets
-- most of the way (95 %) there within `seconds`: the same whatever the frame rate, never past it.
function GuardianPose.share(dt: number, seconds: number): number
	if seconds <= 0 then
		return 1
	end
	return 1 - math.exp(-3 * dt / seconds)
end

-- `current` eased towards `target` over a frame of `dt` seconds (see share).
function GuardianPose.ease(current: number, target: number, dt: number, seconds: number): number
	return current + (target - current) * GuardianPose.share(dt, seconds)
end

-- Where the model is drawn this frame, following its body: the body's server position reaches
-- the client in steps (each time the guardian's brain picks a new velocity, the body jumps a
-- little), so the model goes on from where it was drawn at the body's `velocity` and closes the
-- gap to the body's `target` position by easing (see share). On a steady course it keeps right
-- on the body; a jump is spread over `seconds`.
function GuardianPose.follow(drawn: Vector3, velocity: Vector3, target: Vector3, dt: number, seconds: number): Vector3
	local predicted = drawn + velocity * dt
	return predicted + (target - predicted) * GuardianPose.share(dt, seconds)
end

-- How near the camera, studs to its middle, a guardian `length` studs long wears its model
-- (GuardianLooks.MODELS): at least `minDistance` past its half length, and as far as `lengths` of
-- its own lengths, so that where its look changes it is no bigger than 1 / `lengths` radians of
-- the view, whatever its size (a whale's model shows from farther than a slime's).
function GuardianPose.wearReach(length: number, minDistance: number, lengths: number): number
	return math.max(minDistance, lengths * length) + length / 2
end

-- Whether a guardian `distance` studs from the camera wears its model, `wearing` it now: within
-- `reach` (wearReach) it puts it on, and takes it off only `margin` farther, so that a camera on
-- the line does not swap the model and the greybox back and forth.
function GuardianPose.wears(wearing: boolean, distance: number, reach: number, margin: number): boolean
	return distance <= reach + (if wearing then margin else 0)
end

-- How many screen pixels a stud of the sign over a guardian (or the star serpent) `distance`
-- studs from the camera takes when its size is held, or nil while it is not: between `near` and
-- `far` it is sized in studs and the camera's perspective shrinks it, smoothly; nearer it is held
-- at its size at `near` (no bigger), farther at its size at `far` (no smaller), as a fixed size in
-- pixels for a view `viewHeight` pixels tall with a vertical field of view of `fovDegrees`. Equal
-- to the perspective's size at the edge, so the switch shows no step; it changes only when the
-- sign crosses an edge or the view changes, never frame by frame.
function GuardianPose.labelPixelsPerStud(
	distance: number,
	near: number,
	far: number,
	viewHeight: number,
	fovDegrees: number
): number?
	assert(near > 0 and far > near, "labelPixelsPerStud needs 0 < near < far")
	local held = if distance < near then near elseif distance > far then far else nil
	if not held then
		return nil
	end
	return viewHeight / (2 * held * math.tan(math.rad(fovDegrees) / 2))
end

-- How faded the sign over a guardian (or the star serpent) `distance` studs from the camera is,
-- as transparency: clear up to `start`, then fading evenly to `maxFade` at `finish` (where the
-- sign goes), so far signs stay in the background and near ones stand out.
function GuardianPose.labelFade(distance: number, start: number, finish: number, maxFade: number): number
	assert(finish > start, "labelFade needs start < finish")
	return maxFade * math.clamp((distance - start) / (finish - start), 0, 1)
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
