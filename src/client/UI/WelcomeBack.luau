--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The welcome-back screen (docs/design/screens/welcome-back.md): a compact neon window on login
-- after time away. How long the player was away, two big tiles (the coins the pods earned, the
-- ⚡ the trainer added), the eggs that are ready, and two buttons: "Claim" (the reward is
-- already paid, it only closes) and "×2" for Robux while the time away can be collected once
-- more.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local IconText = require(script.Parent.IconText)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Marks = require(ReplicatedStorage.Shared.Locale.Marks)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local SIZE = Vector2.new(470, 250)
local GAP = 8
local LINE_HEIGHT = 18
local TILE_HEIGHT = 66
local TILE_GAP = 10
local NUMBER_TEXT_SIZE = 26
local EGG_ICON_SIZE = 16
local TILE_TRANSPARENCY = 0.88
local TILE_LINE_DARKEN = 0.45

export type Texts = {
	title: string,
	-- "You were away 7 h 12 min".
	away: () -> string,
	pods: string,
	trainer: string,
	claim: string,
	-- "×2 for R$ 5".
	double: () -> string,
}

export type Props = {
	visible: () -> boolean,
	texts: Texts,
	-- The big numbers, formatted.
	coins: () -> string,
	speed: () -> string,
	-- The ready eggs line; empty hides it.
	eggs: () -> string,
	onClaim: () -> (),
	-- "×2" is on offer, and its price has come from Roblox.
	canDouble: () -> boolean,
	doubleReady: () -> boolean,
	onDouble: () -> (),
}

-- One big number with its icon and what brought it, on glass of its resource's colour.
local function Gain(name: string, order: number, mark: string, value: () -> string, label: string, color: Color3): Frame
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = NEON.LINE_THICKNESS
	stroke.Color = color:Lerp(NEON.GLASS, TILE_LINE_DARKEN)
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -TILE_GAP / 2, 1, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = TILE_TRANSPARENCY,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		stroke,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		IconText({
			name = "Number",
			layoutOrder = 1,
			text = function()
				return `{mark}+{value()}`
			end,
			textSize = NUMBER_TEXT_SIZE,
			color = color,
			outline = "Neon",
		}),
		create("TextLabel")({
			Name = "Label",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SMALL,
			TextColor3 = NEON.MUTED,
			Text = label,
			Layout.textStroke(),
		}),
	}) :: Frame
end

local function WelcomeBack(props: Props): Frame
	local texts = props.texts
	return NeonWindow({
		name = "WelcomeBack",
		visible = props.visible,
		title = texts.title,
		size = SIZE,
		-- The reward is already paid: closing is claiming.
		onClose = props.onClaim,
		body = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Away",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_HINT,
				TextColor3 = NEON.MUTED,
				Text = texts.away,
				Layout.textStroke(),
			}),
			create("Frame")({
				Name = "Gains",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, TILE_HEIGHT),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, TILE_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Gain("Coins", 1, Marks.COINS, props.coins, texts.pods, NEON.COINS),
				Gain("Speed", 2, Marks.SPEED, props.speed, texts.trainer, NEON.SPEED),
			}),
			create("Frame")({
				Name = "Eggs",
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Visible = function()
					return props.eggs() ~= ""
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 5),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(EGG_ICON_SIZE, EGG_ICON_SIZE),
					BackgroundTransparency = 1,
					Image = Icons.ICONS.Egg,
					ImageColor3 = NEON.EGG,
				}),
				create("TextLabel")({
					Name = "Text",
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_BODY,
					TextColor3 = NEON.EGG,
					Text = props.eggs,
					Layout.textStroke(),
				}),
			}),
		},
		footer = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ActionButton({
				name = "Claim",
				text = texts.claim,
				color = NEON.ACTION.Main,
				size = "Large",
				layoutOrder = 1,
				onClick = props.onClaim,
			}),
			ActionButton({
				name = "Double",
				text = texts.double,
				color = NEON.ACTION.Robux,
				size = "Large",
				layoutOrder = 2,
				visible = props.canDouble,
				enabled = props.doubleReady,
				onClick = props.onDouble,
			}),
		},
	})
end

return WelcomeBack
