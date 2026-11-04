--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The way home: a "Station" sign with the distance, drawn over the dome while it is in view and
-- pinned to the screen edge with an arrow towards it when it is not. Screen space, so it shows
-- from any distance and does not depend on the station streaming in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local SIGN_SIZE = UDim2.fromOffset(140, 52)
local ARROW_SIZE = 28
local DISTANCE_TEXT_SIZE = 16
-- The arrow glyph points right; GuiObject.Rotation turns it.
local ARROW_GLYPH = "▶"

export type Props = {
	title: string,
	distance: () -> string,
	visible: () -> boolean,
	-- Where the sign's center goes, pixels from the top left of the screen.
	signPosition: () -> Vector2,
	-- The arrow: shown only while the station is off screen.
	arrowVisible: () -> boolean,
	arrowPosition: () -> Vector2,
	arrowAngle: () -> number,
}

local function at(position: () -> Vector2): () -> UDim2
	return function()
		local point = position()
		return UDim2.fromOffset(point.X, point.Y)
	end
end

local function StationBeacon(props: Props): ScreenGui
	return create("ScreenGui")({
		Name = "StationBeacon",
		ResetOnSpawn = false,
		-- Viewport coordinates from the camera start at the very top of the screen.
		IgnoreGuiInset = true,
		Enabled = props.visible,

		create("Frame")({
			Name = "Sign",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = SIGN_SIZE,
			Position = at(props.signPosition),
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
				TextColor3 = Theme.OXYGEN,
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
				Text = props.distance,
			}),
		}),

		create("TextLabel")({
			Name = "Arrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
			Position = at(props.arrowPosition),
			Rotation = props.arrowAngle,
			Visible = props.arrowVisible,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = ARROW_SIZE,
			TextColor3 = Theme.OXYGEN,
			TextStrokeTransparency = 0.3,
			Text = ARROW_GLYPH,
		}),
	}) :: ScreenGui
end

return StationBeacon
