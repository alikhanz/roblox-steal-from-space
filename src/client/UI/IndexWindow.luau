--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The alien index window (docs/design/screens/index.md) in a neon window. Left: the switch of
-- the sections (the usual aliens, the meteor ones) and the four zones with how much of each is
-- found. Right: the six guardians of the picked zone, a row each: the name, a cell per tier
-- (an unknown alien is a dark "?", a found one is drawn in its tier's colour, a new one glows
-- gold until tapped for its reward) and the set at the end (count, claim button, done). The
-- footer counts the section and holds "Claim all". Data and texts come in ready from the
-- controller; claims are requests to the server.

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
local INDEX_COLOR = NEON.TILE.Index
local GOLD = NEON.ACTION.Coins
local CHECK_COLOR = Color3.fromHex("#5BDB6E")
local CHECK_MARK = "✓"
local COLUMN_GAP = 10
-- Left column.
local SIDE_WIDTH = 160
local SWITCH_HEIGHT = 30
local SIDE_GAP = 6
local ZONE_BAR_HEIGHT = 6
local DOT_SIZE = 10
local BADGE_SIZE = 18
-- Right part: the tier names over the columns, then a row per guardian.
local HEAD_HEIGHT = 16
local ROW_GAP = 4
local CELL_SIZE = 30
local CELL_COLUMN = 50
local END_WIDTH = 80
local ROW_PADDING = 8
local CELL_CORNER = UDim.new(0, 8)
-- The alien in a cell: a ball in its tier's colour with two dark eyes (like the greybox alien
-- in the bay), against the cell's size.
local ALIEN_WIDTH = 0.66
local ALIEN_HEIGHT = 0.6
local EYE_SIZE = Vector2.new(3, 5)
local EYE_SPREAD = 0.2
local EYE_HEIGHT = 0.4
local EYE_COLOR = Color3.fromHex("#14141E")
-- The ball keeps its tier's colour full; the cell's fill behind it stays faint, so it stands out.
local ALIEN_LIGHTEN = 0
local GLASS_TRANSPARENCY = 0.965
local FOUND_FILL_TRANSPARENCY = 0.86
local NEW_GLOW_SHARE = 1.9
local NEW_GLOW_TRANSPARENCY = 0.35

export type CellState = "Unknown" | "New" | "Found"

export type Cell = {
	alienId: string,
	state: CellState,
	-- The tier's colour.
	color: Color3,
}

export type SetState = "Collecting" | "Ready" | "Done"

export type Guardian = {
	title: string,
	setId: string,
	cells: { Cell },
	setState: SetState,
	-- "3/5" while collecting, the reward ("●+18K") when ready.
	setText: string,
}

export type Zone = {
	name: string,
	-- "19/30"
	count: string,
	-- 0..1
	share: number,
	-- A reward waits in this zone.
	waiting: boolean,
	selected: boolean,
}

-- A section of the index (the usual aliens, the meteor ones).
export type Section = {
	text: string,
	active: () -> boolean,
	-- How many rewards wait in this section.
	badge: () -> number,
	onClick: () -> (),
}

export type Tier = {
	name: string,
	color: Color3,
}

export type Texts = {
	title: string,
	guardian: string,
	setDone: string,
	claimAll: string,
	-- "Found 26 of 120" and a line under it (empty for none).
	found: () -> string,
	hint: () -> string,
}

export type Props = {
	visible: () -> boolean,
	coins: () -> string,
	texts: Texts,
	sections: { Section },
	zones: () -> { Zone },
	tiers: { Tier },
	guardians: () -> { Guardian },
	onZone: (index: number) -> (),
	onClaimAlien: (alienId: string) -> (),
	onClaimSet: (setId: string) -> (),
	canClaimAll: () -> boolean,
	onClaimAll: () -> (),
	onClose: () -> (),
}

local function text(
	name: string,
	value: string | () -> string,
	options: {
		size: number?,
		color: (Color3 | () -> Color3)?,
		align: Enum.TextXAlignment?,
		order: number?,
		width: UDim2?,
	}
): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = options.order or 0,
		Size = options.width or UDim2.new(),
		AutomaticSize = if options.width then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = options.size or NEON.TEXT_BODY,
		TextColor3 = options.color or NEON.TEXT,
		TextXAlignment = options.align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = value,
		Layout.textStroke(),
	}) :: TextLabel
end

