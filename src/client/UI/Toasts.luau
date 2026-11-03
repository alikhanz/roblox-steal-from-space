--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Short messages stacked at the top of the screen: a hatch, a refused command.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
			return create("TextLabel")({
				Name = "Toast",
				LayoutOrder = index,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = function()
					return toast().color
				end,
				FontFace = Theme.FONT,
				TextSize = Theme.TEXT_SIZE,
				TextColor3 = Theme.TEXT,
				TextWrapped = true,
				Text = function()
					return toast().text
				end,
				create("UICorner")({ CornerRadius = Theme.CORNER }),
				Layout.maxSize(MAX_WIDTH, math.huge),
				Layout.padding(PADDING, PADDING / 2),
			})
		end),
	}) :: Frame
end

return Toasts
