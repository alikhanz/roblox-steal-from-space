--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The shop window: everything sold for Robux, one row each, with what it gives and its price on
-- the button (or why it cannot be bought now). Texts come in resolved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Window = require(script.Parent.Window)

local create = Vide.create

local MAX_SIZE = Vector2.new(560, 600)
local ROW_PADDING = 12
local GAP = 10
local BUY_WIDTH = 120
local BUY_HEIGHT = 40
local SMALL_TEXT_SIZE = 14

export type Row = {
	title: string,
	-- What it gives, right now.
	hint: () -> string,
	-- The button's text: the price.
	price: () -> string,
	-- The button is there; otherwise `status` is shown in its place.
	offered: () -> boolean,
	-- "Owned", or nothing.
	status: () -> string,
	onBuy: () -> (),
}

export type Props = {
	visible: () -> boolean,
	title: string,
	hint: string,
	rows: { Row },
	onClose: () -> (),
}

local function row(entry: Row, order: number): Frame
	return create("Frame")({
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PANEL,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(ROW_PADDING, ROW_PADDING),

		create("Frame")({
			Name = "Lines",
			Size = UDim2.new(1, -(BUY_WIDTH + GAP), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = Theme.TEXT_SIZE,
				TextColor3 = Theme.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = entry.title,
			}),
			create("TextLabel")({
				Name = "Hint",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SMALL_TEXT_SIZE,
				TextColor3 = Theme.MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = entry.hint,
			}),
		}),

		create("Frame")({
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(BUY_WIDTH, BUY_HEIGHT),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			create("Frame")({
				Name = "ButtonSlot",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Visible = entry.offered,
				Button({
					name = "BuyButton",
					text = entry.price,
					color = Theme.TOAST_GOOD,
					onClick = entry.onBuy,
				}),
			}),
			create("TextLabel")({
				Name = "Status",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SMALL_TEXT_SIZE,
				TextColor3 = Theme.TOAST_GOOD,
				TextXAlignment = Enum.TextXAlignment.Right,
				Visible = function()
					return not entry.offered()
				end,
				Text = entry.status,
			}),
		}),
	}) :: Frame
end

local function StoreWindow(props: Props): Frame
	local rows = {}
	for order, entry in props.rows do
		table.insert(rows, row(entry, order))
	end
	return Window({
		name = "StoreWindow",
		visible = props.visible,
		title = props.title,
		hints = { props.hint },
		maxSize = MAX_SIZE,
		onClose = props.onClose,
		rows = rows,
	})
end

return StoreWindow
