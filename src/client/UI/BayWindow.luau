--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The bay window: pods, the incubator, the inventory and what waits on the floor, with the
-- actions on the selected aliens. Reads the profile copy; every action is a request to the
-- server. Texts come in resolved: the component knows no keys.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienCard = require(script.Parent.AlienCard)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local MAX_WIDTH = 760
local MAX_HEIGHT = 600
local PADDING = 16
local GAP = 10
local CARD_SIZE = UDim2.fromOffset(190, 64)
local TITLE_TEXT_SIZE = 24
local SECTION_TEXT_SIZE = 18
local HINT_TEXT_SIZE = 14
local ACTION_BAR_HEIGHT = 48
local STATUS_HEIGHT = 36
local CLOSE_SIZE = 36

export type Texts = {
	title: string,
	close: string,
	pods: string,
	emptyPod: string,
	buyPod: () -> string,
	-- "Incubator · 2/4": eggs warming of the slots.
	incubator: () -> string,
	incubatorEmpty: string,
	-- "+1 slot 450 ●".
	buySlot: () -> string,
	-- "+1 slot 19 R$".
	buySlotRobux: () -> string,
	inventory: () -> string,
	floor: () -> string,
	-- How to pick them up, or why not right now.
	floorHint: () -> string,
	autoPlace: string,
	crossbreed: string,
	crossbreedHint: string,
	sell: () -> string,
	toPod: string,
	-- "To inventory", or "Out of the pod" while the selected alien stands in one.
	toInventory: () -> string,
	-- What the selection means right now and what to do next; sits above the action buttons.
	status: () -> string,
}

