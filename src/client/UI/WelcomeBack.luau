--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen on login after time away: how long it was, what the pods earned, what the
-- trainer added and how many eggs wait to be hatched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local WIDTH = 360
local PADDING = 20
local GAP = 12
local TITLE_TEXT_SIZE = 28
local COINS_TEXT_SIZE = 36

export type Props = {
	visible: () -> boolean,
	title: string,
	-- The long line: how long and how much.
	details: () -> string,
	-- The big numbers.
	coins: () -> string,
	speed: () -> string,
	-- The ready eggs line; empty hides it.
	eggs: () -> string,
	claim: string,
	onClaim: () -> (),
}

local function WelcomeBack(props: Props): Frame
	return create("Frame")({
		Name = "WelcomeBack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PANEL,
		Visible = props.visible,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(PADDING, PADDING),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = TITLE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			Text = props.title,
		}),
		create("TextLabel")({
			Name = "Coins",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = COINS_TEXT_SIZE,
			TextColor3 = Theme.COINS,
			Text = function()
				return `● {props.coins()}`
			end,
		}),
		create("TextLabel")({
			Name = "Speed",
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = COINS_TEXT_SIZE,
			TextColor3 = Theme.SPEED,
			Text = function()
				return `+{props.speed()} ⚡`
			end,
		}),
		create("TextLabel")({
			Name = "Details",
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextWrapped = true,
			Text = props.details,
		}),
		create("TextLabel")({
			Name = "Eggs",
			LayoutOrder = 5,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextWrapped = true,
			Text = props.eggs,
			Visible = function()
				return props.eggs() ~= ""
			end,
		}),
		Button({
			name = "Claim",
			layoutOrder = 6,
			text = props.claim,
			color = Theme.COINS_DARK,
			onClick = props.onClaim,
		}),
	}) :: Frame
end

return WelcomeBack
