--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The next speed goal under the speed stat: the guardian to grow towards, the stat now against
-- the one it needs, and a bar of the way there (Domain/SpeedGoal). Styled like StatBadge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local PADDING = 12
local GAP = 4
local VALUE_TEXT_SIZE = 20
local BAR_SIZE = Vector2.new(200, 6)

export type Props = {
	name: string,
	-- "Next: Snow Crab".
	title: () -> string,
	-- "85K / 121K".
	value: () -> string,
	-- 0..1 of the way to the goal.
	progress: () -> number,
	color: Color3,
	layoutOrder: number,
	visible: () -> boolean,
}

local function GoalBadge(props: Props): Frame
	return create("Frame")({
		Name = props.name,
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
		Visible = props.visible,

		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(PADDING, PADDING / 2),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			Text = props.title,
		}),
		create("TextLabel")({
			Name = "Value",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = VALUE_TEXT_SIZE,
			TextColor3 = props.color,
			Text = function()
				return `⚡ {props.value()}`
			end,
		}),
		create("Frame")({
			Name = "Bar",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
			BackgroundColor3 = Theme.TEXT,
			BackgroundTransparency = 0.8,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(math.clamp(props.progress(), 0, 1), 1)
				end,
				BackgroundColor3 = props.color,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
	}) :: Frame
end

return GoalBadge
