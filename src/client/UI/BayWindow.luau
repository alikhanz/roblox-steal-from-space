--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The bay window (docs/design/screens/bay-window.md): two columns in a neon window. Left: the
-- pods as a list by income, one row for the free ones, the big "best into pods" and "+ pod"
-- buttons. Right: the incubator's slots with timers, the queue, buying slots, the inventory and
-- the floor, the crossbreed note. The footer: the selected alien and its actions, or what to
-- do. Rows come in ready (sorted, worded) from the controller; every action is a request to the
-- server. Texts come in resolved: the component knows no keys.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AlienPicture = require(script.Parent.AlienPicture)
local AlienRow = require(script.Parent.AlienRow)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local NEON = Theme.NEON
local COLUMN_GAP = 12
local LEFT_SHARE = 0.53
local SECTION_HEIGHT = 22
local ROW_GAP = 4
local ACTIONS_HEIGHT = 36
local SLOT_SIZE = Vector2.new(46, 40)
local EGG_SIZE = 26
local SLOT_CORNER = UDim.new(0, 9)
local READY_COLOR = Color3.fromHex("#43CC5F")
-- Rows past this order are the fixed lines after a list's rows.
local AFTER_ROWS = 1000
-- The footer's room for its buttons; the selected alien's words take the rest.
local FOOTER_BUTTONS_ROOM = 340
-- The selected aliens' pictures in the footer: this big, this far apart, at most this many.
local FOOTER_PICK_SIZE = 30
local FOOTER_PICK_GAP = 4
local FOOTER_PICKS_MAX = 3
-- Below the slots: the last row's timer labels hang under them.
local SLOTS_BOTTOM_ROOM = 8

local function bottomPadding(pixels: number): UIPadding
	local instance = Instance.new("UIPadding")
	instance.PaddingBottom = UDim.new(0, pixels)
	return instance
end

export type Row = {
	uid: number,
	alienId: string,
	name: string,
	-- "8.5/s".
	income: string,
	color: Color3,
	-- A badge for a variant alien; nil for a regular one.
	variant: Icons.Name?,
}

export type EggSlot = {
	color: Color3,
	-- "1:20" while it warms, "Ready!" when it is.
	label: string,
	ready: boolean,
}

-- What is selected: nothing, one alien in a pod, one elsewhere, or several (a crossbreed).
export type Selection = "None" | "Pod" | "Away" | "Many"

export type Texts = {
	title: string,
	-- "Pods 3/6".
	pods: () -> string,
	-- The pods' income together, "21.9/s".
	podsIncome: () -> string,
	-- "Free: 3"; empty when every pod is taken.
	freePods: () -> string,
	podsEmpty: string,
	autoPlace: string,
	buyPod: () -> string,
	maxPods: string,
	-- "Incubator 2/4".
	incubator: () -> string,
	incubatorEmpty: string,
	-- "Waiting for a slot: 2"; empty without a queue.
	waiting: () -> string,
	buySlot: () -> string,
	buySlotRobux: () -> string,
	inventory: () -> string,
	inventoryEmpty: string,
	floor: () -> string,
	floorHint: () -> string,
	crossbreedHint: string,
	-- The footer's line while nothing or several aliens are selected.
	status: () -> string,
	-- The selected alien: its name and "Rare · 8.5/s".
	selectedName: () -> string,
	selectedLine: () -> string,
	sell: () -> string,
	toPod: string,
	fromPod: string,
	crossbreed: string,
}

export type Props = {
	visible: () -> boolean,
	coins: () -> string,
	texts: Texts,
	pods: () -> { Row },
	inventory: () -> { Row },
	floor: () -> { Row },
	-- The incubator's eggs in their slots, and how many slots it has.
	eggs: () -> { EggSlot },
	slots: () -> number,
	selection: () -> Selection,
	-- The selected aliens' ids, in the order picked: their pictures lead the footer.
	selectedAliens: () -> { string },
	isSelected: (uid: number) -> boolean,
	-- True for an alien that cannot join the current crossbreed selection.
	isDimmed: (alienId: string) -> boolean,
	onToggle: (uid: number) -> (),
	canCrossbreed: () -> boolean,
	canMoveToPod: () -> boolean,
	canMoveToInventory: () -> boolean,
	canBuyPod: () -> boolean,
	-- Every pod the bay can hold is bought.
	podsAtMax: () -> boolean,
	-- Shown while the incubator can take another slot; enabled when it is affordable.
	canBuySlot: () -> boolean,
	slotForSale: () -> boolean,
	-- The next slot is sold for Robux too.
	slotForRobux: () -> boolean,
	onClose: () -> (),
	onAutoPlace: () -> (),
	onCrossbreed: () -> (),
	onSell: () -> (),
	onMoveToPod: () -> (),
	onMoveToInventory: () -> (),
	onBuyPod: () -> (),
	onBuySlot: () -> (),
	onBuySlotRobux: () -> (),
}

