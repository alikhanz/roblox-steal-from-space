--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A text button of the HUD: rounded, dims when disabled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local HEIGHT = 40
local PADDING = 14
local DISABLED_TRANSPARENCY = 0.6
-- The count bubble on the top-right corner.
local BADGE_SIZE = 24
local BADGE_TEXT_SIZE = 15
-- How far the bubble's center sits inside the corner, pixels.
local BADGE_INSET = 4

export type Props = {
	name: string,
	text: string | () -> string,
	onClick: () -> (),
	enabled: (() -> boolean)?,
	color: Color3?,
	layoutOrder: number?,
	-- Something waits behind the button: a red bubble with this count, hidden at 0.
	badge: (() -> number)?,
}

local function Badge(count: () -> number): Frame
	return create("Frame")({
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- The button's padding shifts its children inwards; the bubble sits on the outer corner.
		Position = UDim2.new(1, PADDING - BADGE_INSET, 0, BADGE_INSET),
		Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
		BackgroundColor3 = Theme.DANGER,
		ZIndex = 2,
		Visible = function()
			return count() > 0
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		Layout.stroke(Theme.TEXT, 2, function()
			return true
		end),
		create("TextLabel")({
			Name = "Count",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = BADGE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			ZIndex = 2,
			Text = function()
				return tostring(count())
			end,
		}),
	}) :: Frame
end

local function Button(props: Props): TextButton
	local function isEnabled(): boolean
		return if props.enabled then props.enabled() else true
	end
	return create("TextButton")({
		Name = props.name,
		LayoutOrder = props.layoutOrder or 0,
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = props.color or Theme.ACCENT,
		BackgroundTransparency = function()
			return if isEnabled() then 0 else DISABLED_TRANSPARENCY
		end,
		FontFace = Theme.FONT,
		TextSize = Theme.TEXT_SIZE,
		TextColor3 = Theme.TEXT,
		TextTransparency = function()
			return if isEnabled() then 0 else DISABLED_TRANSPARENCY
		end,
		Text = props.text,
		AutoButtonColor = isEnabled,
		Activated = function()
			if isEnabled() then
				props.onClick()
			end
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(PADDING),
		if props.badge then Badge(props.badge) else nil,
	}) :: TextButton
end

return Button
