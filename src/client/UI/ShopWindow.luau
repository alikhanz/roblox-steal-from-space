--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The jetpack shop window (docs/design/screens/jetpack-shop.md): two columns in a neon window.
-- Left: a card of the jetpack to buy next (its picture in its flame colours, the multiplier and
-- the speed before and after, one big buy button, or a saving-up bar while coins are short);
-- once the top jetpack is owned, that one with a note instead of the button. Right: the ladder
-- of every jetpack, scrolled to the owned one when the window opens. Data and texts come in
-- ready from the controller; buying is a request to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local IconText = require(script.Parent.IconText)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local NEON = Theme.NEON
local COLUMN_GAP = 12
local CARD_PADDING = 10
local CARD_GAP = 4
local JETPACK_SIZE = 64
-- The soft light behind the jetpack, against its size.
local JETPACK_GLOW_SHARE = 1.9
local JETPACK_GLOW_TRANSPARENCY = 0.55
-- The body keeps its flame's colour, only a little lighter, so jetpacks are told apart by it.
local JETPACK_LIGHTEN = 0.12
-- The flame sprite takes the lower part of the picture: its gradient keeps the hot colour until
-- the nozzles and turns to the flame's end colour at the tip.
local FLAME_HOT_UNTIL = 0.72
local CARD_TRANSPARENCY = 0.965
local BAR_HEIGHT = 10
local HEAD_HEIGHT = 22
local ROW_HEIGHT = 30
local ROW_GAP = 4
local ROW_CORNER = UDim.new(0, 9)
local SCROLL_BAR_ROOM = 9
local DOT_SIZE = 16
local TAG_HEIGHT = 16
-- Room on the right of a row for its price, tag or check mark.
local ROW_END_WIDTH = 64
local COIN_SIZE = 14
-- Rows above the owned one when the ladder scrolls to it.
local ROWS_ABOVE_OWNED = 1
-- How faded past and later rows are.
local PAST_TRANSPARENCY = 0.5
local LOCKED_TRANSPARENCY = 0.4
local OWNED_COLOR = NEON.ACTION.Move
local NEXT_COLOR = NEON.ACTION.Coins
local CHECK_COLOR = Color3.fromHex("#5BDB6E")
local CHECK_MARK = "✓"

export type Row = {
	level: number,
	name: string,
	-- "⚡ ×8".
	multiplier: string,
	flameStart: Color3,
	flameEnd: Color3,
	-- Past: outgrown; Owned: the current one; Next: the one to buy; Locked: later ones.
	state: "Past" | "Owned" | "Next" | "Locked",
	-- The price, on the next row only.
	price: string,
}

-- The card on the left: the next jetpack, or the owned one at the top.
export type Card = {
	name: string,
	flameStart: Color3,
	flameEnd: Color3,
	-- "⚡ ×4 → ×6", or "⚡ ×2048" at the top.
	upgrade: string,
	-- "Speed: 1.2K → 1.8K"; empty at the top.
	gain: string,
}

export type Texts = {
	title: string,
	hint: string,
	nextTitle: string,
	topTitle: string,
	topHint: string,
	ladderTitle: string,
	-- The tag on the owned row.
	owned: string,
}

export type Props = {
	visible: () -> boolean,
	coins: () -> string,
	texts: Texts,
	card: () -> Card,
	-- The top jetpack is owned: nothing to buy.
	atTop: () -> boolean,
	buyText: () -> string,
	canBuy: () -> boolean,
	-- "Saving up: 45K / 77K" while coins are short, and how much of the price is there (0..1).
	saving: () -> string,
	savingShare: () -> number,
	rows: () -> { Row },
	-- "4 of 22".
	count: () -> string,
	-- The owned row's place in the ladder (1 for the starter).
	ownedIndex: () -> number,
	onBuy: () -> (),
	onClose: () -> (),
}

type LabelOptions = {
	size: number?,
	color: (Color3 | () -> Color3)?,
	transparency: (() -> number)?,
	visible: (() -> boolean)?,
	wrapped: boolean?,
	align: Enum.TextXAlignment?,
}

local function label(name: string, text: string | () -> string, order: number, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or {}
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = opts.size or NEON.TEXT_BODY,
		TextColor3 = opts.color or NEON.MUTED,
		TextTransparency = opts.transparency or 0,
		TextXAlignment = opts.align or Enum.TextXAlignment.Center,
		TextWrapped = opts.wrapped == true,
		TextTruncate = if opts.wrapped then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		Visible = opts.visible or true,
		Text = text,
		Layout.textStroke(),
	}) :: TextLabel
end

-- A flame's colours across a picture: hot until `hotUntil` of its height, its end colour at the
-- bottom.
local function flameGradient(card: () -> { flameStart: Color3, flameEnd: Color3 }, hotUntil: number): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	Vide.effect(function()
		local current = card()
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, current.flameStart),
			ColorSequenceKeypoint.new(hotUntil, current.flameStart),
			ColorSequenceKeypoint.new(1, current.flameEnd),
		})
	end)
	return gradient
end

