--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- On-screen buttons for touch devices, shown while flying: strike, up, down.
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
	strikeAction: string,
	-- The strike button's word; the others are arrows.
	strikeText: string,
}

local function FlightButton(
	symbol: string,
	order: number,
	textSize: number,
	color: Color3,
	onCreated: (GuiButton) -> ()
): TextButton
	return create("TextButton")({
		Name = symbol,
		LayoutOrder = order,
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		BackgroundColor3 = color,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
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

		FlightButton(props.strikeText, 1, Theme.TEXT_SIZE, Theme.DANGER, function(button)
			props.onButton(props.strikeAction, button)
		end),
		FlightButton("▲", 2, BUTTON_SIZE / 2, Theme.PANEL, function(button)
			props.onButton(props.ascendAction, button)
		end),
		FlightButton("▼", 3, BUTTON_SIZE / 2, Theme.PANEL, function(button)
			props.onButton(props.descendAction, button)
		end),
	}) :: Frame
end

return FlightButtons
