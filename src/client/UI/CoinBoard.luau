--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The coin board's face, drawn on the front of a screen of the station's board: up close a title,
-- what it counts and the top ten (place, name, coins); from afar (`far`) the title and the top
-- three in letters big enough to read across the station. The player's own row stands out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local LeaderboardLooks = require(ReplicatedStorage.Shared.Config.LeaderboardLooks)
local Marks = require(ReplicatedStorage.Shared.Locale.Marks)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

-- Laid out for a screen of the station's coin board (StationShape.BOARD_SCREEN_*) at
-- LeaderboardLooks.PIXELS_PER_STUD: 720 × 520 pixels.
local PADDING = 20
local GAP = 4
local HINT_TEXT_SIZE = 18

-- The two layouts: the title's size, how many rows, and a row's height, text and columns.
type Spec = {
	titleSize: number,
	rows: number,
	rowHeight: number,
	textSize: number,
	placeWidth: number,
	coinsWidth: number,
}

local NEAR: Spec = {
	titleSize = 42,
	rows = 10,
	rowHeight = 34,
	textSize = 25,
	placeWidth = 56,
	coinsWidth = 180,
}
-- The top three filling the screen under the title.
local FAR: Spec = {
	titleSize = 56,
	rows = 3,
	rowHeight = 136,
	textSize = 80,
	placeWidth = 90,
	coinsWidth = 270,
}

-- A row's strip: every other row faint, the player's own row in its colour.
local STRIP_TRANSPARENCY = 0.94
local OWN_STRIP_TRANSPARENCY = 0.78
local STRIP_CORNER = UDim.new(0, 8)

-- One row as the board shows it.
export type Row = {
	place: number,
	name: string,
	coins: string,
	own: boolean,
}

export type Props = {
	adornee: BasePart,
	title: string,
	allTime: string,
	empty: string,
	-- Best first; at most `rowCount` are shown up close.
	rows: () -> { Row },
	rowCount: number,
	-- Seen from afar: the top three, big.
	far: () -> boolean,
}

local function placeColor(row: Row): Color3
	return LeaderboardLooks.PLACE_COLORS[row.place] or LeaderboardLooks.ROW_COLOR
end

type LabelProps = {
	name: string,
	order: number,
	size: UDim2,
	text: string | () -> string,
	textSize: number,
	color: Color3 | () -> Color3,
	alignment: Enum.TextXAlignment?,
	visible: (() -> boolean)?,
	-- Wraps onto more lines instead of cutting the end off.
	wrapped: boolean?,
	-- Shrinks to fit instead of cutting the end off.
	scaled: boolean?,
}

local function label(props: LabelProps): TextLabel
	return create("TextLabel")({
		Name = props.name,
		LayoutOrder = props.order,
		Size = props.size,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = props.textSize,
		TextScaled = props.scaled == true,
		TextColor3 = props.color,
		TextXAlignment = props.alignment or Enum.TextXAlignment.Center,
		TextWrapped = props.wrapped == true,
		TextTruncate = if props.wrapped or props.scaled then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		Text = props.text,
		Visible = props.visible or true,
		if props.scaled
			then {
				Layout.maxTextSize(function()
					return props.textSize
				end),
			}
			else {},
	}) :: TextLabel
end

local function RowView(props: Props, spec: Spec, index: number): Frame
	local function row(): Row?
		return props.rows()[index]
	end
	local function color(): Color3
		local current = row()
		if not current then
			return LeaderboardLooks.ROW_COLOR
		end
		return if current.own then LeaderboardLooks.OWN_ROW_COLOR else LeaderboardLooks.ROW_COLOR
	end
	return create("Frame")({
		Name = `Row{index}`,
		LayoutOrder = 10 + index,
		Size = UDim2.new(1, 0, 0, spec.rowHeight),
		BackgroundColor3 = color,
		BackgroundTransparency = function()
			local current = row()
			if current and current.own then
				return OWN_STRIP_TRANSPARENCY
			end
			return if index % 2 == 1 then STRIP_TRANSPARENCY else 1
		end,
		Visible = function()
			return row() ~= nil
		end,

		create("UICorner")({ CornerRadius = STRIP_CORNER }),
		Layout.padding(8, 0),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label({
			name = "Place",
			order = 1,
			size = UDim2.new(0, spec.placeWidth, 1, 0),
			text = function()
				local current = row()
				return if current then tostring(current.place) else ""
			end,
			textSize = spec.textSize,
			color = function()
				local current = row()
				return if current then placeColor(current) else LeaderboardLooks.ROW_COLOR
			end,
		}),
		label({
			name = "Name",
			order = 2,
			size = UDim2.new(1, -(spec.placeWidth + spec.coinsWidth), 1, 0),
			text = function()
				local current = row()
				return if current then current.name else ""
			end,
			textSize = spec.textSize,
			color = color,
			alignment = Enum.TextXAlignment.Left,
			scaled = true,
		}),
		create("Frame")({
			Name = "Coins",
			LayoutOrder = 3,
			Size = UDim2.new(0, spec.coinsWidth, 1, 0),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			IconText({
				name = "Value",
				text = function()
					local current = row()
					return if current then `{Marks.COINS}{current.coins}` else ""
				end,
				textSize = spec.textSize,
				color = Theme.COINS,
				font = Theme.FONT,
			}),
		}),
	}) :: Frame
end

-- One layout: the title, the hint up close, the empty board's line, the rows.
local function Face(props: Props, spec: Spec, visible: () -> boolean): Frame
	local rowViews = {}
	for index = 1, math.min(spec.rows, props.rowCount) do
		table.insert(rowViews, RowView(props, spec, index))
	end
	local near = spec == NEAR
	return create("Frame")({
		Name = if near then "Near" else "Far",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,

		Layout.padding(PADDING),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),

		label({
			name = "Title",
			order = 1,
			size = UDim2.new(1, 0, 0, spec.titleSize + GAP),
			text = props.title,
			textSize = spec.titleSize,
			color = LeaderboardLooks.TITLE_COLOR,
		}),
		label({
			name = "AllTime",
			order = 2,
			size = UDim2.new(1, 0, 0, HINT_TEXT_SIZE + GAP),
			text = props.allTime,
			textSize = HINT_TEXT_SIZE,
			color = Theme.MUTED,
			-- Only up close: from afar it is too small to read.
			visible = function()
				return near
			end,
		}),
		label({
			name = "Empty",
			order = 3,
			size = UDim2.new(1, 0, 0, spec.rowHeight * 2),
			text = props.empty,
			textSize = spec.textSize,
			color = LeaderboardLooks.ROW_COLOR,
			wrapped = true,
			visible = function()
				return #props.rows() == 0
			end,
		}),
		rowViews,
	}) :: Frame
end

local function CoinBoard(props: Props): SurfaceGui
	return create("SurfaceGui")({
		Name = "CoinBoard",
		Adornee = props.adornee,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = LeaderboardLooks.PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = LeaderboardLooks.MAX_DISTANCE,

		Face(props, NEAR, function()
			return not props.far()
		end),
		Face(props, FAR, props.far),
	}) :: SurfaceGui
end

return CoinBoard
