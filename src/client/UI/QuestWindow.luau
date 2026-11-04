--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The daily quests window: one row per quest with what to do, a progress bar, the reward and a
-- button (claim when done, swap while the day's swap is unused). Texts come in resolved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Window = require(script.Parent.Window)

local create = Vide.create
local indexes = Vide.indexes

local MAX_SIZE = Vector2.new(520, 460)
local GAP = 10
local ROW_HEIGHT = 92
local ROW_PADDING = 12
local BAR_HEIGHT = 10
local SMALL_TEXT_SIZE = 14
local BUTTON_SLOT_WIDTH = 130

export type Row = {
	-- What to do, e.g. "Deliver 3 eggs".
	task: string,
	-- 0..1.
	progress: number,
	-- "2/3".
	progressText: string,
	-- "+1.2K ● · +300 ⚡"
	reward: string,
	-- Active: in progress; Done: ready to claim; Claimed: paid.
	state: "Active" | "Done" | "Claimed",
	canSwap: boolean,
}

export type Texts = {
	title: string,
	-- When new quests come and whether the swap is left.
	resetIn: () -> string,
	swapHint: () -> string,
	claim: string,
	swap: string,
	claimed: string,
}

export type Props = {
	visible: () -> boolean,
	rows: () -> { Row },
	texts: Texts,
	onClaim: (index: number) -> (),
	onSwap: (index: number) -> (),
	onClose: () -> (),
}

local function smallLabel(name: string, order: number, text: () -> string, color: Color3): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = SMALL_TEXT_SIZE,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	}) :: TextLabel
end

local function QuestWindow(props: Props): Frame
	local texts = props.texts

	local function row(entry: () -> Row, index: number): Frame
		local function state(): string
			return entry().state
		end
		return create("Frame")({
			Name = "Quest",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = function()
				return if state() == "Done" then Theme.SELECTED else Theme.PANEL
			end,
			BackgroundTransparency = function()
				return if state() == "Claimed" then Theme.PANEL_TRANSPARENCY else 0
			end,
			create("UICorner")({ CornerRadius = Theme.CORNER }),
			Layout.stroke(Theme.COINS, 2, function()
				return state() == "Done"
			end),
			Layout.padding(ROW_PADDING, ROW_PADDING),

			create("Frame")({
				Name = "Lines",
				Size = UDim2.new(1, -BUTTON_SLOT_WIDTH, 1, 0),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("TextLabel")({
					Name = "Task",
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = Theme.TEXT_SIZE,
					TextColor3 = Theme.TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					Text = function()
						return entry().task
					end,
				}),
				create("Frame")({
					Name = "Bar",
					LayoutOrder = 2,
					Size = UDim2.new(1, -GAP, 0, BAR_HEIGHT),
					BackgroundColor3 = Theme.MUTED,
					BackgroundTransparency = 0.6,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					create("Frame")({
						Name = "Fill",
						Size = function()
							return UDim2.fromScale(math.clamp(entry().progress, 0, 1), 1)
						end,
						BackgroundColor3 = Theme.COINS,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					}),
				}),
				smallLabel("Progress", 3, function()
					return `{entry().progressText}   {entry().reward}`
				end, Theme.MUTED),
			}),

			create("Frame")({
				Name = "Action",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, BUTTON_SLOT_WIDTH, 1, 0),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				create("Frame")({
					Name = "ClaimSlot",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Visible = function()
						return state() == "Done"
					end,
					Button({
						name = "Claim",
						text = texts.claim,
						color = Theme.COINS_DARK,
						onClick = function()
							props.onClaim(index)
						end,
					}),
				}),
				create("Frame")({
					Name = "SwapSlot",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Visible = function()
						return state() == "Active" and entry().canSwap
					end,
					Button({
						name = "Swap",
						text = texts.swap,
						onClick = function()
							props.onSwap(index)
						end,
					}),
				}),
				create("TextLabel")({
					Name = "Claimed",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = SMALL_TEXT_SIZE,
					TextColor3 = Theme.MUTED,
					Text = texts.claimed,
					Visible = function()
						return state() == "Claimed"
					end,
				}),
			}),
		}) :: Frame
	end

	return Window({
		name = "QuestWindow",
		visible = props.visible,
		title = texts.title,
		hints = { texts.resetIn, texts.swapHint },
		maxSize = MAX_SIZE,
		onClose = props.onClose,
		rows = indexes(props.rows, row),
	})
end

return QuestWindow
