--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The oxygen tank in the HUD's bottom stack (docs/design/screens/hud.md): the bubble icon, a
-- glass bar and the percent left; red, with a warning above it, when the tank runs low.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local WIDTH = 253
local BAR_HEIGHT = 14
local ICON_SIZE = 24
local GAP = 7
local PERCENT_WIDTH = 38
-- The fill runs from deep to light blue.
local FILL_FROM = Color3.fromHex("#1F9AD8")
local FILL_TO = Color3.fromHex("#78D6E8")

export type Props = {
	-- Share of a full tank, 0..1.
	fraction: () -> number,
	isLow: () -> boolean,
	visible: () -> boolean,
	warningText: string,
	layoutOrder: number,
}

local function OxygenBar(props: Props): Frame
	local fillGradient = Instance.new("UIGradient")
	Vide.effect(function()
		fillGradient.Color = if props.isLow()
			then ColorSequence.new(NEON.DANGER)
			else ColorSequence.new(FILL_FROM, FILL_TO)
	end)
	return create("Frame")({
		Name = "OxygenBar",
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = props.visible,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Warning",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = NEON.DANGER,
			Text = props.warningText,
			Visible = props.isLow,
			Layout.textStroke(),
		}),
		create("Frame")({
			Name = "Row",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, ICON_SIZE),
			BackgroundTransparency = 1,
			create("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				BackgroundTransparency = 1,
				Image = Icons.ICONS.Oxygen,
				ImageColor3 = function()
					return if props.isLow() then NEON.DANGER else NEON.OXYGEN
				end,
			}),
			create("Frame")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, ICON_SIZE + GAP, 0.5, 0),
				Size = UDim2.new(1, -(ICON_SIZE + GAP * 2 + PERCENT_WIDTH), 0, BAR_HEIGHT),
				BackgroundColor3 = NEON.GLASS,
				BackgroundTransparency = NEON.GLASS_TRANSPARENCY,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				Layout.panelLine(),
				create("Frame")({
					Name = "Fill",
					BorderSizePixel = 0,
					Size = function()
						return UDim2.fromScale(math.clamp(props.fraction(), 0, 1), 1)
					end,
					BackgroundColor3 = Color3.new(1, 1, 1),
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					fillGradient,
				}),
			}),
			create("TextLabel")({
				Name = "Percent",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(PERCENT_WIDTH, NEON.TEXT_BODY),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return `{math.floor(math.clamp(props.fraction(), 0, 1) * 100 + 0.5)}%`
				end,
				Layout.textStroke(),
			}),
		}),
	}) :: Frame
end

return OxygenBar
