--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- On-screen buttons for touch devices, shown while flying: the attacks, up, down, slow mode.
-- The buttons drive the input actions through UIButton bindings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create

local BUTTON_SIZE = 72
local GAP = 12
-- Keeps the buttons clear of Roblox's own touch jump button in the bottom-right corner.
local RIGHT_OFFSET = 200

export type Props = {
	visible: () -> boolean,
	-- Called once with each created button so it can be bound to its input action.
	onButton: (actionName: string, button: GuiButton) -> (),
	ascendAction: string,
	descendAction: string,
	-- The attacks, top to bottom, each with its word; a cooling one is dimmed.
	abilities: { { action: string, text: string, cooling: () -> boolean } },
	-- The slow mode switch; it lights up while on.
	slowMode: { action: string, text: string, active: () -> boolean },
}

local COOLING_TRANSPARENCY = 0.7

local function FlightButton(
	symbol: string,
	order: number,
	textSize: number,
	color: Color3 | () -> Color3,
	dimmed: (() -> boolean)?,
	onCreated: (GuiButton) -> ()
): TextButton
	return create("TextButton")({
		Name = symbol,
		LayoutOrder = order,
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		BackgroundColor3 = color,
		BackgroundTransparency = function()
			return if dimmed and dimmed() then COOLING_TRANSPARENCY else Theme.PANEL_TRANSPARENCY
		end,
		FontFace = Theme.FONT,
		TextSize = textSize,
		TextColor3 = Theme.TEXT,
		Text = symbol,
		AutoButtonColor = true,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		action(function(instance)
			onCreated(instance :: GuiButton)
		end),
	}) :: TextButton
end

local function FlightButtons(props: Props): Frame
	local abilityButtons: { TextButton } = {}
	for order, ability in props.abilities do
		table.insert(
			abilityButtons,
			FlightButton(ability.text, order, Theme.TEXT_SIZE, Theme.DANGER, ability.cooling, function(button)
				props.onButton(ability.action, button)
			end)
		)
	end
	return create("Frame")({
		Name = "FlightButtons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -RIGHT_OFFSET, 1, -Theme.MARGIN),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.visible,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		abilityButtons,
		FlightButton("▲", #props.abilities + 1, BUTTON_SIZE / 2, Theme.PANEL, nil, function(button)
			props.onButton(props.ascendAction, button)
		end),
		FlightButton("▼", #props.abilities + 2, BUTTON_SIZE / 2, Theme.PANEL, nil, function(button)
			props.onButton(props.descendAction, button)
		end),
		FlightButton(
			props.slowMode.text,
			#props.abilities + 3,
			Theme.TEXT_SIZE,
			function()
				return if props.slowMode.active() then Theme.SELECTED else Theme.PANEL
			end,
			nil,
			function(button)
				props.onButton(props.slowMode.action, button)
			end
		),
	}) :: Frame
end

return FlightButtons
