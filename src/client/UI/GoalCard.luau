--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The speed goal under the resources (DESIGN.md, "Цель роста"): the guardian to grow towards,
-- a bar of the way there, the stat against the one it needs, and the way to more ⚡.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoalBar = require(script.Parent.GoalBar)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local WIDTH = 211
local PADDING = 9
local BAR_HEIGHT = 11
local ICON_SIZE = 15
-- The last row: the stat against the goal on the left, the button on the right.
local ROW_HEIGHT = 20

export type Props = {
	-- "Next: Ice Worm".
	title: () -> string,
	-- "178K / 412K".
	value: () -> string,
	-- 0..1 of the way to the goal.
	progress: () -> number,
	-- The "More ⚡" button, or nil where nothing is sold.
	more: Instance?,
	layoutOrder: number,
	visible: () -> boolean,
}

local function GoalCard(props: Props): Frame
	return create("Frame")({
		Name = "Goal",
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = NEON.GLASS,
		BackgroundTransparency = NEON.GLASS_TRANSPARENCY,
		Visible = props.visible,

		create("UICorner")({ CornerRadius = NEON.CORNER }),
		Layout.panelLine(),
		Layout.padding(PADDING, PADDING),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, NEON.TEXT_BODY),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = NEON.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = props.title,
			Layout.textStroke(),
		}),
		GoalBar({ progress = props.progress, height = BAR_HEIGHT, layoutOrder = 2 }),
		create("Frame")({
			Name = "Row",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			create("ImageLabel")({
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				BackgroundTransparency = 1,
				Image = Icons.ICONS.Bolt,
				ImageColor3 = NEON.SPEED,
			}),
			create("TextLabel")({
				Name = "Value",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, ICON_SIZE + 3, 0.5, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, NEON.TEXT_SMALL),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SMALL + 1,
				TextColor3 = NEON.TEXT,
				Text = props.value,
				Layout.textStroke(),
			}),
			create("Frame")({
				Name = "MoreSlot",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				props.more,
			}),
		}),
	}) :: Frame
end

return GoalCard