local function outline(color: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	return stroke
end

-- A red bubble with a count, on a corner.
local function Badge(count: () -> number): TextLabel
	return create("TextLabel")({
		Name = "Badge",
		ZIndex = 3,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 2, 0, 0),
		Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
		BackgroundColor3 = NEON.DANGER,
		FontFace = NEON.FONT,
		TextSize = NEON.TEXT_SMALL,
		TextColor3 = Color3.new(1, 1, 1),
		Text = function()
			return tostring(count())
		end,
		Visible = function()
			return count() > 0
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		outline(Color3.new(1, 1, 1), 2),
	}) :: TextLabel
end

local function SectionSwitch(sections: { Section }): Frame
	local halves = {}
	for order, section in sections do
		local corner = UDim.new(0.5, 0)
		local glass = Layout.glass(INDEX_COLOR, corner, true)
		local fill = glass[1] :: Frame
		local line = glass[2] :: UIStroke
		Vide.effect(function()
			fill.Visible = section.active()
			line.Enabled = section.active()
		end)
		table.insert(
			halves,
			create("TextButton")({
				Name = `Section{order}`,
				LayoutOrder = order,
				Size = UDim2.new(1 / #sections, -2, 1, 0),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Activated = function()
					section.onClick()
				end,
				create("UICorner")({ CornerRadius = corner }),
				glass,
				create("TextLabel")({
					Name = "Label",
					ZIndex = 1,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_SMALL,
					TextColor3 = function()
						return if section.active() then NEON.TEXT else NEON.MUTED
					end,
					Text = section.text,
					Layout.textStroke(),
				}),
				Badge(section.badge),
			})
		)
	end
	return create("Frame")({
		Name = "Sections",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, SWITCH_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = GLASS_TRANSPARENCY,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		Layout.panelLine(),
		Layout.padding(3, 3),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		halves,
	}) :: Frame
end

local function ZoneButton(zone: () -> Zone, index: number, props: Props): TextButton
	local function selected(): boolean
		return zone().selected
	end
	local stroke = outline(NEON.LINE, 1)
	Vide.effect(function()
		local on = selected()
		stroke.Color = if on then Layout.lineColor(INDEX_COLOR) else NEON.LINE
		stroke.Thickness = if on then NEON.LINE_THICKNESS else 1
		stroke.Transparency = if on then 0 else 0.7
	end)
	return create("TextButton")({
		Name = "Zone",
		LayoutOrder = index + 1,
		Size = UDim2.new(1, 0, 0.25, -(SWITCH_HEIGHT + SIDE_GAP * 4) / 4),
		BackgroundColor3 = function()
			return if selected() then INDEX_COLOR else Color3.new(1, 1, 1)
		end,
		BackgroundTransparency = function()
			return if selected() then 0.82 else GLASS_TRANSPARENCY
		end,
		AutoButtonColor = false,
		Text = "",
		Activated = function()
			props.onZone(index)
		end,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		stroke,
		Layout.padding(9, 6),
		text("Name", function()
			return zone().name
		end, { size = NEON.TEXT_BODY, width = UDim2.new(1, -DOT_SIZE - 4, 0.5, 0) }),
		create("Frame")({
			Name = "Dot",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE),
			BackgroundColor3 = NEON.DANGER,
			Visible = function()
				return zone().waiting
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			outline(Color3.new(1, 1, 1), 1.5),
		}),
		create("Frame")({
			Name = "Progress",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.45),
			BackgroundTransparency = 1,
			create("Frame")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, -44, 0, ZONE_BAR_HEIGHT),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.9,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				create("Frame")({
					Name = "Fill",
					Size = function()
						return UDim2.fromScale(math.clamp(zone().share, 0, 1), 1)
					end,
					Visible = function()
						return zone().share > 0
					end,
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					create("UIGradient")({
						Color = ColorSequence.new(INDEX_COLOR, INDEX_COLOR:Lerp(Color3.new(1, 1, 1), 0.55)),
					}),
				}),
			}),
			create("TextLabel")({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 40, 1, 0),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SMALL,
				TextColor3 = NEON.MUTED,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = function()
					return zone().count
				end,
				Layout.textStroke(),
			}),
		}),
	}) :: TextButton
end

