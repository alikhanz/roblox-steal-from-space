--!strict
-- Where the HUD's bottom stack stands on a touch screen (docs/design/screens/hud-hint-room.md):
-- in the strip along the bottom between Roblox's movement stick at rest and the flight buttons,
-- so the tutorial's line and the hints neither hide under the stick's ring nor run over the
-- buttons. The line wraps to the strip's width.
--
-- Pure Luau: sizes come in as numbers. Pixels are the HUD's own (its ScreenGui, inside the safe
-- area); points are the reference screen's, which the HUD's UIScale `scale` turns into pixels.

-- Roblox's dynamic thumbstick at rest (PlayerModule, DynamicThumbstick): its ring's centre stands
-- 3.3 ring sizes (20) from the left and the ring is 74 across, so its right edge is at 103 pixels;
-- everything is twice as big on a screen whose shorter side is over 500 pixels.
local STICK_RING_RIGHT = 20 * 3.3 + 74 / 2
local BIG_SCREEN_SIDE = 500
local BIG_SCREEN_FACTOR = 2

export type Strip = {
	-- The strip's middle, pixels from the HUD's left edge.
	centre: number,
	-- Its width, points.
	width: number,
}

export type Spec = {
	-- The HUD's size, pixels.
	screenWidth: number,
	screenHeight: number,
	-- The HUD's scale: pixels in a point.
	scale: number,
	-- The least room from the screen's left edge, points.
	edge: number,
	-- How far from the screen's right edge the flight buttons reach, points.
	flightReach: number,
	-- The gap kept to the stick's ring and to the flight buttons, points.
	clearance: number,
}

local HintStrip = {}

-- The right edge of the stick's ring at rest, pixels.
function HintStrip.stickRight(screenWidth: number, screenHeight: number): number
	local big = math.min(screenWidth, screenHeight) > BIG_SCREEN_SIDE
	return STICK_RING_RIGHT * (if big then BIG_SCREEN_FACTOR else 1)
end

function HintStrip.of(spec: Spec): Strip
	assert(spec.scale > 0, "the HUD's scale is positive")
	local left = math.max(
		spec.edge * spec.scale,
		HintStrip.stickRight(spec.screenWidth, spec.screenHeight) + spec.clearance * spec.scale
	)
	local right = spec.screenWidth - (spec.flightReach + spec.clearance) * spec.scale
	return {
		centre = (left + right) / 2,
		width = math.max(right - left, 0) / spec.scale,
	}
end

return table.freeze(HintStrip)
