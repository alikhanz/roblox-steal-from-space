--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A chip over something small in the world (docs/design/screens/toasts-and-signs.md): one line
-- on a pill of dark glass, with a coloured dot or an icon in front. The income of an alien in
-- its pod (a dot of its tier's colour), the countdown of an egg (a clock), a newbie (a shield).
-- Constant size on screen, like the signs; amounts carry their marks (UI/IconText).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconText = require(script.Parent.IconText)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- Room for the widest chip, pixels; the pill itself is as wide as its line.
local SIZE = Vector2.new(220, 32)
local TEXT_SIZE = 16
local DOT_SIZE = 10
local ICON_SIZE = 18
local PADDING_X = 10
local PADDING_Y = 4
local GAP = 5
-- Glass a little denser than the HUD's: a chip stands over a busy scene.
local GLASS_TRANSPARENCY = 0.35
-- Chips fade out beyond this distance so the station is not covered in text, studs.
local DEFAULT_MAX_DISTANCE = 80

export type Props = {
	adornee: BasePart,
	text: string | () -> string,
	-- The line's colour; white when nil.
	color: (Color3 | () -> Color3)?,
	-- A dot in front (a tier's colour), or an icon (with its own colour).
	dot: Color3?,
	icon: Icons.Name?,
	iconColor: Color3?,
	-- The outline's colour; the plain line when nil.
	lineColor: Color3?,
	-- Height of the chip above the adornee's centre, studs.
	studsAbove: number,
	maxDistance: number?,
}

local function WorldChip(props: Props): BillboardGui
	local outline = Layout.panelLine()
	if props.lineColor then
		outline.Color = props.lineColor
		outline.Transparency = 0.3
	end
	return create("BillboardGui")({
		Name = "WorldChip",
		Adornee = props.adornee,
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		StudsOffset = Vector3.new(0, props.studsAbove, 0),
		MaxDistance = props.maxDistance or DEFAULT_MAX_DISTANCE,
		AlwaysOnTop = true,
		LightInfluence = 0,

		create("Frame")({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = NEON.GLASS,
			BackgroundTransparency = GLASS_TRANSPARENCY,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			outline,
			Layout.padding(PADDING_X, PADDING_Y),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			if props.dot
				then create("Frame")({
					Name = "Dot",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE),
					BackgroundColor3 = props.dot,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				})
				else nil,
			if props.icon
				then create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					BackgroundTransparency = 1,
					Image = Icons.ICONS[props.icon],
					ImageColor3 = props.iconColor or NEON.TEXT,
				})
				else nil,
			IconText({
				name = "Text",
				layoutOrder = 2,
				text = props.text,
				textSize = TEXT_SIZE,
				color = props.color or NEON.TEXT,
				outline = "Neon",
			}),
		}),
	}) :: BillboardGui
end

return WorldChip
