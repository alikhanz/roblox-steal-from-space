--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Oxygen tank bar at the bottom of the screen, with a warning above it when the tank runs low.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local BAR_SIZE = UDim2.fromOffset(320, 22)
local WARNING_GAP = 8
local LABEL_GAP = 10

export type Props = {
	-- Share of a full tank, 0..1.
	fraction: () -> number,
	isLow: () -> boolean,
	visible: () -> boolean,
	warningText: string,
}

local function OxygenBar(props: Props): Frame
	return create("Frame")({
		Name = "OxygenBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.MARGIN),
		Size = BAR_SIZE,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
		Visible = props.visible,

		create("UICorner")({ CornerRadius = Theme.CORNER }),

		create("Frame")({
			Name = "Fill",
			BorderSizePixel = 0,
			Size = function()
				return UDim2.fromScale(props.fraction(), 1)
			end,
			BackgroundColor3 = function()
				return if props.isLow() then Theme.DANGER else Theme.OXYGEN
			end,
			create("UICorner")({ CornerRadius = Theme.CORNER }),
		}),

		create("TextLabel")({
			Name = "Label",
			-- Sits left of the bar so it stays readable over any fill level.
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0, -LABEL_GAP, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.OXYGEN,
			TextStrokeTransparency = 0.4,
			Text = "O₂",
		}),

		create("TextLabel")({
			Name = "Warning",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -WARNING_GAP),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.DANGER,
			TextStrokeTransparency = 0.4,
			Text = props.warningText,
			Visible = props.isLow,
		}),
	}) :: Frame
end

return OxygenBar
