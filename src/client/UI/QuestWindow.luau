--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The daily quests window (docs/design/screens/quests.md): three cards side by side in a neon
-- window, one per quest: its icon, what to do, a progress bar, the reward and one action (claim
-- when done, swap while the day's swap is unused, asking "Sure?" before the swap). A claimed
-- card fades. The footer tells when new quests come and whether the swap is left. Data and texts
-- come in ready from the controller; claims and swaps are requests to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local NEON = Theme.NEON
local CARD_GAP = 10
local CARD_PADDING = 10
local CARD_LINE_GAP = 8
local CARD_TRANSPARENCY = 0.965
local DONE_TRANSPARENCY = 0.88
-- How far the quest colour of an active card's outline goes towards the glass.
local ACTIVE_LINE_DARKEN = 0.5
local ICON_SIZE = 50
local ICON_IMAGE_SHARE = 0.58
-- Two lines of the longest task.
local TASK_HEIGHT = 40
local BAR_HEIGHT = 12
local PROGRESS_WIDTH = 40
local REWARD_ICON_SIZE = 16
local ACTION_HEIGHT = 32
-- A claimed card fades all over.
local CLAIMED_TRANSPARENCY = 0.5
local QUEST_COLOR = NEON.TILE.Quests
local QUEST_BAR_END = Color3.fromHex("#FFD36B")
local DONE_COLOR = NEON.ACTION.Main
local DONE_BAR_END = Color3.fromHex("#9BF0A8")
local CHECK_COLOR = Color3.fromHex("#5BDB6E")
local CHECK_MARK = "✓"

export type State = "Active" | "Done" | "Claimed"

export type Row = {
	icon: Icons.Name,
	-- What to do, e.g. "Deliver 3 eggs".
	task: string,
	-- 0..1.
	progress: number,
	-- "2/3".
	progressText: string,
	-- What it pays, formatted: "12K", "3.4K".
	coins: string,
	speed: string,
	state: State,
	-- The day's swap is unused.
	canSwap: boolean,
	-- The swap was tapped once and waits for the second tap.
	confirming: boolean,
}

export type Texts = {
	title: string,
	-- When new quests come and whether the swap is left.
	resetIn: () -> string,
	swapHint: () -> string,
	claim: string,
	swap: string,
	confirm: string,
	claimed: string,
}

export type Props = {
	visible: () -> boolean,
	coins: () -> string,
	rows: () -> { Row },
	texts: Texts,
	onClaim: (index: number) -> (),
	onSwap: (index: number) -> (),
	onClose: () -> (),
}

type LabelOptions = {
	size: number?,
	color: Color3?,
	transparency: (() -> number)?,
	wrapped: boolean?,
	align: Enum.TextXAlignment?,
	width: UDim2?,
	visible: (() -> boolean)?,
}

local function label(name: string, text: string | () -> string, order: number, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or {}
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = opts.width or UDim2.new(),
		AutomaticSize = if opts.width then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
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

-- A horizontal row of pieces, centred, as wide as its pieces.
local function centredRow(
	name: string,
	order: number,
	gap: number,
	children: { Instance },
	visible: (() -> boolean)?
): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = visible or true,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		children,
	}) :: Frame
end

-- The quest's round icon: quest-coloured glass with the icon of what to do.
local function QuestIcon(row: () -> Row, dim: () -> number): Frame
	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(QUEST_COLOR, corner)
	local fill = glass[1] :: Frame
	local outline = glass[2] :: UIStroke
	-- The fill's own transparency adds to its gradient's, so the whole glass fades.
	Vide.effect(function()
		local transparency = dim()
		fill.BackgroundTransparency = transparency
		outline.Transparency = transparency
	end)
	return create("Frame")({
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		BackgroundTransparency = 1,
		create("UICorner")({ CornerRadius = corner }),
		glass,
		create("ImageLabel")({
			Name = "Image",
			ZIndex = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ICON_IMAGE_SHARE, ICON_IMAGE_SHARE),
			BackgroundTransparency = 1,
			Image = function()
				return Icons.ICONS[row().icon]
			end,
			ImageColor3 = Layout.iconColor(QUEST_COLOR),
			ImageTransparency = dim,
		}),
	}) :: Frame
end

local function ProgressBar(row: () -> Row, dim: () -> number): Frame
	local function done(): boolean
		return row().state ~= "Active"
	end
	local gradient = Instance.new("UIGradient")
	Vide.effect(function()
		gradient.Color = if done()
			then ColorSequence.new(DONE_COLOR, DONE_BAR_END)
			else ColorSequence.new(QUEST_COLOR, QUEST_BAR_END)
	end)
	local track = Layout.panelLine()
	Vide.effect(function()
		track.Transparency = 1 - (1 - NEON.LINE_TRANSPARENCY) * (1 - dim())
	end)
	return create("Frame")({
		Name = "Progress",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		BackgroundTransparency = 1,
		create("Frame")({
			Name = "Bar",
			Size = UDim2.new(1, -(PROGRESS_WIDTH + 4), 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.93,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			track,
			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(math.clamp(row().progress, 0, 1), 1)
				end,
				Visible = function()
					return row().progress > 0
				end,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = dim,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				gradient,
			}),
		}),
		create("TextLabel")({
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0, PROGRESS_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = NEON.MUTED,
			TextTransparency = dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = function()
				return row().progressText
			end,
			Layout.textStroke(),
		}),
	}) :: Frame
