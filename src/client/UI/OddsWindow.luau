--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The odds window (docs/design/screens/egg-odds.md, decision 127): everything an egg in the
-- incubator can hatch into. A line names the egg; a column per tier that can come out (lowest
-- first) heads with the tier and its chance, and lists each kind of the guardian as its icon, its
-- name and the chance of that very alien. The footer tells the income roll, the outfit and, when a
-- chance is rounded, that it is. The window sells nothing: the purchase stays at the egg. Texts
-- and chances come in ready (OddsController, Domain/HatchOdds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AlienPicture = require(script.Parent.AlienPicture)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local EGG_LINE_HEIGHT = 20
local SECTION_GAP = 6
local COLUMN_GAP = 10
local HEAD_HEIGHT = 22
local HEAD_DOT = 12
local HEAD_DOT_GAP = 6
local ROW_HEIGHT = 40
local ROW_GAP = 4
local ICON_SIZE = 36
local ICON_GAP = 8
local ICON_CORNER = UDim.new(0, 11)
local NAME_TEXT = 14
local NOTE_HEIGHT = 15

-- One alien that can hatch.
export type Row = {
	icon: AlienIcons.Icon?,
	-- Its tier's colour (the icon's ring, the ball of a kind with no icon yet).
	color: Color3,
	name: string,
	-- "21.667 %".
	chance: string,
}

-- One tier that can hatch.
export type Column = {
	color: Color3,
	-- "Rare 60 %".
	head: string,
	rows: { Row },
}

export type Content = {
	-- "Rare egg · Crab Drone · large".
	egg: string,
	columns: { Column },
	-- The lines under the list: the income roll, the outfit, the rounding.
	notes: { string },
}

export type Props = {
	visible: () -> boolean,
	title: string,
	coins: () -> string,
	content: Content,
	onClose: () -> (),
}

local function Label(name: string, order: number, text: string, size: number, height: number): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = size,
		TextColor3 = NEON.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		Layout.textStroke(),
	}) :: TextLabel
end

local function RowView(row: Row, order: number): Frame
	local words = Instance.new("UIFlexItem")
	words.FlexMode = Enum.UIFlexMode.Fill
	return create("Frame")({
		Name = `Alien{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, ICON_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("Frame")({
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			BackgroundColor3 = NEON.GLASS,
			BackgroundTransparency = 0.3,
			create("UICorner")({ CornerRadius = ICON_CORNER }),
			Layout.stroke(row.color, NEON.LINE_THICKNESS, function()
				return true
			end),
			AlienPicture({
				icon = function()
					return row.icon
				end,
				color = function()
					return row.color
				end,
			}),
		}),
		create("Frame")({
			Name = "Words",
			LayoutOrder = 2,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			words,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Label("Name", 1, row.name, NAME_TEXT, NAME_TEXT + 4),
			Label("Chance", 2, row.chance, NAME_TEXT, NAME_TEXT + 4),
		}),
	}) :: Frame
end

local function ColumnView(column: Column, order: number): Frame
	local fill = Instance.new("UIFlexItem")
	fill.FlexMode = Enum.UIFlexMode.Fill
	local children: { any } = {
		fill,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("Frame")({
			Name = "Head",
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, HEAD_HEIGHT),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, HEAD_DOT_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("Frame")({
				Name = "Dot",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(HEAD_DOT, HEAD_DOT),
				BackgroundColor3 = column.color,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
			create("TextLabel")({
				Name = "Tier",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SECTION,
				TextColor3 = column.color,
				Text = column.head,
				Layout.textStroke(),
			}),
		}),
	}
	for index, row in column.rows do
		table.insert(children, RowView(row, index))
	end
	return create("Frame")({
		Name = `Tier{order}`,
		LayoutOrder = order,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		children,
	}) :: Frame
end

local function OddsWindow(props: Props): Frame
	local content = props.content
	local columns: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, COLUMN_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, column in content.columns do
		table.insert(columns, ColumnView(column, index))
	end
	local notes: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, note in content.notes do
		table.insert(notes, Label(`Note{index}`, index, note, NEON.TEXT_BODY, NOTE_HEIGHT))
	end
	return NeonWindow({
		name = "Odds",
		visible = props.visible,
		title = props.title,
		coins = props.coins,
		onClose = props.onClose,
		body = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, SECTION_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Label("Egg", 1, content.egg, NEON.TEXT_SECTION, EGG_LINE_HEIGHT),
			create("Frame")({
				Name = "Columns",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 1, -(EGG_LINE_HEIGHT + SECTION_GAP)),
				BackgroundTransparency = 1,
				columns,
			}),
		},
		footer = notes,
	})
end

return OddsWindow
