--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- An action button of the neon style (DESIGN.md, "Кнопка действия"): a rounded pill of dense
-- coloured glass with a word on it. Lights up while pressed; a disabled one fades and does
-- nothing.
--
-- The press lights the glass instead of shrinking the button: the button fits its word, and a
-- size change would move its neighbours in a row (and a picture sized to the button inside a
-- button sized by its contents makes the size depend on itself).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local NEON = Theme.NEON
-- How far a pressed button's glass goes towards white.
local PRESSED_LIGHTEN = 0.3
-- A disabled button: how see-through its glass and its word get.
local DISABLED_TRANSPARENCY = 0.5
local PADDING_X = 10
-- Vertical padding by size: a large button is a big, easy target.
local PADDING_Y: { [string]: number } = { Small = 3, Normal = 5, Large = 9 }
local TEXT_SIZE: { [string]: number } = { Small = NEON.TEXT_SMALL, Normal = NEON.TEXT_BODY, Large = NEON.TEXT_SECTION }

export type Size = "Small" | "Normal" | "Large"

export type Props = {
	name: string,
	text: string | () -> string,
	-- What the press does (NEON.ACTION.*).
	color: Color3,
	onClick: () -> (),
	enabled: (() -> boolean)?,
	size: Size?,
	-- A share of its parent's width (the word centred); without it the button fits its word.
	width: number?,
	layoutOrder: number?,
	visible: (() -> boolean)?,
}

local function ActionButton(props: Props): TextButton
	local pressed = source(false)
	local size = props.size or "Normal"
	local textSize = TEXT_SIZE[size]
	local paddingY = PADDING_Y[size]
	local width = props.width
	local function isEnabled(): boolean
		return if props.enabled then props.enabled() else true
	end
	local function faded(): number
		return if isEnabled() then 0 else DISABLED_TRANSPARENCY
	end
	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(props.color, corner, true)
	local fill = glass[1] :: Frame
	local outline = glass[2] :: UIStroke
	Vide.effect(function()
		local transparency = faded()
		fill.BackgroundTransparency = transparency
		fill.BackgroundColor3 = if pressed() and isEnabled()
			then props.color:Lerp(Color3.new(1, 1, 1), PRESSED_LIGHTEN)
			else props.color
		outline.Transparency = transparency
	end)
	-- The word sits in its own frame above the glass: the glass is a child frame, and children
	-- draw over their parent's own text. A price's coin mark is drawn as the coin (IconText).
	return create("TextButton")({
		Name = props.name,
		LayoutOrder = props.layoutOrder or 0,
		Size = if width then UDim2.fromScale(width, 0) else UDim2.new(),
		AutomaticSize = if width then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = props.visible or true,
		Activated = function()
			if isEnabled() then
				props.onClick()
			end
		end,
		Layout.followPress(pressed),

		create("UICorner")({ CornerRadius = corner }),
		glass,
		create("Frame")({
			Name = "Label",
			ZIndex = 1,
			Size = if width then UDim2.fromScale(1, 0) else UDim2.new(),
			AutomaticSize = if width then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Layout.padding(PADDING_X, paddingY),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			IconText({
				name = "Text",
				text = props.text,
				textSize = textSize,
				color = NEON.TEXT,
				transparency = faded,
				outline = "Neon",
				zIndex = 1,
			}),
		}),
	}) :: TextButton
end

return ActionButton
