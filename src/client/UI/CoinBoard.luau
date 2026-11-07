--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The coin board's face: a title, what it counts, and the top rows (place, name, coins), drawn
-- on the front of the board's panel. The player's own row stands out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local LeaderboardLooks = require(ReplicatedStorage.Shared.Config.LeaderboardLooks)
local Marks = require(ReplicatedStorage.Shared.Locale.Marks)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local TITLE_TEXT_SIZE = 34
local HINT_TEXT_SIZE = 18
local ROW_TEXT_SIZE = 22
local ROW_HEIGHT = 32
local PLACE_WIDTH = 40
local COINS_WIDTH = 120
local PADDING = 16
local GAP = 6

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
	-- Best first; at most `rowCount` are shown.
	rows: () -> { Row },
	rowCount: number,
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
}

local function label(props: LabelProps): TextLabel
	return create("TextLabel")({
		Name = props.name,
		LayoutOrder = props.order,
		Size = props.size,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = props.textSize,
		TextColor3 = props.color,
		TextXAlignment = props.alignment or Enum.TextXAlignment.Center,
		TextWrapped = props.wrapped == true,
		TextTruncate = if props.wrapped then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		Text = props.text,
		Visible = props.visible or true,
	}) :: TextLabel
end

local function RowView(props: Props, index: number): Frame
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
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return row() ~= nil
		end,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label({
			name = "Place",
			order = 1,
			size = UDim2.new(0, PLACE_WIDTH, 1, 0),
			text = function()
				local current = row()
				return if current then tostring(current.place) else ""
			end,
			textSize = ROW_TEXT_SIZE,
			color = function()
				local current = row()
				return if current then placeColor(current) else LeaderboardLooks.ROW_COLOR
			end,
		}),
		label({
			name = "Name",
			order = 2,
			size = UDim2.new(1, -(PLACE_WIDTH + COINS_WIDTH), 1, 0),
			text = function()
				local current = row()
				return if current then current.name else ""
			end,
			textSize = ROW_TEXT_SIZE,
			color = color,
			alignment = Enum.TextXAlignment.Left,
		}),
		create("Frame")({
			Name = "Coins",
			LayoutOrder = 3,
			Size = UDim2.new(0, COINS_WIDTH, 1, 0),
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
				textSize = ROW_TEXT_SIZE,
				color = Theme.COINS,
				font = Theme.FONT,
			}),
		}),
	}) :: Frame
end

local function CoinBoard(props: Props): SurfaceGui
	local rowViews = {}
	for index = 1, props.rowCount do
		table.insert(rowViews, RowView(props, index))
	end

	return create("SurfaceGui")({
		Name = "CoinBoard",
		Adornee = props.adornee,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = LeaderboardLooks.PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = LeaderboardLooks.MAX_DISTANCE,

		create("Frame")({
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

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
				size = UDim2.new(1, 0, 0, TITLE_TEXT_SIZE + GAP),
				text = props.title,
				textSize = TITLE_TEXT_SIZE,
				color = LeaderboardLooks.TITLE_COLOR,
			}),
			label({
				name = "AllTime",
				order = 2,
				size = UDim2.new(1, 0, 0, HINT_TEXT_SIZE + GAP),
				text = props.allTime,
				textSize = HINT_TEXT_SIZE,
				color = Theme.MUTED,
			}),
			label({
				name = "Empty",
				order = 3,
				size = UDim2.new(1, 0, 0, ROW_HEIGHT * 2),
				text = props.empty,
				textSize = ROW_TEXT_SIZE,
				color = LeaderboardLooks.ROW_COLOR,
				wrapped = true,
				visible = function()
					return #props.rows() == 0
				end,
			}),
			rowViews,
		}),
	}) :: SurfaceGui
end

return CoinBoard
