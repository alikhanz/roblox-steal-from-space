--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A row of chips at the bottom of the screen, one per action: the key to press, its name,
-- and while it cools down, the seconds left. Shown while flying with a keyboard or a gamepad
-- (touch screens have the buttons themselves).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local GAP = 8
local PADDING = 10
-- Above the oxygen bar.
local BOTTOM_OFFSET = 70
local COOLING_TRANSPARENCY = 0.6

export type Chip = {
	label: string,
	-- The key to press, e.g. "F", "LMB", "R2".
	key: () -> string,
	-- "1.2s" while cooling, "" when ready.
	cooldown: () -> string,
	cooling: () -> boolean,
	-- A switch that is on (slow mode): the chip lights up.
	active: (() -> boolean)?,
}

local KEY_PADDING = 6

export type Props = {
	visible: () -> boolean,
	chips: { Chip },
}

local function AbilityChip(chip: Chip, order: number): Frame
	return create("Frame")({
		Name = chip.label,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = function()
			return if chip.active and chip.active() then Theme.SELECTED else Theme.PANEL
		end,
		BackgroundTransparency = function()
			return if chip.cooling() then COOLING_TRANSPARENCY else Theme.PANEL_TRANSPARENCY
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(PADDING, PADDING / 2),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- The key, boxed like the badge over an egg.
		create("TextLabel")({
			Name = "Key",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.OXYGEN,
			BackgroundTransparency = function()
				return if chip.cooling() then COOLING_TRANSPARENCY else 0
			end,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.PANEL,
			Text = chip.key,
			create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			Layout.padding(KEY_PADDING, 2),
		}),
		create("TextLabel")({
			Name = "Label",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = function()
				return if chip.cooling() then Theme.MUTED else Theme.TEXT
			end,
			Text = function()
				local left = chip.cooldown()
				return if left ~= "" then `{chip.label} · {left}` else chip.label
			end,
		}),
	}) :: Frame
end

local function AbilityChips(props: Props): Frame
	local chips: { Frame } = {}
	for order, chip in props.chips do
		table.insert(chips, AbilityChip(chip, order))
	end
	return create("Frame")({
		Name = "AbilityChips",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.visible,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		chips,
	}) :: Frame
end

return AbilityChips
