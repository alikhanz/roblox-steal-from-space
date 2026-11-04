--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The frame every menu window shares: a panel in the middle of the screen with a title, a few
-- hint lines under it, a close button and a scrolling list for the window's own rows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local PADDING = 16
local GAP = 10
local TITLE_TEXT_SIZE = 24
local HINT_TEXT_SIZE = 14
local CLOSE_SIZE = 36

export type Props = {
	name: string,
	visible: () -> boolean,
	title: string,
	-- Lines under the title, top first.
	hints: { string | () -> string },
	maxSize: Vector2,
	onClose: () -> (),
	-- The rows of the list (a Vide `indexes` result or plain instances).
	rows: any,
}

local function Window(props: Props): Frame
	local hints = {}
	for index, hint in props.hints do
		table.insert(
			hints,
			create("TextLabel")({
				Name = `Hint{index}`,
				Position = UDim2.fromOffset(0, CLOSE_SIZE + GAP + (index - 1) * (HINT_TEXT_SIZE + GAP)),
				Size = UDim2.new(1, 0, 0, HINT_TEXT_SIZE),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = HINT_TEXT_SIZE,
				TextColor3 = Theme.MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = hint,
			})
		)
	end
	local headerHeight = CLOSE_SIZE + #props.hints * (HINT_TEXT_SIZE + GAP) + GAP

	return create("Frame")({
		Name = props.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.88),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0.05,
		Visible = props.visible,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.maxSize(props.maxSize.X, props.maxSize.Y),
		Layout.padding(PADDING, PADDING),

		create("TextLabel")({
			Name = "Title",
			Size = UDim2.new(1, -CLOSE_SIZE, 0, CLOSE_SIZE),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = TITLE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = props.title,
		}),
		hints,
		create("TextButton")({
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
			BackgroundColor3 = Theme.DANGER,
			FontFace = Theme.FONT,
			TextSize = TITLE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			Text = "×",
			Activated = function()
				props.onClose()
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),

		create("ScrollingFrame")({
			Name = "Rows",
			Position = UDim2.fromOffset(0, headerHeight),
			Size = UDim2.new(1, 0, 1, -headerHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Layout.padding(GAP),
			props.rows,
		}),
	}) :: Frame
end

return Window
