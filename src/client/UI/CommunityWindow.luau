--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The community window (docs/design/screens/community.md): a compact neon window with the gift
-- for joining the game's community in big numbers, one line on what it is, and one gold button
-- that opens Roblox's own join prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local Marks = require(ReplicatedStorage.Shared.Locale.Marks)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local SIZE = Vector2.new(380, 230)
local GAP = 10
local GIFT_TEXT_SIZE = 40
local HINT_WIDTH = 320

export type Props = {
	visible: () -> boolean,
	title: string,
	coins: () -> string,
	-- The gift as the stat would show it now, formatted ("10K").
	gift: () -> string,
	hint: string,
	-- The button's word: "Join", or "Checking…" while the server asks Roblox.
	button: () -> string,
	canJoin: () -> boolean,
	onJoin: () -> (),
	onClose: () -> (),
}

local function CommunityWindow(props: Props): Frame
	return NeonWindow({
		name = "Community",
		visible = props.visible,
		title = props.title,
		coins = props.coins,
		size = SIZE,
		onClose = props.onClose,
		body = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			IconText({
				name = "Gift",
				layoutOrder = 1,
				text = function()
					return `{Marks.SPEED}+{props.gift()}`
				end,
				textSize = GIFT_TEXT_SIZE,
				color = NEON.SPEED,
				outline = "Neon",
			}),
			create("TextLabel")({
				Name = "Hint",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(HINT_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.MUTED,
				TextWrapped = true,
				Text = props.hint,
				Layout.textStroke(),
			}),
		},
		footer = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ActionButton({
				name = "Join",
				text = props.button,
				color = NEON.ACTION.Coins,
				size = "Large",
				enabled = props.canJoin,
				onClick = props.onJoin,
			}),
		},
	})
end

return CommunityWindow
