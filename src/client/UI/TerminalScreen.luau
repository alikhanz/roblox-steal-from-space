--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen of a terminal on a player's island (docs/design/screens/terminals.md): a SurfaceGui
-- on the terminal's screen part with a title in the zone's colour, a big number, a hint, and for
-- the owner a button with the price (or a line once everything is bought).
--
-- The canvas is laid out at screen size and scaled up to the part (UIScale), so the neon
-- components (ActionButton, IconText) keep their own sizes and proportions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- The canvas in screen pixels, as wide and high as the screen part (4 x 3 studs), scaled up to
-- fill it.
local CANVAS = Vector2.new(160, 120)
local PIXELS_PER_STUD = 100
-- Screens fade out beyond this distance, as the signs before them, studs.
local MAX_DISTANCE = 80
local TITLE_SIZE = 18
local VALUE_SIZE = 30
local HINT_SIZE = 12
local SCREEN_TOP = Color3.fromRGB(22, 32, 96)
local SCREEN_BOTTOM = Color3.fromRGB(10, 13, 44)
local DONE_COLOR = NEON.SHIELD
-- How far the title's colour goes towards white: the zone's colour, readable on the dark glass.
local TITLE_LIGHTEN = 0.45

export type ButtonProps = {
	text: () -> string,
	enabled: () -> boolean,
	onClick: () -> (),
}

export type Props = {
	adornee: BasePart,
	color: Color3,
	title: string,
	value: () -> string,
	hint: () -> string,
	hintColor: Color3?,
	-- The owner's purchase; nil on someone else's island.
	button: ButtonProps?,
	-- True once there is nothing left to buy: the button gives way to `doneText`.
	done: (() -> boolean)?,
	doneText: string?,
}

-- Vide's create does not know UIScale.
local function scaleTo(scale: number): UIScale
	local instance = Instance.new("UIScale")
	instance.Scale = scale
	return instance
end

local function TerminalScreen(props: Props): SurfaceGui
	local button = props.button
	local done = props.done or function()
		return false
	end
	return create("SurfaceGui")({
		Name = "TerminalScreen",
		Adornee = props.adornee,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		-- Needed for the button to take clicks and touches.
		Active = button ~= nil,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			scaleTo(props.adornee.Size.X * PIXELS_PER_STUD / CANVAS.X),
			create("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(SCREEN_TOP, SCREEN_BOTTOM),
			}),
			Layout.padding(NEON.GAP, NEON.GAP),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),

			create("TextLabel")({
				Name = "Title",
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = TITLE_SIZE,
				TextColor3 = props.color:Lerp(Color3.new(1, 1, 1), TITLE_LIGHTEN),
				Text = props.title,
				Layout.textStroke(),
			}),
			create("TextLabel")({
				Name = "Value",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = VALUE_SIZE,
				TextColor3 = NEON.TEXT,
				Text = props.value,
				Layout.textStroke(),
			}),
			-- Amounts of ⚡ show their icon (Locale/Marks).
			IconText({
				name = "Hint",
				layoutOrder = 3,
				text = props.hint,
				textSize = HINT_SIZE,
				color = props.hintColor or NEON.MUTED,
				font = NEON.FONT,
				outline = "Neon",
				wrapWidth = CANVAS.X - NEON.GAP * 2,
			}),
			if button
				then ActionButton({
					name = "Buy",
					layoutOrder = 4,
					text = button.text,
					color = NEON.ACTION.Coins,
					enabled = button.enabled,
					onClick = button.onClick,
					visible = function()
						return not done()
					end,
				})
				else nil,
			if button
				then create("TextLabel")({
					Name = "Done",
					LayoutOrder = 5,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = HINT_SIZE,
					TextColor3 = DONE_COLOR,
					Text = props.doneText or "",
					Visible = done,
					Layout.textStroke(),
				})
				else nil,
		}),
	}) :: SurfaceGui
end

return TerminalScreen
