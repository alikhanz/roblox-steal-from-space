--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A resource plaque of the HUD (DESIGN.md, "Плашка ресурса"): glass with a number and the
-- resource's icon sticking out over its left edge, tinted with the resource's colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local NEON = Theme.NEON
-- The icon, and how far it reaches out past the plaque's left edge.
local ICON_SIZE = 30
local ICON_OVERHANG = 14
local PADDING_X = 10
local PADDING_Y = 4

export type Props = {
	name: string,
	icon: Icons.Name,
	-- An icon that changes (the egg in hand wears its own); `icon` otherwise.
	iconOf: (() -> Icons.Name)?,
	color: Color3,
	-- The number or short text, e.g. "178K" or "12 min".
	value: () -> string,
	layoutOrder: number,
	textSize: number?,
	visible: (() -> boolean)?,
	-- The longest text the value can take: the plaque keeps that width, so it does not twitch
	-- (and push its neighbours) as the number grows. Without it the plaque fits its text.
	widest: string?,
}

-- Before the font measures the widest text: a guess from the text size, characters wide.
local GUESS_CHAR_WIDTH = 0.6

local function ResourcePill(props: Props): Frame
	local textSize = props.textSize or NEON.TEXT_RESOURCE
	local fixedWidth = source(nil :: number?)
	local readFixedWidth = fixedWidth :: () -> number?
	local widest = props.widest
	if widest then
		fixedWidth(math.ceil(#widest * textSize * GUESS_CHAR_WIDTH))
		task.spawn(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = widest
			params.Font = NEON.FONT
			params.Size = textSize
			params.Width = math.huge
			local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
			if ok then
				fixedWidth(math.ceil(bounds.X))
			end
		end)
	end
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
			Image = function()
				local iconOf = props.iconOf
				return Icons.ICONS[if iconOf then iconOf() else props.icon]
			end,
			ImageColor3 = props.color,
		}),
		create("TextLabel")({
			Name = "Value",
			Position = UDim2.fromOffset(ICON_SIZE - ICON_OVERHANG - PADDING_X + 4, 0),
			Size = function()
				local width = readFixedWidth()
				return if width then UDim2.new(0, width, 1, 0) else UDim2.fromScale(0, 1)
			end,
			AutomaticSize = function()
				return if readFixedWidth() then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			end,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = textSize,
			TextColor3 = NEON.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = props.value,
			Layout.textStroke(),
		}),
	}) :: Frame
end

return ResourcePill
