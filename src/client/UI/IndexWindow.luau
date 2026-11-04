--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The alien index window: zone headers, and under each a row per guardian with its five aliens.
-- An unknown alien is a dark "?", a found one takes its tier's color and name, and a new one
-- glows until it is tapped for its reward. A full set gets a claim button. Texts come in
-- resolved; every row and cell is a plain value the controller computes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Window = require(script.Parent.Window)

local create = Vide.create
local indexes = Vide.indexes

local MAX_SIZE = Vector2.new(560, 620)
local GAP = 8
local ZONE_TEXT_SIZE = 20
local ROW_TEXT_SIZE = 16
local CELL_SIZE = 64
local CELL_TEXT_SIZE = 11
local UNKNOWN_TEXT_SIZE = 26
local HEADER_HEIGHT = 26
-- Room above the tab buttons for their badges (the list clips what sticks out of a row).
local TAB_BADGE_ROOM = 10
local UNKNOWN_COLOR = Color3.fromRGB(28, 32, 48)

export type CellState = "Unknown" | "New" | "Found"

export type Cell = {
	alienId: string,
	state: CellState,
	-- The tier's name and color, for a found alien.
	label: string,
	color: Color3,
}

export type SetState = "Collecting" | "Ready" | "Done"

export type Row = {
	-- A zone header, or a guardian row (with its set and cells).
	kind: "Zone" | "Guardian",
	title: string,
	setId: string,
	cells: { Cell },
	-- "3/5", or the claim button's text when the set is ready.
	setText: string,
	setState: SetState,
}

-- A section of the index (the usual aliens, the meteor ones), picked by a tab.
export type Tab = {
	name: string,
	text: string,
	active: () -> boolean,
	-- How many rewards wait in this section.
	badge: () -> number,
	onClick: () -> (),
}

export type Props = {
	visible: () -> boolean,
	title: string,
	hints: { string | () -> string },
	tabs: { Tab },
	rows: () -> { Row },
	setDone: string,
	onClaimAlien: (alienId: string) -> (),
	onClaimSet: (setId: string) -> (),
	onClose: () -> (),
}

local function cell(props: Props, row: () -> Row, index: number): TextButton
	local function entry(): Cell?
		return row().cells[index]
	end
	local function state(): CellState
		local current = entry()
		return if current then current.state else "Unknown"
	end
	return create("TextButton")({
		Name = `Tier{index}`,
		LayoutOrder = index,
		Size = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
		AutoButtonColor = false,
		BackgroundColor3 = function()
			local current = entry()
			return if current and state() ~= "Unknown" then current.color else UNKNOWN_COLOR
		end,
		FontFace = Theme.FONT,
		-- Scaled down to fit the cell (long tier names), no bigger than these sizes.
		TextScaled = true,
		TextColor3 = function()
			return if state() == "Unknown" then Theme.MUTED else UNKNOWN_COLOR
		end,
		Layout.maxTextSize(function()
			return if state() == "Unknown" then UNKNOWN_TEXT_SIZE else CELL_TEXT_SIZE
		end),
		TextYAlignment = function()
			return if state() == "Unknown" then Enum.TextYAlignment.Center else Enum.TextYAlignment.Bottom
		end,
		Text = function()
			local current = entry()
			return if not current or state() == "Unknown" then "?" else current.label
		end,
		Activated = function()
			local current = entry()
			if current and state() == "New" then
				props.onClaimAlien(current.alienId)
			end
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(3, 4),
		-- A new find glows until its reward is taken.
		Layout.stroke(Theme.COINS, 3, function()
			return state() == "New"
		end),
	}) :: TextButton
end

local function IndexWindow(props: Props): Frame
	local function row(entry: () -> Row, order: number): Frame
		local function isZone(): boolean
			return entry().kind == "Zone"
		end
		local cells = {}
		for index = 1, 5 do
			table.insert(cells, cell(props, entry, index))
		end
		return create("Frame")({
			Name = "Row",
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Zone",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, ZONE_TEXT_SIZE + 10),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = ZONE_TEXT_SIZE,
				TextColor3 = Theme.SPEED,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				Visible = isZone,
				Text = function()
					return entry().title
				end,
			}),
			create("Frame")({
				Name = "Header",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				BackgroundTransparency = 1,
				Visible = function()
					return not isZone()
				end,
				create("TextLabel")({
					Name = "Guardian",
					Size = UDim2.fromScale(0.55, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = ROW_TEXT_SIZE,
					TextColor3 = Theme.TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = function()
						return entry().title
					end,
				}),
				create("TextLabel")({
					Name = "SetCount",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.45, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = ROW_TEXT_SIZE,
					TextColor3 = function()
						return if entry().setState == "Done" then Theme.TOAST_GOOD else Theme.MUTED
					end,
					TextXAlignment = Enum.TextXAlignment.Right,
					Visible = function()
						return entry().setState ~= "Ready"
					end,
					Text = function()
						return if entry().setState == "Done" then props.setDone else entry().setText
					end,
				}),
			}),
			create("Frame")({
				Name = "Cells",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, CELL_SIZE),
				BackgroundTransparency = 1,
				Visible = function()
					return not isZone()
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				cells,
			}),
			create("Frame")({
				Name = "SetClaim",
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = function()
					return not isZone() and entry().setState == "Ready"
				end,
				Button({
					name = "ClaimSet",
					text = function()
						return entry().setText
					end,
					color = Theme.COINS_DARK,
					onClick = function()
						props.onClaimSet(entry().setId)
					end,
				}),
			}),
		}) :: Frame
	end

	local tabButtons = {}
	for order, tab in props.tabs do
		table.insert(
			tabButtons,
			Button({
				name = tab.name,
				layoutOrder = order,
				text = tab.text,
				badge = tab.badge,
				-- The open section stands out; the other one is dimmed until picked.
				dimmed = function()
					return not tab.active()
				end,
				onClick = tab.onClick,
			})
		)
	end
	local tabs = create("Frame")({
		Name = "Tabs",
		LayoutOrder = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP + TAB_BADGE_ROOM),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Layout.padding(0, TAB_BADGE_ROOM),
		tabButtons,
	})

	return Window({
		name = "IndexWindow",
		visible = props.visible,
		title = props.title,
		hints = props.hints,
		maxSize = MAX_SIZE,
		onClose = props.onClose,
		rows = { tabs, indexes(props.rows, row) },
	})
end

return IndexWindow
