--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A two-line sign hanging over something in the world: a title and a value under it.
-- Used for bays, aliens and incubator eggs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local IconText = require(script.Parent.IconText)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local WIDTH = 220
local HEIGHT = 60
-- Room for the button row under the two lines.
local BUTTON_ROW_HEIGHT = 48
-- Signs fade out beyond this distance so the station is not covered in text, studs.
local DEFAULT_MAX_DISTANCE = 80
local VALUE_TEXT_SIZE = 16

-- A button under the sign: a purchase right where the thing stands.
export type ButtonProps = {
	text: string | () -> string,
	enabled: () -> boolean,
	visible: () -> boolean,
	onClick: () -> (),
	color: Color3?,
}

export type Props = {
	adornee: BasePart,
	-- Static, or sources for lines that change (countdowns, levels).
	title: string | () -> string,
	value: string | () -> string,
	valueColor: Color3?,
	-- Height of the sign above the adornee's center, studs.
	studsAbove: number,
	maxDistance: number?,
	button: ButtonProps?,
}

local function WorldLabel(props: Props): BillboardGui
	local button = props.button
	return create("BillboardGui")({
		Name = "WorldLabel",
		Adornee = props.adornee,
		Size = UDim2.fromOffset(WIDTH, HEIGHT + (if button then BUTTON_ROW_HEIGHT else 0)),
		StudsOffset = Vector3.new(0, props.studsAbove, 0),
		MaxDistance = props.maxDistance or DEFAULT_MAX_DISTANCE,
		AlwaysOnTop = true,
		-- Needed for the button to take clicks and touches.
		Active = button ~= nil,
		LightInfluence = 0,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextStrokeTransparency = 0.4,
			Text = props.title,
		}),

		-- Amounts of coins and ⚡ show their icons (Locale/Marks).
		IconText({
			name = "Value",
			layoutOrder = 2,
			text = props.value,
			textSize = VALUE_TEXT_SIZE,
			color = props.valueColor or Theme.TEXT,
			font = Theme.FONT,
			outline = "Legacy",
		}),

		if button
			then create("Frame")({
				Name = "ButtonRow",
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Visible = button.visible,
				Button({
					name = "SignButton",
					text = button.text,
					enabled = button.enabled,
					color = button.color or Theme.COINS_DARK,
					onClick = button.onClick,
				}),
			})
			else nil,
	}) :: BillboardGui
end

return WorldLabel
