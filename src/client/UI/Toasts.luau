--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Short messages stacked at the top of the screen: a hatch, a refused command.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local TOP_OFFSET = 72
local GAP = 6
local PADDING = 12
local MAX_WIDTH = 420

export type Toast = {
	id: number,
	text: string,
	color: Color3,
}

export type Props = {
	toasts: () -> { Toast },
}

local function Toasts(props: Props): Frame
	return create("Frame")({
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		indexes(props.toasts, function(toast: () -> Toast, index: number)
			return create("Frame")({
				Name = "Toast",
				LayoutOrder = index,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = function()
					return toast().color
				end,
				create("UICorner")({ CornerRadius = Theme.CORNER }),
				Layout.padding(PADDING, PADDING / 2),
				-- Amounts of coins and ⚡ show their icons (Locale/Marks).
				IconText({
					name = "Text",
					text = function()
						return toast().text
					end,
					textSize = Theme.TEXT_SIZE,
					color = Theme.TEXT,
					font = Theme.FONT,
					wrapWidth = MAX_WIDTH - 2 * PADDING,
				}),
			})
		end),
	}) :: Frame
end

return Toasts