type LabelOptions = { size: number?, color: Color3?, visible: (() -> boolean)?, wrapped: boolean? }

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
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = opts.wrapped ~= false,
		Visible = opts.visible or true,
		Text = text,
		Layout.textStroke(),
	}) :: TextLabel
end

local function sectionTitle(text: () -> string, order: number, visible: (() -> boolean)?): TextLabel
	return label("Section", text, order, { size = NEON.TEXT_SECTION, color = NEON.TEXT, visible = visible })
end

local function list(name: string, order: number, children: any): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		children,
	}) :: Frame
end

local function scroller(name: string, position: UDim2, size: UDim2, children: any): ScrollingFrame
	return create("ScrollingFrame")({
		Name = name,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = NEON.LINE,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the selection frame and the scroll bar.
		Layout.padding(3, 3),
		children,
	}) :: ScrollingFrame
end

-- One incubator slot: an egg in its rarity's colour with its timer or "Ready!", or empty.
local function EggCell(slot: () -> EggSlot?, order: number): Frame
	local function egg(): EggSlot?
		return slot()
	end
	return create("Frame")({
		Name = "Slot",
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = function()
			return if egg() then 0.93 else 0.98
		end,
		create("UICorner")({ CornerRadius = SLOT_CORNER }),
		Layout.panelLine(),
		create("ImageLabel")({
			Name = "Egg",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(EGG_SIZE, EGG_SIZE),
			BackgroundTransparency = 1,
			Image = Icons.ICONS.Egg,
			ImageColor3 = function()
				local current = egg()
				return if current then current.color else NEON.MUTED
			end,
			Visible = function()
				return egg() ~= nil
			end,
		}),
		create("TextLabel")({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			BackgroundColor3 = function()
				local current = egg()
				return if current and current.ready then READY_COLOR else NEON.GLASS
			end,
			BackgroundTransparency = function()
				local current = egg()
				return if current and current.ready then 0.2 else 0.15
			end,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SMALL,
			TextColor3 = NEON.TEXT,
			Text = function()
				local current = egg()
				return if current then current.label else ""
			end,
			Visible = function()
				return egg() ~= nil
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			Layout.padding(5, 0),
		}),
	}) :: Frame
end

