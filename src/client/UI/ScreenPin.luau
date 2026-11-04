--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A pin on the screen for a place in the world: a sign with a name and a distance, drawn over
-- the place while it is in view and held at the screen edge with an arrow towards it when it is
-- not (Domain/ScreenMarker). Screen space, so it shows from any distance and does not depend on
-- the place streaming in. The station beacon and event markers are pins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenMarker = require(ReplicatedStorage.Shared.Domain.ScreenMarker)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

-- Room for the longest title (a zone name) and the distance under it, pixels.
local SIGN_SIZE = Vector2.new(220, 52)
local ARROW_SIZE = 28
local DISTANCE_TEXT_SIZE = 16
-- The arrow glyph points right; GuiObject.Rotation turns it.
local ARROW_GLYPH = "▶"
-- Distance of the arrow from the screen edge, pixels.
local EDGE_MARGIN = 40
-- The sign stands this far inwards from the arrow, pixels.
local SIGN_FROM_ARROW = 56
-- While the place is in view the sign floats this far above it, pixels.
local SIGN_ABOVE_POINT = 30
-- The distance shown is rounded to this many studs.
local DISTANCE_STEP = 10

export type ViewProps = {
	name: string,
	title: string | () -> string,
	color: Color3,
}

-- Where a pin goes on screen this frame: its sign, and the arrow at the edge if the place is not
-- in view.
export type Location = {
	sign: Vector2,
	arrow: Vector2?,
	angle: number,
}

export type Pin = {
	-- The pin's ScreenGui, to mount once.
	view: (props: ViewProps) -> ScreenGui,
	-- Shows the pin at world `point` for this frame, with `distance` under the title.
	place: (camera: Camera, point: Vector3, distance: string) -> (),
	-- The same, at a location from `ScreenPin.locate` (moved, to keep pins from covering each
	-- other).
	show: (location: Location, distance: string) -> (),
	hide: () -> (),
}

local ScreenPin = {}

ScreenPin.SIGN_SIZE = SIGN_SIZE

-- The screen pins are kept on.
function ScreenPin.screenOf(camera: Camera): ScreenMarker.Screen
	local viewport = camera.ViewportSize
	return { width = viewport.X, height = viewport.Y, margin = EDGE_MARGIN }
end

-- Where the pin for world `point` goes on screen (Domain/ScreenMarker).
function ScreenPin.locate(camera: Camera, point: Vector3): Location
	local viewportPoint = camera:WorldToViewportPoint(point)
	local placement = ScreenMarker.place(viewportPoint.X, viewportPoint.Y, viewportPoint.Z, ScreenPin.screenOf(camera))
	local position = Vector2.new(placement.x, placement.y)
	if placement.onScreen then
		return { sign = position - Vector2.new(0, SIGN_ABOVE_POINT), arrow = nil, angle = placement.angle }
	end
	local radians = math.rad(placement.angle)
	local towards = Vector2.new(math.cos(radians), math.sin(radians))
	return { sign = position - towards * SIGN_FROM_ARROW, arrow = position, angle = placement.angle }
end

-- "120 m": the distance, rounded so it does not flicker every frame.
function ScreenPin.distanceText(locale: Text.Locale, studs: number): string
	local shown = math.max(math.floor(studs / DISTANCE_STEP + 0.5) * DISTANCE_STEP, DISTANCE_STEP)
	return Text.get(locale, "marker.distance.hint", { distance = shown })
end

local function at(position: () -> Vector2): () -> UDim2
	return function()
		local point = position()
		return UDim2.fromOffset(point.X, point.Y)
	end
end

function ScreenPin.new(): Pin
	local visible = source(false)
	local distance = source("")
	local signPosition = source(Vector2.zero)
	local arrowVisible = source(false)
	local arrowPosition = source(Vector2.zero)
	local arrowAngle = source(0)

	local function show(location: Location, distanceText: string)
		visible(true)
		if distanceText ~= distance() then
			distance(distanceText)
		end
		signPosition(location.sign)
		local arrow = location.arrow
		arrowVisible(arrow ~= nil)
		if arrow then
			arrowPosition(arrow)
			arrowAngle(location.angle)
		end
	end

	local function place(camera: Camera, point: Vector3, distanceText: string)
		show(ScreenPin.locate(camera, point), distanceText)
	end

	local function view(props: ViewProps): ScreenGui
		return create("ScreenGui")({
			Name = props.name,
			ResetOnSpawn = false,
			-- Viewport coordinates from the camera start at the very top of the screen.
			IgnoreGuiInset = true,
			Enabled = visible,

			create("Frame")({
				Name = "Sign",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(SIGN_SIZE.X, SIGN_SIZE.Y),
				Position = at(signPosition),
				BackgroundTransparency = 1,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("TextLabel")({
					Name = "Title",
					LayoutOrder = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = Theme.TEXT_SIZE,
					TextColor3 = props.color,
					TextStrokeTransparency = 0.3,
					Text = props.title,
				}),
				create("TextLabel")({
					Name = "Distance",
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = DISTANCE_TEXT_SIZE,
					TextColor3 = Theme.TEXT,
					TextStrokeTransparency = 0.3,
					Text = distance,
				}),
			}),

			create("TextLabel")({
				Name = "Arrow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
				Position = at(arrowPosition),
				Rotation = arrowAngle,
				Visible = arrowVisible,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = ARROW_SIZE,
				TextColor3 = props.color,
				TextStrokeTransparency = 0.3,
				Text = ARROW_GLYPH,
			}),
		}) :: ScreenGui
	end

	return {
		view = view,
		place = place,
		show = show,
		hide = function()
			visible(false)
		end,
	}
end

return table.freeze(ScreenPin)
