--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- One alien in a bay window list (docs/design/screens/bay-window.md): its icon
-- (docs/design/screens/alien-icons.md), a badge for a variant (meteor), its name, the income on
-- the right, an outline in its tier's colour. A tap
-- toggles its selection: a pink frame around the row (the outline stays the tier's, so the frame
-- sits on a wrapper: one object takes one stroke). Faded when it cannot join the crossbreed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AlienPicture = require(script.Parent.AlienPicture)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Press = require(script.Parent.Press)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local HEIGHT = 32
local INNER_CORNER = UDim.new(0, 9)
local OUTER_CORNER = UDim.new(0, 11)
local PADDING_X = 10
local ICON_SIZE = 15
local VARIANT_SIZE = 17
local PICTURE_SIZE = 26
local GAP = 5
-- Room kept for the income's number and the gaps, points.
local INCOME_TEXT_ROOM = 70
local FILL_TRANSPARENCY = 0.965
-- How far the tier's outline goes towards the glass, and its thickness.
local TIER_LINE_DARKEN = 0.28
local ROW_PRESS_SHARE = 0.5
local DIMMED_TRANSPARENCY = 0.55
local METEOR_COLOR = Color3.fromHex("#FFA060")

export type Props = {
	layoutOrder: number,
	name: () -> string,
	-- "8.5/s".
	income: () -> string,
	tierColor: () -> Color3,
	-- Its kind's icon at its tier; nil while its guardian has no sheet (the ball stands in).
	icon: () -> AlienIcons.Icon?,
	-- A badge before the name for a variant alien; nil for a regular one.
	variant: () -> Icons.Name?,
	selected: () -> boolean,
	dimmed: () -> boolean,
	-- In the inventory: it earns nothing yet, so the income is grey.
	idle: boolean,
	onTap: () -> (),
}

local function AlienRow(props: Props): TextButton
	local press = Press.new({ shrinks = true })
	local readVariant = props.variant :: () -> Icons.Name?
	local pressScale = Instance.new("UIScale")
	local selectionLine = Instance.new("UIStroke")
	selectionLine.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	selectionLine.Color = NEON.SELECTED
	selectionLine.Thickness = 2
	local tierLine = Instance.new("UIStroke")
	tierLine.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tierLine.Thickness = 2
	Vide.effect(function()
		-- Half the press's dip and pop: a whole row shrinking as much as a tile looks like a jump.
		pressScale.Scale = 1 + (press.scale() - 1) * ROW_PRESS_SHARE
		selectionLine.Enabled = props.selected()
		tierLine.Color = props.tierColor():Lerp(NEON.GLASS, TIER_LINE_DARKEN)
		tierLine.Transparency = if props.dimmed() then DIMMED_TRANSPARENCY else 0
	end)
	local function textTransparency(): number
		return if props.dimmed() then DIMMED_TRANSPARENCY else 0
	end

	return create("TextButton")({
		Name = "AlienRow",
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			props.onTap()
		end,
		press.action,
		create("UICorner")({ CornerRadius = OUTER_CORNER }),
		selectionLine,
		Layout.padding(2, 2),

		-- The row inside shrinks on a press; its place in the list stays, so the rows below do
		-- not move.
		create("Frame")({
			Name = "Row",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			pressScale,
			BackgroundColor3 = function()
				return if props.selected() then NEON.SELECTED else Color3.new(1, 1, 1)
			end,
			BackgroundTransparency = function()
				return if props.selected() then 0.88 else FILL_TRANSPARENCY
			end,
			create("UICorner")({ CornerRadius = INNER_CORNER }),
			tierLine,
			Layout.padding(PADDING_X, 0),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("Frame")({
				Name = "Picture",
				LayoutOrder = 0,
				Size = UDim2.fromOffset(PICTURE_SIZE, PICTURE_SIZE),
				BackgroundTransparency = 1,
				AlienPicture({
					icon = props.icon,
					color = props.tierColor,
					transparency = textTransparency,
				}),
			}),
			create("ImageLabel")({
				Name = "Variant",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(VARIANT_SIZE, VARIANT_SIZE),
				BackgroundTransparency = 1,
				Image = function()
					local variant = readVariant()
					return if variant then Icons.ICONS[variant] else ""
				end,
				ImageColor3 = METEOR_COLOR,
				ImageTransparency = textTransparency,
				Visible = function()
					return readVariant() ~= nil
				end,
			}),
			create("TextLabel")({
				Name = "Name",
				LayoutOrder = 2,
				-- Takes what is left of the row; a long name ends in an ellipsis.
				Size = UDim2.new(1, -(PICTURE_SIZE + GAP + VARIANT_SIZE + ICON_SIZE + INCOME_TEXT_ROOM), 1, 0),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.TEXT,
				TextTransparency = textTransparency,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = props.name,
				Layout.textStroke(),
			}),
			create("Frame")({
				Name = "Income",
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 3),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("ImageLabel")({
					Name = "Coin",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					BackgroundTransparency = 1,
					Image = Icons.ICONS.Coin,
					ImageColor3 = if props.idle then NEON.MUTED else NEON.COINS,
					ImageTransparency = textTransparency,
				}),
				create("TextLabel")({
					Name = "Value",
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_BODY,
					TextColor3 = if props.idle then NEON.MUTED else NEON.TEXT,
					TextTransparency = textTransparency,
					Text = props.income,
					Layout.textStroke(),
				}),
			}),
		}),
	}) :: TextButton
end

return AlienRow
