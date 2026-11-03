--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The speed stat in the top-left corner: the player's one number to grow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local PADDING = 12
local GAP = 8
local VALUE_TEXT_SIZE = 24

export type Props = {
	title: string,
	-- Formatted stat, e.g. "1.5K".
	value: () -> string,
}

-- Vide's instance types do not list UIPadding, so it is made directly.
local function padding(horizontal: number, vertical: number): UIPadding
	local instance = Instance.new("UIPadding")
	instance.PaddingLeft = UDim.new(0, horizontal)
	instance.PaddingRight = UDim.new(0, horizontal)
	instance.PaddingTop = UDim.new(0, vertical)
	instance.PaddingBottom = UDim.new(0, vertical)
	return instance
end

local function label(name: string, order: number, size: number, color: Color3, text: string | () -> string): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = size,
		TextColor3 = color,
		Text = text,
	}) :: TextLabel
end

local function SpeedBadge(props: Props): Frame
	return create("Frame")({
		Name = "SpeedBadge",
		Position = UDim2.fromOffset(Theme.MARGIN, Theme.MARGIN),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,

		create("UICorner")({ CornerRadius = Theme.CORNER }),
		padding(PADDING, PADDING / 2),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		label("Title", 1, Theme.TEXT_SIZE, Theme.TEXT, props.title),
		label("Value", 2, VALUE_TEXT_SIZE, Theme.SPEED, function()
			return `⚡ {props.value()}`
		end),
	}) :: Frame
end

return SpeedBadge
