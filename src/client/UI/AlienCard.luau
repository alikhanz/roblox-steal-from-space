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
	-- The guardian's name; nil shows an empty slot with `emptyText`.
	title: () -> string?,
	-- Tier and income.
	subtitle: () -> string,
	color: () -> Color3,
	selected: () -> boolean,
	-- Faded: not a crossbreed match for the current selection. Still tappable.
	dimmed: () -> boolean,
	emptyText: string,
	onTap: () -> (),
}

local DIMMED_TRANSPARENCY = 0.6

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
			if not hasAlien() then
				return Theme.PANEL_TRANSPARENCY
			end
			return if props.dimmed() then DIMMED_TRANSPARENCY else 0
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
			BackgroundTransparency = function()
				return if props.dimmed() then DIMMED_TRANSPARENCY else 0
			end,
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
				TextSize = Theme.TEXT_SIZE,
				TextColor3 = Theme.TEXT,
				TextTransparency = function()
					return if props.dimmed() then DIMMED_TRANSPARENCY else 0
				end,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = function()
					return props.title() or props.emptyText
				end,
			}),
			create("TextLabel")({
				Name = "Subtitle",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SMALL_TEXT_SIZE,
				TextColor3 = Theme.COINS,
				TextTransparency = function()
					return if props.dimmed() then DIMMED_TRANSPARENCY else 0
				end,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Visible = hasAlien,
				Text = props.subtitle,
			}),
		}),
	}) :: TextButton
end

return AlienCard
