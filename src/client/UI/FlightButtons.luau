--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The flight buttons (docs/design/screens/hud.md): round buttons of coloured glass with an
-- icon. On a touch screen they sit under the right thumb (`corner`) and each drives an input
-- action through a UIButton binding (TouchBindings), the same action the keyboard drives; with a
-- keyboard or a gamepad they make a row with their keys (`row`). A cooling button is
-- covered by a dark sector with the seconds left; a disabled one turns grey; a switched-on one
-- (slow mode) fills denser.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create
local source = Vide.source

local NEON = Theme.NEON
-- The icon's share of the button.
local ICON_SHARE = 0.55
-- The glow ring around the button, against the button's size.
local GLOW_SHARE = 1.7
local GLOW_TRANSPARENCY = 0.6
local PRESSED_SCALE = 0.92
local COOLDOWN_TRANSPARENCY = 0.35
-- A disabled button: how see-through its glass gets.
local DISABLED_TRANSPARENCY = 0.6
-- The whole group's box, points: big enough for every button's place in it.
local AREA = Vector2.new(300, 170)
-- The PC row: space between buttons; the key cap's height and how far it sticks out.
local ROW_GAP = 12
local KEY_HEIGHT = 17
local KEY_OUT = 6

export type ButtonSpec = {
	name: string,
	-- The input action it drives (FlightInputs).
	action: string,
	icon: Icons.Name,
	color: Color3,
	-- Diameter, points; on a touch screen also the distance of its outer edges from the screen's
	-- right and bottom (the PC row lays its buttons out itself).
	size: number,
	right: number?,
	bottom: number?,
	-- The key that drives it, on a key cap (the PC and gamepad row); empty: none shown.
	keyText: (() -> string)?,
	-- The part of the cooldown still to run (1 just used .. 0 ready) and its seconds.
	cooldown: (() -> number)?,
	seconds: (() -> number)?,
	-- Works only while this says so; otherwise grey.
	enabled: (() -> boolean)?,
	-- A switch that is on (slow mode).
	active: (() -> boolean)?,
}

export type Props = {
	visible: () -> boolean,
	buttons: { ButtonSpec },
	-- Called once with each created button so it can be bound to its input action.
	onButton: (actionName: string, button: GuiButton) -> (),
}