export type Props = {
	visible: () -> boolean,
	bay: () -> ProfileState.Bay,
	texts: Texts,
	-- Guardian name (nil for an unknown alien), tier-and-income line and tier color of an alien.
	alienName: (alienId: string) -> string?,
	alienSubtitle: (alienId: string) -> string,
	alienColor: (alienId: string) -> Color3,
	-- Egg line: "<name> — hatches in …", refreshed by the controller.
	eggLine: (egg: ProfileState.Egg) -> string,
	-- A queued egg's line: "<name> — waiting for a slot".
	waitingLine: (egg: ProfileState.WaitingEgg) -> string,
	isSelected: (uid: number) -> boolean,
	-- True for an alien that cannot join the current crossbreed selection.
	isDimmed: (alienId: string) -> boolean,
	onToggle: (uid: number) -> (),
	canCrossbreed: () -> boolean,
	canSell: () -> boolean,
	canMoveToPod: () -> boolean,
	canMoveToInventory: () -> boolean,
	canBuyPod: () -> boolean,
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

local function sectionTitle(text: string | () -> string, order: number, visible: (() -> boolean)?): TextLabel
	return create("TextLabel")({
		Name = "SectionTitle",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = SECTION_TEXT_SIZE,
		TextColor3 = Theme.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = visible or true,
		Text = text,
	}) :: TextLabel
end

local function hint(text: string | () -> string, order: number, visible: (() -> boolean)?): TextLabel
	return create("TextLabel")({
		Name = "Hint",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = HINT_TEXT_SIZE,
		TextColor3 = Theme.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Visible = visible or true,
		Text = text,
	}) :: TextLabel
end

local function grid(name: string, order: number, children: any): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create("UIGridLayout")({
			CellSize = CARD_SIZE,
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		children,
	}) :: Frame
end

local function BayWindow(props: Props): Frame
	local texts = props.texts

	local function card(alien: () -> ProfileState.Alien?, order: number): TextButton
		return AlienCard({
			layoutOrder = order,
			title = function()
				local record = alien()
				return if record then props.alienName(record.id) else nil
			end,
			subtitle = function()
				local record = alien()
				return if record then props.alienSubtitle(record.id) else ""
			end,
			color = function()
				local record = alien()
				return if record then props.alienColor(record.id) else Theme.PANEL
			end,
			selected = function()
				local record = alien()
				return record ~= nil and props.isSelected(record.uid)
			end,
			dimmed = function()
				local record = alien()
				return record ~= nil and props.isDimmed(record.id)
			end,
			emptyText = texts.emptyPod,
			onTap = function()
				local record = alien()
				if record then
					props.onToggle(record.uid)
				end
			end,
		})
	end

	local pods = indexes(function()
		return props.bay().pods
	end, function(pod, index)
		return card(function()
			return pod().alien
		end, index)
	end)
	local inventory = indexes(function()
		return props.bay().inventory
	end, function(alien, index)
		return card(alien, index)
	end)
	local floor = indexes(function()
		return props.bay().floor
	end, function(alien, index)
		return card(alien, index)
	end)
	local eggs = indexes(function()
		return props.bay().incubator
	end, function(egg, index)
		return hint(function()
			return props.eggLine(egg())
		end, index)
	end)
	-- The queue after the eggs warming: ordered after any number of them.
	local waitingEggs = indexes(function()
		return props.bay().waiting
	end, function(egg, index)
		return hint(function()
			return props.waitingLine(egg())
		end, BayConfig.MAX_INCUBATOR_SLOTS + (index :: number))
	end)

	return create("Frame")({
		Name = "BayWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.88),
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = 0.05,
		Visible = props.visible,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.maxSize(MAX_WIDTH, MAX_HEIGHT),
		Layout.padding(PADDING, PADDING),

		create("TextLabel")({
			Name = "Title",
			Size = UDim2.new(1, -CLOSE_SIZE, 0, CLOSE_SIZE),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = TITLE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = texts.title,
		}),
		create("TextButton")({
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
			BackgroundColor3 = Theme.DANGER,
			FontFace = Theme.FONT,
			TextSize = TITLE_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			Text = "×",
			Activated = function()
				props.onClose()
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),

		create("ScrollingFrame")({
			Name = "Sections",
			Position = UDim2.fromOffset(0, CLOSE_SIZE + GAP),
			Size = UDim2.new(1, 0, 1, -(CLOSE_SIZE + STATUS_HEIGHT + ACTION_BAR_HEIGHT + GAP * 3)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Layout.padding(GAP),

			sectionTitle(texts.pods, 1),
			grid("Pods", 2, pods),
			sectionTitle(texts.incubator, 3),
			create("Frame")({
				Name = "Incubator",
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				hint(texts.incubatorEmpty, 0, function()
					return #props.bay().incubator == 0
				end),
				eggs,
				waitingEggs,
			}),
			sectionTitle(texts.inventory, 5),
			hint(texts.crossbreedHint, 6),
			grid("Inventory", 7, inventory),
			sectionTitle(texts.floor, 8, function()
				return #props.bay().floor > 0
			end),
			hint(texts.floorHint, 9, function()
				return #props.bay().floor > 0
			end),
			grid("Floor", 10, floor),
		}),

		create("TextLabel")({
			Name = "Status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -(ACTION_BAR_HEIGHT + GAP)),
			Size = UDim2.new(1, 0, 0, STATUS_HEIGHT),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = HINT_TEXT_SIZE,
			TextColor3 = Theme.SPEED,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextWrapped = true,
			Text = texts.status,
		}),

		create("Frame")({
			Name = "Actions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, ACTION_BAR_HEIGHT),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
			}),
			Button({ name = "AutoPlace", layoutOrder = 1, text = texts.autoPlace, onClick = props.onAutoPlace }),
			Button({
				name = "ToPod",
				layoutOrder = 2,
				text = texts.toPod,
				enabled = props.canMoveToPod,
				onClick = props.onMoveToPod,
			}),
			Button({
				name = "ToInventory",
				layoutOrder = 3,
				text = texts.toInventory,
				enabled = props.canMoveToInventory,
				onClick = props.onMoveToInventory,
			}),
			Button({
				name = "Crossbreed",
				layoutOrder = 4,
				text = texts.crossbreed,
				enabled = props.canCrossbreed,
				onClick = props.onCrossbreed,
			}),
			Button({
				name = "Sell",
				layoutOrder = 5,
				text = texts.sell,
				enabled = props.canSell,
				color = Theme.DANGER,
				onClick = props.onSell,
			}),
			Button({
				name = "BuyPod",
				layoutOrder = 6,
				text = texts.buyPod,
				enabled = props.canBuyPod,
				color = Theme.COINS_DARK,
				onClick = props.onBuyPod,
			}),
			create("Frame")({
				Name = "BuySlotSlot",
				LayoutOrder = 7,
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Visible = props.slotForSale,
				Button({
					name = "BuySlot",
					text = texts.buySlot,
					enabled = props.canBuySlot,
					color = Theme.COINS_DARK,
					onClick = props.onBuySlot,
				}),
			}),
			create("Frame")({
				Name = "BuySlotRobuxSlot",
				LayoutOrder = 8,
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Visible = props.slotForRobux,
				Button({
					name = "BuySlotRobux",
					text = texts.buySlotRobux,
					color = Theme.TOAST_GOOD,
					onClick = props.onBuySlotRobux,
				}),
			}),
		}),
	}) :: Frame
end

return BayWindow
