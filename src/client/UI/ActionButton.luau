--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- An action button of the neon style (DESIGN.md, "Кнопка действия"): a rounded pill of dense
-- coloured glass with a word on it. Shrinks a little while pressed; a disabled one fades and
-- does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local NEON = Theme.NEON
local PRESSED_SCALE = 0.95
-- A disabled button: how see-through its glass and its word get.
local DISABLED_TRANSPARENCY = 0.5
local PADDING_X = 10
local PADDING_Y = 3

export type Size = "Small" | "Normal"

export type Props = {
	name: string,
	text: string | () -> string,
	-- What the press does (NEON.ACTION.*).
	color: Color3,
	onClick: () -> (),
	enabled: (() -> boolean)?,
	size: Size?,
	layoutOrder: number?,
}

local function ActionButton(props: Props): TextButton
	local pressed = source(false)
	local textSize = if props.size == "Small" then NEON.TEXT_SMALL else NEON.TEXT_BODY
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
	local textStroke = Layout.textStroke()
	-- Vide's typed `create` does not list UIScale, so it is made directly.
	local pressScale = Instance.new("UIScale")
	Vide.effect(function()
		pressScale.Scale = if pressed() and isEnabled() then PRESSED_SCALE else 1
	end)
	Vide.effect(function()
		local transparency = faded()
		fill.BackgroundTransparency = transparency
		outline.Transparency = transparency
		textStroke.Transparency = 1 - (1 - NEON.TEXT_STROKE_TRANSPARENCY) * (1 - transparency)
	end)
	-- The word sits in its own label above the glass: the glass is a child frame, and children
	-- draw over their parent's own text.
	return create("TextButton")({
		Name = props.name,
		LayoutOrder = props.layoutOrder or 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			if isEnabled() then
				props.onClick()
			end
		end,
		Layout.followPress(pressed),

		create("UICorner")({ CornerRadius = corner }),
		pressScale,
		glass,
		create("TextLabel")({
			Name = "Label",
			ZIndex = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = textSize,
			TextColor3 = NEON.TEXT,
			TextTransparency = faded,
			Text = props.text,
			Layout.padding(PADDING_X, PADDING_Y),
			textStroke,
		}),
	}) :: TextButton
end

return ActionButton