-- One half of the cooldown sector: a dark disc clipped to the left or right half of the
-- button, with a gradient that leaves only the part of the circle still cooling. Together the
-- halves cover the circle clockwise from twelve o'clock by `fraction`.
local function sectorHalf(side: "Left" | "Right", fraction: () -> number): Frame
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	Vide.effect(function()
		local share = fraction()
		if side == "Right" then
			gradient.Rotation = if share <= 0.5 then 360 * share else 180
		else
			gradient.Rotation = 360 * share
		end
	end)
	return create("Frame")({
		Name = `Cooldown{side}`,
		ZIndex = 3,
		Position = if side == "Left" then UDim2.fromScale(0, 0) else UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = function()
			local share = fraction()
			return if side == "Right" then share > 0 else share > 0.5
		end,
		create("ImageLabel")({
			Name = "Disc",
			ZIndex = 3,
			Position = if side == "Left" then UDim2.fromScale(0, 0) else UDim2.fromScale(-1, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = COOLDOWN_TRANSPARENCY,
			gradient,
		}),
	}) :: Frame
end

-- The key cap on a button's bottom-right corner (the PC and gamepad row).
local function KeyCap(keyText: () -> string): TextLabel
	return create("TextLabel")({
		Name = "Key",
		ZIndex = 5,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, KEY_OUT, 1, KEY_OUT),
		Size = UDim2.fromOffset(0, KEY_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = NEON.GLASS,
		FontFace = NEON.FONT,
		TextSize = NEON.TEXT_SMALL,
		TextColor3 = NEON.TEXT,
		Text = keyText,
		Visible = function()
			return keyText() ~= ""
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		Layout.panelLine(),
		Layout.padding(4, 0),
		Layout.minSize(KEY_HEIGHT, KEY_HEIGHT),
	}) :: TextLabel
end

local function FlightButton(spec: ButtonSpec, order: number, onButton: ((string, GuiButton) -> ())?): ImageButton
	local pressed = source(false)
	local function isEnabled(): boolean
		return if spec.enabled then spec.enabled() else true
	end
	local function isActive(): boolean
		return if spec.active then spec.active() else false
	end
	local function fraction(): number
		return if spec.cooldown then spec.cooldown() else 0
	end

	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(spec.color, corner)
	local fill = glass[1] :: Frame
	local outline = glass[2] :: UIStroke
	fill.ZIndex = 1
	local gradient = fill:FindFirstChildOfClass("UIGradient") :: UIGradient
	local pressScale = Instance.new("UIScale")
	Vide.effect(function()
		local enabled = isEnabled()
		local dense = isActive()
		fill.BackgroundTransparency = if enabled then 0 else DISABLED_TRANSPARENCY
		outline.Color = if enabled then Layout.lineColor(spec.color) else NEON.MUTED
		outline.Transparency = if enabled then 0 else DISABLED_TRANSPARENCY
		gradient.Transparency = if dense
			then NumberSequence.new(NEON.DENSE_FILL_TOP, NEON.DENSE_FILL_BOTTOM)
			else NumberSequence.new(NEON.FILL_TOP, NEON.FILL_BOTTOM)
		pressScale.Scale = if pressed() and enabled then PRESSED_SCALE else 1
	end)

	local right, bottom = spec.right, spec.bottom
	return create("ImageButton")({
		Name = spec.name,
		LayoutOrder = order,
		-- Placed at its spot in the corner, or left to the row's list layout.
		AnchorPoint = if right then Vector2.new(1, 1) else Vector2.zero,
		Position = if right and bottom then UDim2.new(1, -right, 1, -bottom) else UDim2.new(),
		Size = UDim2.fromOffset(spec.size, spec.size),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Layout.followPress(pressed),
		action(function(instance)
			if onButton then
				onButton(spec.action, instance :: GuiButton)
			end
		end),
		if spec.keyText then KeyCap(spec.keyText) else nil,

		-- What is seen shrinks on a press; the button's place stays, so a row does not move.
		create("Frame")({
			Name = "Face",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("UICorner")({ CornerRadius = corner }),
			pressScale,
			create("ImageLabel")({
				Name = "Glow",
				ZIndex = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(GLOW_SHARE, GLOW_SHARE),
				BackgroundTransparency = 1,
				Image = Icons.GLOW,
				ImageColor3 = spec.color,
				ImageTransparency = GLOW_TRANSPARENCY,
				Visible = isEnabled,
			}),
			glass,
			create("ImageLabel")({
				Name = "Icon",
				ZIndex = 2,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(ICON_SHARE, ICON_SHARE),
				BackgroundTransparency = 1,
				Image = Icons.ICONS[spec.icon],
				ImageColor3 = function()
					return if isEnabled() then Layout.iconColor(spec.color) else NEON.MUTED
				end,
			}),
			sectorHalf("Left", fraction),
			sectorHalf("Right", fraction),
			create("TextLabel")({
				Name = "Seconds",
				ZIndex = 4,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_HINT,
				TextColor3 = NEON.TEXT,
				Text = function()
					return if spec.seconds then tostring(math.ceil(spec.seconds())) else ""
				end,
				Visible = function()
					return fraction() > 0
				end,
				Layout.textStroke(),
			}),
		}),
	}) :: ImageButton
end

-- The touch layout: every button at its own spot under the right thumb, bound to its action.
local function corner(props: Props): Frame
	local buttons: { Instance } = {}
	for order, spec in props.buttons do
		table.insert(buttons, FlightButton(spec, order, props.onButton))
	end
	return create("Frame")({
		Name = "FlightButtons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(AREA.X, AREA.Y),
		BackgroundTransparency = 1,
		Visible = props.visible,
		Layout.screenScale(),
		buttons,
	}) :: Frame
end

-- The keyboard and gamepad layout: the same buttons in a row with their keys, a picture of the
-- controls (the keys drive the actions; the icons are not bound). Sits in a list; scaled by it.
local function row(props: { visible: () -> boolean, buttons: { ButtonSpec }, layoutOrder: number }): Frame
	local buttons: { Instance } = {}
	for order, spec in props.buttons do
		table.insert(buttons, FlightButton(spec, order, nil))
	end
	return create("Frame")({
		Name = "ActionRow",
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.visible,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the key caps that stick out of the last button and below the row.
		Layout.padding(KEY_OUT, KEY_OUT),
		buttons,
	}) :: Frame
end

return table.freeze({
	corner = corner,
	row = row,
})