local function Side(props: Props): Frame
	return create("Frame")({
		Name = "Side",
		Size = UDim2.new(0, SIDE_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, SIDE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		SectionSwitch(props.sections),
		indexes(props.zones, function(zone: () -> Zone, index: number)
			return ZoneButton(zone, index, props)
		end),
	}) :: Frame
end

-- The alien drawn in a cell: a ball with a light spot and two eyes.
local function Alien(color: () -> Color3): Frame
	local function eye(name: string, side: number): Frame
		return create("Frame")({
			Name = name,
			ZIndex = 2,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + side * EYE_SPREAD, EYE_HEIGHT),
			Size = UDim2.fromOffset(EYE_SIZE.X, EYE_SIZE.Y),
			BackgroundColor3 = EYE_COLOR,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}) :: Frame
	end
	return create("Frame")({
		Name = "Alien",
		ZIndex = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(ALIEN_WIDTH, ALIEN_HEIGHT),
		BackgroundTransparency = 1,
		create("ImageLabel")({
			Name = "Body",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageColor3 = function()
				return color():Lerp(Color3.new(1, 1, 1), ALIEN_LIGHTEN)
			end,
		}),
		create("ImageLabel")({
			Name = "Shine",
			ZIndex = 2,
			Position = UDim2.fromScale(0.18, 0.1),
			Size = UDim2.fromScale(0.28, 0.28),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageTransparency = 0.55,
		}),
		eye("LeftEye", -1),
		eye("RightEye", 1),
	}) :: Frame
end

local function CellView(guardian: () -> Guardian, index: number, props: Props): Frame
	local function entry(): Cell?
		return guardian().cells[index]
	end
	local function state(): CellState
		local current = entry()
		return if current then current.state else "Unknown"
	end
	local function color(): Color3
		local current = entry()
		return if current then current.color else NEON.MUTED
	end
	local stroke = outline(NEON.LINE, 1)
	Vide.effect(function()
		local current = state()
		if current == "New" then
			stroke.Color = GOLD
			stroke.Thickness = 2.5
			stroke.Transparency = 0
		elseif current == "Found" then
			stroke.Color = Layout.lineColor(color())
			stroke.Thickness = NEON.LINE_THICKNESS
			stroke.Transparency = 0
		else
			stroke.Color = NEON.LINE
			stroke.Thickness = 1
			stroke.Transparency = 0.75
		end
	end)
	return create("Frame")({
		Name = `Tier{index}`,
		LayoutOrder = index + 1,
		Size = UDim2.new(0, CELL_COLUMN, 1, 0),
		BackgroundTransparency = 1,
		create("ImageLabel")({
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CELL_SIZE * NEW_GLOW_SHARE, CELL_SIZE * NEW_GLOW_SHARE),
			BackgroundTransparency = 1,
			Image = Icons.GLOW,
			ImageColor3 = GOLD,
			ImageTransparency = NEW_GLOW_TRANSPARENCY,
			Visible = function()
				return state() == "New"
			end,
		}),
		create("TextButton")({
			Name = "Cell",
			ZIndex = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
			BackgroundColor3 = function()
				return if state() == "Unknown" then Color3.new(1, 1, 1) else color()
			end,
			BackgroundTransparency = function()
				return if state() == "Unknown" then 0.95 else FOUND_FILL_TRANSPARENCY
			end,
			AutoButtonColor = false,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SECTION,
			TextColor3 = NEON.MUTED,
			Text = function()
				return if state() == "Unknown" then "?" else ""
			end,
			Activated = function()
				local current = entry()
				if current and current.state == "New" then
					props.onClaimAlien(current.alienId)
				end
			end,
			create("UICorner")({ CornerRadius = CELL_CORNER }),
			stroke,
			create("Frame")({
				Name = "Holder",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = function()
					return state() ~= "Unknown"
				end,
				Alien(color),
			}),
		}),
	}) :: Frame
end

