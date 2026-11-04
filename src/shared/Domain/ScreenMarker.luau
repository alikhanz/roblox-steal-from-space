--!strict
-- Where on screen to draw a marker for a point in the world: right over it while it is in view,
-- otherwise pinned to the screen edge on the side the point lies, with the angle to turn an
-- arrow towards it. Pure and in plain numbers: takes the viewport point the camera gives
-- (Camera:WorldToViewportPoint: X and Y in pixels, Z the depth, negative behind the camera).

local ScreenMarker = {}

export type Screen = {
	read width: number,
	read height: number,
	-- Distance from the screen edge where pinned markers sit; a point closer to the edge than
	-- this counts as off screen, pixels.
	read margin: number,
}

export type Placement = {
	x: number,
	y: number,
	onScreen: boolean,
	-- Direction from the screen center to the point, degrees clockwise from "right"
	-- (the GuiObject.Rotation of an arrow drawn pointing right).
	angle: number,
}

function ScreenMarker.place(x: number, y: number, depth: number, screen: Screen): Placement
	local margin = screen.margin
	local centerX, centerY = screen.width / 2, screen.height / 2
	local inFront = depth > 0
	local inside = x >= margin and x <= screen.width - margin and y >= margin and y <= screen.height - margin
	local dx, dy = x - centerX, y - centerY
	if inFront and inside then
		return { x = x, y = y, onScreen = true, angle = math.deg(math.atan2(dy, dx)) }
	end

	-- A point behind the camera projects mirrored through the center.
	if not inFront then
		dx, dy = -dx, -dy
	end
	-- Straight behind: point down, towards "turn around".
	if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then
		dx, dy = 0, 1
	end
	local halfWidth = math.max(centerX - margin, 0)
	local halfHeight = math.max(centerY - margin, 0)
	local scaleX = if math.abs(dx) > 1e-6 then halfWidth / math.abs(dx) else math.huge
	local scaleY = if math.abs(dy) > 1e-6 then halfHeight / math.abs(dy) else math.huge
	local scale = math.min(scaleX, scaleY)
	return {
		x = centerX + dx * scale,
		y = centerY + dy * scale,
		onScreen = false,
		angle = math.deg(math.atan2(dy, dx)),
	}
end

return table.freeze(ScreenMarker)