-- The jetpack's picture: the body in its flame colour, the flame under it, a soft light behind.
local function JetpackPicture(card: () -> Card, order: number): Frame
	local function flameEnd(): Color3
		return card().flameEnd
	end
	return create("Frame")({
		Name = "Jetpack",
		LayoutOrder = order,
		Size = UDim2.fromOffset(JETPACK_SIZE, JETPACK_SIZE),
		BackgroundTransparency = 1,
		create("ImageLabel")({
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(JETPACK_GLOW_SHARE, JETPACK_GLOW_SHARE),
			BackgroundTransparency = 1,
			Image = Icons.GLOW,
			ImageColor3 = flameEnd,
			ImageTransparency = JETPACK_GLOW_TRANSPARENCY,
		}),
		create("ImageLabel")({
			Name = "Body",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.ICONS.Jetpack,
			ImageColor3 = function()
				return flameEnd():Lerp(Color3.new(1, 1, 1), JETPACK_LIGHTEN)
			end,
		}),
		create("ImageLabel")({
			Name = "Flame",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.FLAME,
			flameGradient(card, FLAME_HOT_UNTIL),
		}),
	}) :: Frame
end

-- The saving-up line and bar, shown over the dim buy button while coins are short.
local function SavingBar(props: Props, order: number): Frame
	return create("Frame")({
		Name = "Saving",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function()
			return props.saving() ~= ""
		end,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		IconText({
			name = "Line",
			layoutOrder = 1,
			text = props.saving,
			textSize = NEON.TEXT_SMALL,
			color = NEON.MUTED,
			outline = "Neon",
		}),
		create("Frame")({
			Name = "Bar",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.93,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			Layout.panelLine(),
			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(math.clamp(props.savingShare(), 0, 1), 1)
				end,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				create("UIGradient")({ Color = ColorSequence.new(NEON.ACTION.Coins, NEON.SPEED) }),
			}),
		}),
	}) :: Frame
end

local function NextCard(props: Props): Frame
	local texts = props.texts
	local card = props.card
	local function flameEnd(): Color3
		return card().flameEnd
	end
	local function gain(): string
		return card().gain
	end
	local function hasGain(): boolean
		return gain() ~= ""
	end
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = NEON.LINE_THICKNESS
	Vide.effect(function()
		outline.Color = Layout.lineColor(flameEnd())
	end)
	return create("Frame")({
		Name = "Card",
		Size = UDim2.new(0.5, -COLUMN_GAP / 2, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = CARD_TRANSPARENCY,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		outline,
		Layout.padding(CARD_PADDING, CARD_PADDING - 2),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label("Kicker", function()
			return if props.atTop() then texts.topTitle else texts.nextTitle
		end, 1, { size = NEON.TEXT_SMALL }),
		JetpackPicture(card, 2),
		label("Name", function()
			return card().name
		end, 3, { size = NEON.TEXT_WINDOW_TITLE, color = NEON.TEXT }),
		IconText({
			name = "Upgrade",
			layoutOrder = 4,
			text = function()
				return card().upgrade
			end,
			textSize = NEON.TEXT_HINT,
			color = NEON.SPEED,
			outline = "Neon",
		}),
		label("Gain", gain, 5, { visible = hasGain }),
		SavingBar(props, 6),
		ActionButton({
			name = "Buy",
			text = props.buyText,
			color = NEXT_COLOR,
			size = "Large",
			width = 1,
			layoutOrder = 7,
			enabled = props.canBuy,
			visible = function()
				return not props.atTop()
			end,
			onClick = props.onBuy,
		}),
		label("Top", texts.topHint, 8, { wrapped = true, visible = props.atTop }),
	}) :: Frame
end

-- The right end of a ladder row: the price of the next one, the tag of the owned one, a check
-- mark on past ones, nothing on later ones.
local function RowEnd(row: () -> Row, texts: Texts, dim: () -> number): Frame
	local function state(): string
		return row().state
	end
	return create("Frame")({
		Name = "End",
		LayoutOrder = 3,
		Size = UDim2.new(0, ROW_END_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		create("Frame")({
			Name = "Price",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = function()
				return state() == "Next"
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 3),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("ImageLabel")({
				Name = "Coin",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE),
				BackgroundTransparency = 1,
				Image = Icons.ICONS.Coin,
				ImageColor3 = NEON.COINS,
			}),
			create("TextLabel")({
				Name = "Value",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.COINS,
				Text = function()
					return row().price
				end,
				Layout.textStroke(),
			}),
		}),
		create("TextLabel")({
			Name = "Tag",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(0, TAG_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = OWNED_COLOR,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SMALL,
			TextColor3 = NEON.GLASS,
			Text = texts.owned,
			Visible = function()
				return state() == "Owned"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			Layout.padding(7, 0),
		}),
		create("TextLabel")({
			Name = "Check",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SECTION,
			TextColor3 = CHECK_COLOR,
			TextTransparency = dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = CHECK_MARK,
			Visible = function()
				return state() == "Past"
			end,
		}),
	}) :: Frame
end

local function LadderRow(row: () -> Row, order: number, texts: Texts): Frame
	local function state(): string
		return row().state
	end
	-- Past and later rows fade; the owned and the next one are at full strength.
	local function dim(): number
		local current = state()
		return if current == "Past" then PAST_TRANSPARENCY elseif current == "Locked" then LOCKED_TRANSPARENCY else 0
	end
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Vide.effect(function()
		local current = state()
		outline.Color = if current == "Owned"
			then OWNED_COLOR
			elseif current == "Next" then Layout.lineColor(NEXT_COLOR)
			else NEON.LINE
		outline.Transparency = if current == "Owned" or current == "Next" then 0 else 0.82
		outline.Thickness = if current == "Owned" or current == "Next" then NEON.LINE_THICKNESS else 1
	end)
	return create("Frame")({
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = function()
			local current = state()
			return if current == "Owned"
				then OWNED_COLOR
				elseif current == "Next" then NEXT_COLOR
				else Color3.new(1, 1, 1)
		end,
		BackgroundTransparency = function()
			local current = state()
			return if current == "Owned" then 0.82 elseif current == "Next" then 0.92 else CARD_TRANSPARENCY
		end,
		create("UICorner")({ CornerRadius = ROW_CORNER }),
		outline,
		Layout.padding(9, 0),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("ImageLabel")({
			Name = "Dot",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageColor3 = function()
				return row().flameEnd
			end,
			ImageTransparency = dim,
		}),
		create("Frame")({
			Name = "Words",
			LayoutOrder = 2,
			-- What the dot and the end leave, less the gaps.
			Size = UDim2.new(1, -(DOT_SIZE + ROW_END_WIDTH + 14), 1, 0),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Name",
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.62, 1),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.TEXT,
				TextTransparency = dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = function()
					return row().name
				end,
				Layout.textStroke(),
			}),
			create("TextLabel")({
				Name = "Multiplier",
				LayoutOrder = 2,
				Size = UDim2.new(0.38, -6, 1, 0),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SMALL,
				TextColor3 = NEON.SPEED,
				TextTransparency = dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = function()
					return row().multiplier
				end,
				Layout.textStroke(),
			}),
		}),
		RowEnd(row, texts, dim),
	}) :: Frame