-- The end of a guardian's row: the count, the set's claim button, or its done mark.
local function SetEnd(guardian: () -> Guardian, props: Props): Frame
	local function state(): SetState
		return guardian().setState
	end
	return create("Frame")({
		Name = "Set",
		LayoutOrder = 7,
		Size = UDim2.new(0, END_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("TextLabel")({
			Name = "Count",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = function()
				return if state() == "Done" then CHECK_COLOR else NEON.MUTED
			end,
			Text = function()
				return if state() == "Done" then `{CHECK_MARK} {props.texts.setDone}` else guardian().setText
			end,
			Visible = function()
				return state() ~= "Ready"
			end,
			Layout.textStroke(),
		}),
		ActionButton({
			name = "ClaimSet",
			text = function()
				return guardian().setText
			end,
			color = GOLD,
			size = "Small",
			layoutOrder = 2,
			visible = function()
				return state() == "Ready"
			end,
			onClick = function()
				props.onClaimSet(guardian().setId)
			end,
		}),
	}) :: Frame
end

local function cellsWidth(): number
	return CELL_COLUMN * 5
end

local function GuardianRow(guardian: () -> Guardian, order: number, props: Props): Frame
	local function ready(): boolean
		return guardian().setState == "Ready"
	end
	local stroke = outline(NEON.LINE, 1)
	Vide.effect(function()
		local on = ready()
		stroke.Color = if on then Layout.lineColor(GOLD) else NEON.LINE
		stroke.Transparency = if on then 0 else 0.82
	end)
	local cells = {}
	for index = 1, 5 do
		table.insert(cells, CellView(guardian, index, props))
	end
	return create("Frame")({
		Name = "Guardian",
		LayoutOrder = order + 1,
		Size = UDim2.new(1, 0, 1 / 6, -(HEAD_HEIGHT + ROW_GAP * 6) / 6),
		BackgroundColor3 = function()
			return if ready() then GOLD else Color3.new(1, 1, 1)
		end,
		BackgroundTransparency = function()
			return if ready() then 0.9 else GLASS_TRANSPARENCY
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 9) }),
		stroke,
		Layout.padding(ROW_PADDING, 0),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		text("Name", function()
			return guardian().title
		end, { order = 1, width = UDim2.new(1, -(cellsWidth() + END_WIDTH), 1, 0) }),
		cells,
		SetEnd(guardian, props),
	}) :: Frame
end

-- The names over the columns: "Guardian", then each tier in its colour.
local function ColumnHeads(props: Props): Frame
	local heads = {}
	for index, tier in props.tiers do
		local label = text(`Tier{index}`, tier.name, {
			order = index + 1,
			size = NEON.TEXT_SMALL,
			color = tier.color,
			align = Enum.TextXAlignment.Center,
			width = UDim2.new(0, CELL_COLUMN, 1, 0),
		})
		-- A name a little wider than its column may reach into the gap beside it rather than be
		-- cut (TextScaled would not do: its size limit counts screen pixels, and the window is
		-- scaled).
		label.TextTruncate = Enum.TextTruncate.None
		table.insert(heads, label)
	end
	return create("Frame")({
		Name = "Heads",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, HEAD_HEIGHT),
		BackgroundTransparency = 1,
		Layout.padding(ROW_PADDING, 0),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		text("Guardian", props.texts.guardian, {
			order = 1,
			size = NEON.TEXT_SMALL,
			color = NEON.MUTED,
			width = UDim2.new(1, -(cellsWidth() + END_WIDTH), 1, 0),
		}),
		heads,
	}) :: Frame
end

local function Guardians(props: Props): Frame
	return create("Frame")({
		Name = "Guardians",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -(SIDE_WIDTH + COLUMN_GAP), 1, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		ColumnHeads(props),
		indexes(props.guardians, function(guardian: () -> Guardian, order: number)
			return GuardianRow(guardian, order, props)
		end),
	}) :: Frame
end

local function IndexWindow(props: Props): Frame
	local texts = props.texts
	return NeonWindow({
		name = "IndexWindow",
		visible = props.visible,
		title = texts.title,
		coins = props.coins,
		onClose = props.onClose,
		body = { Side(props), Guardians(props) },
		footer = {
			create("Frame")({
				Name = "Count",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(0.62, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 1),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				text("Found", texts.found, { order = 1, size = NEON.TEXT_BODY, width = UDim2.new(1, 0, 0, 16) }),
				create("TextLabel")({
					Name = "Hint",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_SMALL,
					TextColor3 = NEON.MUTED,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = texts.hint,
					Visible = function()
						return texts.hint() ~= ""
					end,
					Layout.textStroke(),
				}),
			}),
			create("Frame")({
				Name = "ClaimAllSlot",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				ActionButton({
					name = "ClaimAll",
					text = texts.claimAll,
					color = GOLD,
					visible = props.canClaimAll,
					onClick = props.onClaimAll,
				}),
			}),
		},
	})
end

return IndexWindow
