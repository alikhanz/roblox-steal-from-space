--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The controls window (docs/design/screens/controls.md): what each flight button does. Eight
-- rows in two columns (flight on the left, the egg and the attacks on the right), each with the
-- button as it looks on the screen, its name and one line; with a keyboard or a gamepad the key
-- sits on the button's corner, as in the HUD's action row. The footer has "Don't show again"
-- (no "?" tile, no window on joining) and "Got it". Texts and keys come in ready.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local FlightButtons = require(script.Parent.FlightButtons)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Press = require(script.Parent.Press)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local ROWS_PER_COLUMN = 4
local COLUMN_GAP = 20
local ICON_SIZE = 38
local ICON_SHARE = 0.55
local ICON_GAP = 12
local LINE_GAP = 1
local CHECK_SIZE = 22
local CHECK_GAP = 8
local CHECK_MARK = "✓"
-- A ticked box: filled with the colour of the useful action.
local CHECK_COLOR = NEON.ACTION.Main
local CHECK_FILL_TRANSPARENCY = 0.4

export type Row = {
	name: string,
	icon: Icons.Name,
	color: Color3,
	title: string,
	-- What it does; may depend on the input (the stick on a phone, keys on a PC).
	hint: () -> string,
	-- The key on the button's corner; empty: none (a touch screen).
	key: () -> string,
}

export type Texts = {
	title: string,
	hide: string,
	ok: string,
}

export type Props = {
	visible: () -> boolean,
	texts: Texts,
	rows: { Row },
	-- "Don't show again" is ticked.
	hidden: () -> boolean,
	onToggleHidden: () -> (),
	onClose: () -> (),
}

local function RowIcon(row: Row): Frame
	local corner = UDim.new(0.5, 0)
	return create("Frame")({
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		BackgroundTransparency = 1,
		create("UICorner")({ CornerRadius = corner }),
		Layout.glass(row.color, corner),
		create("ImageLabel")({
			Name = "Image",
			ZIndex = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ICON_SHARE, ICON_SHARE),
			BackgroundTransparency = 1,
			Image = Icons.ICONS[row.icon],
			ImageColor3 = Layout.iconColor(row.color),
		}),
		FlightButtons.KeyCap(row.key),
	}) :: Frame
end

local function RowView(row: Row, order: number): Frame
	local item = Instance.new("UIFlexItem")
	item.FlexMode = Enum.UIFlexMode.Fill
	return create("Frame")({
		Name = row.name,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, ICON_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		RowIcon(row),
		create("Frame")({
			Name = "Words",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			item,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, LINE_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, NEON.TEXT_SECTION + 2),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SECTION,
				TextColor3 = NEON.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = row.title,
				Layout.textStroke(),
			}),
			create("TextLabel")({
				Name = "Hint",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SMALL,
				TextColor3 = NEON.MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = row.hint,
				Layout.textStroke(),
			}),
		}),
	}) :: Frame
end

-- "Don't show again": a box and its words, pressed together.
local function HideToggle(props: Props): TextButton
	local press = Press.new({})
	local corner = UDim.new(0, 5)
	local box = create("Frame")({
		Name = "Box",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(CHECK_SIZE, CHECK_SIZE),
		BackgroundColor3 = NEON.GLASS,
		create("UICorner")({ CornerRadius = corner }),
		Layout.panelLine(),
		create("TextLabel")({
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SECTION,
			TextColor3 = NEON.TEXT,
			Text = CHECK_MARK,
			Visible = props.hidden,
			Layout.textStroke(),
		}),
	}) :: Frame
	Vide.effect(function()
		local ticked = props.hidden()
		local base = if ticked then CHECK_COLOR else NEON.GLASS
		box.BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), press.light())
		box.BackgroundTransparency = if ticked then CHECK_FILL_TRANSPARENCY else NEON.GLASS_TRANSPARENCY
	end)
	return create("TextButton")({
		Name = "Hide",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			props.onToggleHidden()
		end,
		press.action,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, CHECK_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		box,
		create("TextLabel")({
			Name = "Words",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = NEON.MUTED,
			Text = props.texts.hide,
			Layout.textStroke(),
		}),
	}) :: TextButton
end

local function ControlsWindow(props: Props): Frame
	local rows = {}
	for order, row in props.rows do
		table.insert(rows, RowView(row, order))
	end
	return NeonWindow({
		name = "ControlsWindow",
		visible = props.visible,
		title = props.texts.title,
		onClose = props.onClose,
		body = {
			create("UIGridLayout")({
				-- Down the first column, then the second.
				FillDirection = Enum.FillDirection.Vertical,
				FillDirectionMaxCells = ROWS_PER_COLUMN,
				CellSize = UDim2.new(0.5, -COLUMN_GAP / 2, 1 / ROWS_PER_COLUMN, 0),
				CellPadding = UDim2.fromOffset(COLUMN_GAP, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			rows,
		},
		footer = {
			HideToggle(props),
			create("Frame")({
				Name = "Ok",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				ActionButton({
					name = "Ok",
					text = props.texts.ok,
					color = NEON.ACTION.Main,
					onClick = props.onClose,
				}),
			}),
		},
	})
end

return ControlsWindow
