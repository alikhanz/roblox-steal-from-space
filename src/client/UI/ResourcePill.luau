--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A resource plaque of the HUD (DESIGN.md, "Плашка ресурса"): glass with a number and the
-- resource's icon sticking out over its left edge, tinted with the resource's colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- The icon, and how far it reaches out past the plaque's left edge.
local ICON_SIZE = 30
local ICON_OVERHANG = 14
local PADDING_X = 10
local PADDING_Y = 4

export type Props = {
	name: string,
	icon: Icons.Name,
	color: Color3,
	-- The number or short text, e.g. "178K" or "12 min".
	value: () -> string,
	layoutOrder: number,
	textSize: number?,
	visible: (() -> boolean)?,
}

local function ResourcePill(props: Props): Frame
	local textSize = props.textSize or NEON.TEXT_RESOURCE
	return create("Frame")({
		Name = props.name,
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, textSize + 2 * PADDING_Y),
		BackgroundColor3 = NEON.GLASS,
		BackgroundTransparency = NEON.GLASS_TRANSPARENCY,
		Visible = props.visible or true,

		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		Layout.panelLine(),
		Layout.padding(PADDING_X, 0),
		-- The icon's half that is inside the plaque is room left of the number.
		create("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -(ICON_OVERHANG + PADDING_X), 0.5, 0),
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			BackgroundTransparency = 1,
			Image = Icons.ICONS[props.icon],
			ImageColor3 = props.color,
		}),
		create("TextLabel")({
			Name = "Value",
			Position = UDim2.fromOffset(ICON_SIZE - ICON_OVERHANG - PADDING_X + 4, 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = textSize,
			TextColor3 = NEON.TEXT,
			Text = props.value,
			Layout.textStroke(),
		}),
	}) :: Frame
end

return ResourcePill