local function BayWindow(props: Props): Frame
	local texts = props.texts

	local function rows(source: () -> { Row }, idle: boolean): any
		return indexes(source, function(row: () -> Row, index: number)
			return AlienRow({
				layoutOrder = index,
				name = function()
					return row().name
				end,
				income = function()
					return row().income
				end,
				tierColor = function()
					return row().color
				end,
				icon = function()
					return AlienIcons.iconOf(row().alienId)
				end,
				variant = function()
					return row().variant
				end,
				selected = function()
					return props.isSelected(row().uid)
				end,
				dimmed = function()
					return props.isDimmed(row().alienId)
				end,
				idle = idle,
				onTap = function()
					props.onToggle(row().uid)
				end,
			})
		end)
	end

	-- Every slot of the incubator in order: its egg, or nothing for a free one.
	local slotList = Vide.derive(function(): { { egg: EggSlot? } }
		local eggs = props.eggs()
		local result: { { egg: EggSlot? } } = {}
		for index = 1, props.slots() do
			table.insert(result, { egg = eggs[index] })
		end
		return result
	end)

	-- The selected aliens' pictures (a crossbreed's three side by side), before their words.
	local function picksWidth(): number
		local count = math.min(#props.selectedAliens(), FOOTER_PICKS_MAX)
		return if count == 0 then 0 else count * (FOOTER_PICK_SIZE + FOOTER_PICK_GAP)
	end

	local function footerPicks(): Frame
		local shown = Vide.derive(function(): { string }
			local ids = props.selectedAliens()
			return { table.unpack(ids, 1, math.min(#ids, FOOTER_PICKS_MAX)) }
		end)
		return create("Frame")({
			Name = "Picks",
			LayoutOrder = 0,
			Size = function()
				return UDim2.new(0, picksWidth(), 1, 0)
			end,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, FOOTER_PICK_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			indexes(shown, function(alienId: () -> string, index: number)
				return create("Frame")({
					Name = `Pick{index}`,
					LayoutOrder = index,
					Size = UDim2.fromOffset(FOOTER_PICK_SIZE, FOOTER_PICK_SIZE),
					BackgroundTransparency = 1,
					AlienPicture({
						icon = function()
							return AlienIcons.iconOf(alienId())
						end,
						color = function()
							local alien = AlienConfig.ALIENS[alienId()]
							return if alien then AlienLooks.TIERS[alien.tier].color else NEON.MUTED
						end,
					}),
				})
			end),
		}) :: Frame
	end

	local function footerInfo(): Frame
		local function hasOne(): boolean
			local selection = props.selection()
			return selection == "Pod" or selection == "Away"
		end
		return create("Frame")({
			Name = "Info",
			LayoutOrder = 1,
			-- Takes what the pictures and the buttons leave.
			Size = function()
				return UDim2.new(1, -(FOOTER_BUTTONS_ROOM + picksWidth()), 1, 0)
			end,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			label("Name", texts.selectedName, 1, { size = NEON.TEXT_SECTION, color = NEON.TEXT, visible = hasOne }),
			label("Line", texts.selectedLine, 2, { size = NEON.TEXT_SMALL, visible = hasOne }),
			label("Status", texts.status, 3, {
				visible = function()
					return not hasOne()
				end,
			}),
		}) :: Frame
	end

	local function footerButtons(): Frame
		local function selection(): Selection
			return props.selection()
		end
		return create("Frame")({
			Name = "Buttons",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ActionButton({
				name = "FromPod",
				text = texts.fromPod,
				color = NEON.ACTION.Move,
				layoutOrder = 1,
				enabled = props.canMoveToInventory,
				visible = function()
					return selection() == "Pod"
				end,
				onClick = props.onMoveToInventory,
			}),
			ActionButton({
				name = "ToPod",
				text = texts.toPod,
				color = NEON.ACTION.Move,
				layoutOrder = 2,
				enabled = props.canMoveToPod,
				visible = function()
					return selection() == "Away"
				end,
				onClick = props.onMoveToPod,
			}),
			ActionButton({
				name = "Sell",
				text = texts.sell,
				color = NEON.ACTION.Sell,
				layoutOrder = 3,
				visible = function()
					local current = selection()
					return current == "Pod" or current == "Away"
				end,
				onClick = props.onSell,
			}),
			ActionButton({
				name = "Crossbreed",
				text = texts.crossbreed,
				color = NEON.ACTION.Crossbreed,
				layoutOrder = 4,
				enabled = props.canCrossbreed,
				visible = function()
					return selection() ~= "None"
				end,
				onClick = props.onCrossbreed,
			}),
		}) :: Frame
	end

	local left = create("Frame")({
		Name = "Pods",
		Size = UDim2.new(LEFT_SHARE, -COLUMN_GAP / 2, 1, 0),
		BackgroundTransparency = 1,
		create("Frame")({
			Name = "Head",
			Size = UDim2.new(1, 0, 0, SECTION_HEIGHT),
			BackgroundTransparency = 1,
			label("Title", texts.pods, 1, { size = NEON.TEXT_SECTION, color = NEON.TEXT, wrapped = false }),
			create("Frame")({
				Name = "Income",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 3),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("ImageLabel")({
					Name = "Coin",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(15, 15),
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
					TextColor3 = NEON.MUTED,
					Text = texts.podsIncome,
					Layout.textStroke(),
				}),
			}),
		}),
		scroller(
			"List",
			UDim2.fromOffset(0, SECTION_HEIGHT + 6),
			UDim2.new(1, 0, 1, -(SECTION_HEIGHT + 6 + ACTIONS_HEIGHT + 8)),
			{
				list("Rows", 1, rows(props.pods, false)),
				-- All the free pods in one row.
				create("TextLabel")({
					Name = "Free",
					LayoutOrder = AFTER_ROWS,
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_BODY,
					TextColor3 = NEON.MUTED,
					Text = texts.freePods,
					Visible = function()
						return texts.freePods() ~= ""
					end,
					create("UICorner")({ CornerRadius = UDim.new(0, 9) }),
					Layout.panelLine(),
				}),
				label("Empty", texts.podsEmpty, AFTER_ROWS + 1, {
					visible = function()
						return #props.pods() == 0
					end,
				}),
			}
		),
		create("Frame")({
			Name = "Actions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.04, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ActionButton({
				name = "AutoPlace",
				text = texts.autoPlace,
				color = NEON.ACTION.Main,
				size = "Large",
				width = 0.48,
				layoutOrder = 1,
				onClick = props.onAutoPlace,
			}),
			ActionButton({
				name = "BuyPod",
				text = texts.buyPod,
				color = NEON.ACTION.Coins,
				size = "Large",
				width = 0.48,
				layoutOrder = 2,
				enabled = props.canBuyPod,
				visible = function()
					return not props.podsAtMax()
				end,
				onClick = props.onBuyPod,
			}),
			create("TextLabel")({
				Name = "MaxPods",
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.48, 1),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SMALL,
				TextColor3 = NEON.MUTED,
				TextWrapped = true,
				Text = texts.maxPods,
				Visible = props.podsAtMax,
			}),
		}),
	})

	local right = create("Frame")({
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1 - LEFT_SHARE, -COLUMN_GAP / 2, 1, 0),
		BackgroundTransparency = 1,
		scroller("Scroll", UDim2.new(), UDim2.fromScale(1, 1), {
			sectionTitle(texts.incubator, 1),
			create("Frame")({
				Name = "Slots",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				-- Room for the timer labels hanging below the last row of slots.
				bottomPadding(SLOTS_BOTTOM_ROOM),
				create("UIGridLayout")({
					CellSize = UDim2.fromOffset(SLOT_SIZE.X, SLOT_SIZE.Y),
					CellPadding = UDim2.fromOffset(6, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				indexes(slotList, function(slot, index)
					return EggCell(function()
						return slot().egg
					end, index)
				end),
			}),
			label("IncubatorEmpty", texts.incubatorEmpty, 3, {
				visible = function()
					return #props.eggs() == 0
				end,
			}),
			label("Waiting", texts.waiting, 4, {
				visible = function()
					return texts.waiting() ~= ""
				end,
			}),
			create("Frame")({
				Name = "BuySlots",
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = props.slotForSale,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				ActionButton({
					name = "BuySlot",
					text = texts.buySlot,
					color = NEON.ACTION.Coins,
					layoutOrder = 1,
					enabled = props.canBuySlot,
					onClick = props.onBuySlot,
				}),
				ActionButton({
					name = "BuySlotRobux",
					text = texts.buySlotRobux,
					color = NEON.ACTION.Robux,
					layoutOrder = 2,
					visible = props.slotForRobux,
					onClick = props.onBuySlotRobux,
				}),
			}),
			sectionTitle(texts.inventory, 6),
			list("Inventory", 7, rows(props.inventory, true)),
			label("InventoryEmpty", texts.inventoryEmpty, 8, {
				visible = function()
					return #props.inventory() == 0
				end,
			}),
			sectionTitle(texts.floor, 9, function()
				return #props.floor() > 0
			end),
			list("Floor", 10, rows(props.floor, true)),
			label("FloorHint", texts.floorHint, 11, {
				visible = function()
					return #props.floor() > 0
				end,
			}),
			label("Crossbreed", texts.crossbreedHint, 12, { size = NEON.TEXT_SMALL }),
		}),
	})

	return NeonWindow({
		name = "BayWindow",
		visible = props.visible,
		title = texts.title,
		coins = props.coins,
		onClose = props.onClose,
		body = { left, right },
		footer = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			footerPicks(),
			footerInfo(),
			footerButtons(),
		},
	})
end

return BayWindow