end

-- One part of the reward: its icon and "+12K" in its colour.
local function RewardPart(
	name: string,
	order: number,
	icon: Icons.Name,
	color: Color3,
	value: () -> string,
	dim: () -> number
): Frame
	return centredRow(name, order, 3, {
		create("ImageLabel")({
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(REWARD_ICON_SIZE, REWARD_ICON_SIZE),
			BackgroundTransparency = 1,
			Image = Icons.ICONS[icon],
			ImageColor3 = color,
			ImageTransparency = dim,
		}),
		label("Value", function()
			return `+{value()}`
		end, 2, { size = NEON.TEXT_SECTION, color = color, transparency = dim }),
	})
end

-- The card's one action: claim, swap (or its confirmation), or the claimed mark.
local function Action(row: () -> Row, index: number, props: Props, dim: () -> number): Frame
	local texts = props.texts
	local function state(): State
		return row().state
	end
	local function canSwap(): boolean
		return state() == "Active" and row().canSwap
	end
	return create("Frame")({
		Name = "Action",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		ActionButton({
			name = "Claim",
			text = texts.claim,
			color = DONE_COLOR,
			size = "Large",
			layoutOrder = 1,
			visible = function()
				return state() == "Done"
			end,
			onClick = function()
				props.onClaim(index)
			end,
		}),
		ActionButton({
			name = "Swap",
			text = texts.swap,
			color = NEON.MUTED,
			layoutOrder = 2,
			visible = function()
				return canSwap() and not row().confirming
			end,
			onClick = function()
				props.onSwap(index)
			end,
		}),
		label("Ask", texts.confirm, 3, {
			size = NEON.TEXT_SECTION,
			visible = function()
				return canSwap() and row().confirming
			end,
		}),
		ActionButton({
			name = "Confirm",
			text = texts.swap,
			color = NEON.DANGER,
			layoutOrder = 4,
			visible = function()
				return canSwap() and row().confirming
			end,
			onClick = function()
				props.onSwap(index)
			end,
		}),
		label("Claimed", `{CHECK_MARK} {texts.claimed}`, 5, {
			size = NEON.TEXT_SECTION,
			color = CHECK_COLOR,
			transparency = dim,
			visible = function()
				return state() == "Claimed"
			end,
		}),
	}) :: Frame
end

local function QuestCard(row: () -> Row, index: number, props: Props): Frame
	local function state(): State
		return row().state
	end
	local function dim(): number
		return if state() == "Claimed" then CLAIMED_TRANSPARENCY else 0
	end
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = NEON.LINE_THICKNESS
	Vide.effect(function()
		outline.Color = if state() == "Done" then DONE_COLOR else QUEST_COLOR:Lerp(NEON.GLASS, ACTIVE_LINE_DARKEN)
		outline.Transparency = dim()
	end)
	return create("Frame")({
		Name = "Quest",
		LayoutOrder = index,
		Size = UDim2.new(1 / 3, -CARD_GAP * 2 / 3, 1, 0),
		BackgroundColor3 = function()
			return if state() == "Done" then DONE_COLOR else Color3.new(1, 1, 1)
		end,
		BackgroundTransparency = function()
			return if state() == "Done" then DONE_TRANSPARENCY else CARD_TRANSPARENCY
		end,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		outline,
		Layout.padding(CARD_PADDING, CARD_PADDING),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, CARD_LINE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		QuestIcon(row, dim),
		label(
			"Task",
			function()
				return row().task
			end,
			2,
			{
				size = NEON.TEXT_SECTION,
				color = NEON.TEXT,
				transparency = dim,
				wrapped = true,
				width = UDim2.new(1, 0, 0, TASK_HEIGHT),
			}
		),
		ProgressBar(row, dim),
		centredRow("Reward", 4, 12, {
			RewardPart("Coins", 1, "Coin", NEON.COINS, function()
				return row().coins
			end, dim),
			RewardPart("Speed", 2, "Bolt", NEON.SPEED, function()
				return row().speed
			end, dim),
		}),
		Action(row, index, props, dim),
	}) :: Frame
end

local function QuestWindow(props: Props): Frame
	local texts = props.texts
	return NeonWindow({
		name = "QuestWindow",
		visible = props.visible,
		title = texts.title,
		coins = props.coins,
		onClose = props.onClose,
		body = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, CARD_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			indexes(props.rows, function(row: () -> Row, index: number)
				return QuestCard(row, index, props)
			end),
		},
		footer = {
			label("ResetIn", texts.resetIn, 1, {
				align = Enum.TextXAlignment.Left,
				width = UDim2.fromScale(0.5, 1),
			}),
			create("TextLabel")({
				Name = "SwapHint",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.MUTED,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = texts.swapHint,
				Layout.textStroke(),
			}),
		},
	})
end

return QuestWindow
