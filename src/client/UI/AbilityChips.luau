--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A row of chips at the bottom of the screen, one per attack: its name, and while it cools
-- down, the seconds left. Shown while flying.

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
	-- "1.2s" while cooling, "" when ready.
	cooldown: () -> string,
	cooling: () -> boolean,
}

export type Props = {
	visible: () -> boolean,
	chips: { Chip },
}

local function AbilityChip(chip: Chip, order: number): Frame
	return create("Frame")({
		Name = chip.label,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = function()
			return if chip.cooling() then COOLING_TRANSPARENCY else Theme.PANEL_TRANSPARENCY
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(PADDING, PADDING / 2),
		create("TextLabel")({
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