end

-- Room around the ladder's rows for their thick outlines, and on the right for the scroll bar.
local function listPadding(): UIPadding
	local instance = Layout.padding(3, 3)
	instance.PaddingRight = UDim.new(0, SCROLL_BAR_ROOM)
	return instance
end

local function Ladder(props: Props): Frame
	local texts = props.texts
	local scroller = create("ScrollingFrame")({
		Name = "List",
		Position = UDim2.fromOffset(0, HEAD_HEIGHT + 6),
		Size = UDim2.new(1, 0, 1, -(HEAD_HEIGHT + 6)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = NEON.LINE,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		listPadding(),
		indexes(props.rows, function(row: () -> Row, index: number)
			return LadderRow(row, index, texts)
		end),
	}) :: ScrollingFrame

	-- On opening (and after a buy), the owned jetpack is second from the top: one outgrown above
	-- it, the next ones below. The canvas moves by the row's place on screen, since it counts
	-- screen pixels and the window is scaled. Deferred so the rows are laid out first.
	Vide.effect(function()
		if not props.visible() then
			return
		end
		local topIndex = math.max(1, props.ownedIndex() - ROWS_ABOVE_OWNED)
		task.defer(function()
			local first: GuiObject? = nil
			local target: GuiObject? = nil
			for _, child in scroller:GetChildren() do
				if child:IsA("GuiObject") and child.Name == "Row" then
					if child.LayoutOrder == 1 then
						first = child
					end
					if child.LayoutOrder == topIndex then
						target = child
					end
				end
			end
			if first and target then
				-- From the first row, not from the canvas top: the list's padding stays above.
				local offset = target.AbsolutePosition.Y - first.AbsolutePosition.Y
				scroller.CanvasPosition = Vector2.new(0, offset)
			end
		end)
	end)

	return create("Frame")({
		Name = "Ladder",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -COLUMN_GAP / 2, 1, 0),
		BackgroundTransparency = 1,
		create("Frame")({
			Name = "Head",
			Size = UDim2.new(1, 0, 0, HEAD_HEIGHT),
			BackgroundTransparency = 1,
			label("Title", texts.ladderTitle, 1, {
				size = NEON.TEXT_SECTION,
				color = NEON.TEXT,
				align = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.MUTED,
				Text = props.count,
				Layout.textStroke(),
			}),
		}),
		scroller,
	}) :: Frame
end

local function ShopWindow(props: Props): Frame
	return NeonWindow({
		name = "ShopWindow",
		visible = props.visible,
		title = props.texts.title,
		coins = props.coins,
		onClose = props.onClose,
		body = { NextCard(props), Ladder(props) },
		footer = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("ImageLabel")({
				Name = "Bolt",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				Image = Icons.ICONS.Bolt,
				ImageColor3 = NEON.SPEED,
			}),
			create("TextLabel")({
				Name = "Hint",
				LayoutOrder = 2,
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = props.texts.hint,
				Layout.textStroke(),
			}),
		},
	})
end

return ShopWindow
