--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The jetpack shop window: one row per jetpack level, from the starter up. The owned one is
-- marked, the next one has a buy button, the rest wait. Texts come in resolved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local MAX_WIDTH = 520
local MAX_HEIGHT = 560
local PADDING = 16
local GAP = 10
local ROW_HEIGHT = 56
local ROW_PADDING = 10
local SWATCH_SIZE = 32
local TITLE_TEXT_SIZE = 24
local HINT_TEXT_SIZE = 14
local SMALL_TEXT_SIZE = 14
local CLOSE_SIZE = 36
local HEADER_HEIGHT = CLOSE_SIZE + HINT_TEXT_SIZE + GAP * 2

export type Row = {
	level: number,
	name: string,
	-- "⚡ ×8"
	multiplier: string,
	color: Color3,
	-- Past: already outgrown; Owned: the current one; Next: buyable; Locked: later.
	state: "Past" | "Owned" | "Next" | "Locked",
	-- The buy button's text for the next level.
	price: string,
}

export type Texts = {
	title: string,
	hint: string,
	past: string,
	owned: string,
	locked: string,
}

local STATE_TEXT: { [string]: (texts: Texts) -> string } = {
	Past = function(texts)
		return texts.past
	end,
	Owned = function(texts)
		return texts.owned
	end,
	Locked = function(texts)
		return texts.locked
	end,
}

export type Props = {
	visible: () -> boolean,
	rows: () -> { Row },
	texts: Texts,
	canBuy: () -> boolean,
	onBuy: () -> (),
	onClose: () -> (),
}

local function ShopWindow(props: Props): Frame
	local texts = props.texts

	local function row(entry: () -> Row, order: number): Frame
		local function state(): string
			return entry().state
		end
		return create("Frame")({
			Name = "Row",
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = function()
				return if state() == "Owned" then Theme.SELECTED else Theme.PANEL
			end,
			BackgroundTransparency = function()
				return if state() == "Locked" or state() == "Past" then Theme.PANEL_TRANSPARENCY else 0
			end,
			create("UICorner")({ CornerRadius = Theme.CORNER }),
			Layout.stroke(Theme.ACCENT, 2, function()
				return state() == "Owned"
			end),
			Layout.padding(ROW_PADDING, ROW_PADDING),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			create("Frame")({
				Name = "Swatch",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE),
				BackgroundColor3 = function()
					return entry().color
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
			create("Frame")({
				Name = "Lines",
				LayoutOrder = 2,
				Size = UDim2.new(0.5, -(SWATCH_SIZE + GAP), 1, 0),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("TextLabel")({
					Name = "Name",
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = Theme.TEXT_SIZE,
					TextColor3 = Theme.TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						return entry().name
					end,
				}),
				create("TextLabel")({
					Name = "Multiplier",
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = SMALL_TEXT_SIZE,
					TextColor3 = Theme.SPEED,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						return entry().multiplier
					end,
				}),
			}),
			create("TextLabel")({
				Name = "State",
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SMALL_TEXT_SIZE,
				TextColor3 = Theme.MUTED,
				TextXAlignment = Enum.TextXAlignment.Right,
				Visible = function()
					return state() ~= "Next"
				end,
				Text = function()
					local describe = STATE_TEXT[state()]
					return if describe then describe(texts) else ""
				end,
			}),
			create("Frame")({
				Name = "BuySlot",
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				Visible = function()
					return state() == "Next"
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Button({
					name = "Buy",
					text = function()
						return entry().price
					end,
					enabled = props.canBuy,
					color = Theme.COINS_DARK,
					onClick = props.onBuy,
				}),
			}),
		}) :: Frame
	end

	local rows = indexes(props.rows, row)

	return create("Frame")({
		Name = "ShopWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.88),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0.05,
		Visible = props.visible,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.maxSize(MAX_WIDTH, MAX_HEIGHT),
		Layout.padding(PADDING, PADDING),

		create("TextLabel")({
			Name = "Title",
			Size = UDim2.new(1, -CLOSE_SIZE, 0, CLOSE_SIZE),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = TITLE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = texts.title,
		}),
		create("TextLabel")({
			Name = "Hint",
			Position = UDim2.fromOffset(0, CLOSE_SIZE + GAP),
			Size = UDim2.new(1, 0, 0, HINT_TEXT_SIZE),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = HINT_TEXT_SIZE,
			TextColor3 = Theme.MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = texts.hint,
		}),
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
			Position = UDim2.fromOffset(0, HEADER_HEIGHT),
			Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
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
			rows,
		}),
	}) :: Frame
end

return ShopWindow
