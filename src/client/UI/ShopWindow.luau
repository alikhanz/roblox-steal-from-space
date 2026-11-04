--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The jetpack shop window: one row per jetpack level, from the starter up. The owned one is
-- marked, the next one has a buy button, the rest wait. Texts come in resolved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Window = require(script.Parent.Window)

local create = Vide.create
local indexes = Vide.indexes

local MAX_SIZE = Vector2.new(520, 560)
local GAP = 10
local ROW_HEIGHT = 56
local ROW_PADDING = 10
local SWATCH_SIZE = 32
local SMALL_TEXT_SIZE = 14

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

	return Window({
		name = "ShopWindow",
		visible = props.visible,
		title = texts.title,
		hints = { texts.hint },
		maxSize = MAX_SIZE,
		onClose = props.onClose,
		rows = indexes(props.rows, row),
	})
end

return ShopWindow
