--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A card in the bay window: one alien (color of its tier, name, income) or an empty slot.
-- Tapping it toggles its selection, shown by an outline and a tinted background.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local SWATCH_SIZE = 28
local GAP = 8
local PADDING = 8
local SMALL_TEXT_SIZE = 14
local SELECTED_STROKE = 3

export type Props = {
	layoutOrder: number,
	-- Nil shows an empty slot with `emptyText`.
	title: () -> string?,
	income: () -> string,
	color: () -> Color3,
	selected: () -> boolean,
	emptyText: string,
	onTap: () -> (),
}

local function AlienCard(props: Props): TextButton
	local function hasAlien(): boolean
		return props.title() ~= nil
	end
	return create("TextButton")({
		Name = "AlienCard",
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = function()
			return if props.selected() then Theme.SELECTED else Theme.PANEL
		end,
		BackgroundTransparency = function()
			return if hasAlien() then 0 else Theme.PANEL_TRANSPARENCY
		end,
		Text = "",
		AutoButtonColor = hasAlien,
		Activated = function()
			if hasAlien() then
				props.onTap()
			end
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.stroke(Theme.ACCENT, SELECTED_STROKE, props.selected),
		Layout.padding(PADDING, PADDING),
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
			BackgroundColor3 = props.color,
			Visible = hasAlien,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("Frame")({
			Name = "Lines",
			LayoutOrder = 2,
			Size = UDim2.new(1, -(SWATCH_SIZE + GAP), 1, 0),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SMALL_TEXT_SIZE,
				TextColor3 = Theme.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = function()
					return props.title() or props.emptyText
				end,
			}),
			create("TextLabel")({
				Name = "Income",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SMALL_TEXT_SIZE,
				TextColor3 = Theme.COINS,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = hasAlien,
				Text = props.income,
			}),
		}),
	}) :: TextButton
end

return AlienCard
