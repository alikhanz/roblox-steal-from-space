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

-- A rectangle on the screen, pixels.
export type Rect = {
	read left: number,
	read top: number,
	read right: number,
	read bottom: number,
}

-- Where markers may stand. A point inside `bounds` is in view; one outside is pinned on the way
-- from `center` (the crosshair) towards it, at the bounds, or nearer the center if that spot falls
-- on one of `keepOut` (the HUD: docs/design/screens/markers.md). It never comes nearer the center
-- than `minReach` of the way to the bounds: past that, it may cover the HUD.
export type Area = {
	read centerX: number,
	read centerY: number,
	read bounds: Rect,
	read keepOut: { Rect },
	read minReach: number,
}

-- How far along the ray center + t * (dx, dy) it enters `rect`, and how far it leaves; nil when it
-- misses it.
local function crossing(area: Area, dx: number, dy: number, rect: Rect): (number?, number)
	local enter, leave = -math.huge, math.huge
	for _, axis in { { area.centerX, dx, rect.left, rect.right }, { area.centerY, dy, rect.top, rect.bottom } } do
		local origin, step, low, high = axis[1], axis[2], axis[3], axis[4]
		if math.abs(step) < 1e-9 then
			if origin < low or origin > high then
				return nil, 0
			end
		else
			local a, b = (low - origin) / step, (high - origin) / step
			enter = math.max(enter, math.min(a, b))
			leave = math.min(leave, math.max(a, b))
		end
	end
	if enter > leave then
		return nil, 0
	end
	return enter, leave
end

-- Where the marker for a viewport point goes in `area` (see Area).
function ScreenMarker.placeIn(x: number, y: number, depth: number, area: Area): Placement
	local bounds = area.bounds
	local centerX, centerY = area.centerX, area.centerY
	local inFront = depth > 0
	local inside = x >= bounds.left and x <= bounds.right and y >= bounds.top and y <= bounds.bottom
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
	local function reach(step: number, low: number, high: number, origin: number): number
		if step > 1e-6 then
			return math.max(high - origin, 0) / step
		elseif step < -1e-6 then
			return math.max(origin - low, 0) / -step
		end
		return math.huge
	end
	local edge = math.min(reach(dx, bounds.left, bounds.right, centerX), reach(dy, bounds.top, bounds.bottom, centerY))
	local t = edge
	-- Step back out of every HUD block the spot falls on; each step only goes inwards, so a
	-- pass per block is enough.
	for _ = 1, #area.keepOut do
		local moved = false
		for _, rect in area.keepOut do
			local enter, leave = crossing(area, dx, dy, rect)
			if enter and enter > 0 and t >= enter and t <= leave then
				t = enter
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	t = math.max(t, edge * area.minReach)
	return {
		x = centerX + dx * t,
		y = centerY + dy * t,
		onScreen = false,
		angle = math.deg(math.atan2(dy, dx)),
	}
end

-- The whole screen less `margin` at every side, nothing kept out.
function ScreenMarker.areaOf(screen: Screen): Area
	local margin = screen.margin
	return {
		centerX = screen.width / 2,
		centerY = screen.height / 2,
		bounds = { left = margin, top = margin, right = screen.width - margin, bottom = screen.height - margin },
		keepOut = {},
		minReach = 0,
	}
end

function ScreenMarker.place(x: number, y: number, depth: number, screen: Screen): Placement
	return ScreenMarker.placeIn(x, y, depth, ScreenMarker.areaOf(screen))
end

export type Point = {
	x: number,
	y: number,
}

-- Moves signs of `width` × `height` (by their centers) apart so that none covers another. They
-- are laid down in the given order: the first stays where it is, each next one steps by its
-- height towards the middle of the screen (down in the top half, up in the bottom one) until it
-- is clear of those before it.
function ScreenMarker.separate(points: { Point }, width: number, height: number, screen: Screen): { Point }
	local placed: { Point } = {}
	for _, point in points do
		local step = if point.y < screen.height / 2 then height else -height
		local y = point.y
		local moved = true
		while moved do
			moved = false
			for _, other in placed do
				if math.abs(other.x - point.x) < width and math.abs(other.y - y) < height then
					-- Past the sign it touches; y only goes one way, so this ends.
					y = other.y + step
					moved = true
				end
			end
		end
		table.insert(placed, { x = point.x, y = y })
	end
	return placed
end

return table.freeze(ScreenMarker)
