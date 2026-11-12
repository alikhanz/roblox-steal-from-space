--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The flight buttons (docs/design/screens/hud.md): round buttons of coloured glass with an
-- icon. On a touch screen they sit under the right thumb (`corner`) and each drives an input
-- action through a UIButton binding (TouchBindings), the same action the keyboard drives; with a
-- keyboard or a gamepad they make a row with their keys (`row`). A cooling button is
-- covered by a dark sector with the seconds left; a disabled one turns grey; a switched-on one
-- (slow mode) is lit: solid colour, dark icon.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Press = require(script.Parent.Press)
local ProgressRing = require(script.Parent.ProgressRing)
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
local COOLDOWN_TRANSPARENCY = 0.35
-- A disabled button: how see-through its glass gets.
local DISABLED_TRANSPARENCY = 0.6
-- A switched-on button (slow mode) is lit: its glass nearly solid, the icon dark on it, a light
-- outline and a brighter glow, so "on" reads at a glance next to the see-through buttons.
local LIT_FILL_TOP = 0.05
local LIT_FILL_BOTTOM = 0.25
local LIT_GLOW_TRANSPARENCY = 0.25
-- A button with a word under its icon: the icon a little smaller and higher, the word below.
local LABELLED_ICON_SHARE = 0.45
local LABELLED_ICON_Y = 0.4
local LABEL_Y = 0.74
-- The ring of progress round a button, against the button's size.
local RING_SHARE = 1.18
-- Appearing: grows in from this scale over this long, seconds. Pulsing: breathes this much
-- bigger, one breath this long, seconds.
local APPEAR_FROM = 0.8
local APPEAR_SECONDS = 0.15
local PULSE_GROWTH = 0.06
local PULSE_SECONDS = 1.4
-- The whole group's box, points: big enough for every button's place in it (the grab button
-- stands above the others).
local AREA = Vector2.new(300, 260)
-- The PC row: space between buttons; the key cap's height and how far it sticks out.
local ROW_GAP = 12
local KEY_HEIGHT = 17
local KEY_OUT = 6

export type ButtonSpec = {
	name: string,
	-- The input action it drives (FlightInputs).
	action: string,
	icon: Icons.Name,
	-- An icon that changes (the grab button wears the icon of the egg it grabs); `icon` otherwise.
	iconOf: (() -> Icons.Name)?,
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
	-- Shown only while this says so (the grab button: only next to an egg); always otherwise. It
	-- grows in when it appears.
	visible: (() -> boolean)?,
	-- Its colour now, when it changes (the grab button: the egg's rarity); `color` otherwise.
	tint: (() -> Color3)?,
	-- A short word under the icon.
	label: string?,
	-- Gently pulses while this says so, to be noticed.
	pulse: (() -> boolean)?,
	-- A ring round the button filling clockwise, 0..1; the button gets a solid base for it.
	progress: (() -> number)?,
}

export type Props = {
	visible: () -> boolean,
	buttons: { ButtonSpec },
	-- Called once with each created button so it can be bound to its input action.
	onButton: (actionName: string, button: GuiButton) -> (),
}

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
	local function isEnabled(): boolean
		return if spec.enabled then spec.enabled() else true
	end
	-- Silent: an ability has its own sound and effect.
	local press = Press.new({ enabled = isEnabled, shrinks = true, silent = true })
	local function isActive(): boolean
		return if spec.active then spec.active() else false
	end
	local function fraction(): number
		return if spec.cooldown then spec.cooldown() else 0
	end

	local function colorNow(): Color3
		return if spec.tint then spec.tint() else spec.color
	end
	local function isShown(): boolean
		return if spec.visible then spec.visible() else true
	end
	local function progress(): number
		return if spec.progress then spec.progress() else 0
	end

	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(spec.color, corner)
	local fill = glass[1] :: Frame
	local outline = glass[2] :: UIStroke
	fill.ZIndex = 1
	local gradient = fill:FindFirstChildOfClass("UIGradient") :: UIGradient
	local pressScale = Instance.new("UIScale")
	-- Growing in on appearing and the pulse, multiplied into the press scale.
	local motion = source(1)
	local function isLit(): boolean
		return isActive() and isEnabled()
	end
	Vide.effect(function()
		local enabled = isEnabled()
		local lit = isLit()
		local color = colorNow()
		fill.BackgroundColor3 = color
		fill.BackgroundTransparency = if enabled then 0 else DISABLED_TRANSPARENCY
		outline.Color = if lit then Layout.iconColor(color) elseif enabled then Layout.lineColor(color) else NEON.MUTED
		outline.Transparency = if enabled then 0 else DISABLED_TRANSPARENCY
		gradient.Transparency = if lit
			then NumberSequence.new(LIT_FILL_TOP, LIT_FILL_BOTTOM)
			else NumberSequence.new(NEON.FILL_TOP, NEON.FILL_BOTTOM)
		pressScale.Scale = (if enabled then press.scale() else 1) * motion()
	end)
	-- Appearing (grows in) and pulsing (breathes) are driven frame by frame while they last.
	if spec.visible or spec.pulse then
		local shownAt = os.clock()
		Vide.effect(function()
			if isShown() then
				shownAt = os.clock()
			end
		end)
		Vide.effect(function()
			local pulsing = spec.pulse ~= nil and spec.pulse() and not GuiService.ReducedMotionEnabled
			if not isShown() then
				motion(1)
				return
			end
			local connection: RBXScriptConnection
			connection = RunService.Heartbeat:Connect(function()
				local age = os.clock() - shownAt
				if age >= APPEAR_SECONDS and not pulsing then
					-- Grown in and still: nothing more to drive.
					motion(1)
					connection:Disconnect()
					return
				end
				local appear = if age < APPEAR_SECONDS
					then APPEAR_FROM + (1 - APPEAR_FROM) * age / APPEAR_SECONDS
					else 1
				local beat = if pulsing
					then 1 + PULSE_GROWTH * (0.5 - 0.5 * math.cos(2 * math.pi * age / PULSE_SECONDS))
					else 1
				motion(appear * beat)
			end)
			Vide.cleanup(connection)
		end)
	end

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
		Visible = isShown,
		press.action,
		Rotation = press.tilt,
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
				ZIndex = -2,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(GLOW_SHARE, GLOW_SHARE),
				BackgroundTransparency = 1,
				Image = Icons.GLOW,
				ImageColor3 = colorNow,
				ImageTransparency = function()
					return if isLit() or (spec.pulse and spec.pulse()) then LIT_GLOW_TRANSPARENCY else GLOW_TRANSPARENCY
				end,
				Visible = isEnabled,
			}),
			-- The ring of progress: a light sector round the button, over a solid base that hides
			-- its middle under the see-through glass.
			if spec.progress
				then ProgressRing({ fraction = progress, color = NEON.TEXT, share = RING_SHARE, zIndex = -1 })
				else nil,
			if spec.progress
				then create("ImageLabel")({
					Name = "Base",
					ZIndex = 0,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = Icons.DISC,
					ImageColor3 = NEON.GLASS,
				})
				else nil,
			glass,
			create("ImageLabel")({
				Name = "Icon",
				ZIndex = 2,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if spec.label then UDim2.fromScale(0.5, LABELLED_ICON_Y) else UDim2.fromScale(0.5, 0.5),
				Size = if spec.label
					then UDim2.fromScale(LABELLED_ICON_SHARE, LABELLED_ICON_SHARE)
					else UDim2.fromScale(ICON_SHARE, ICON_SHARE),
				BackgroundTransparency = 1,
				Image = function()
					local iconOf = spec.iconOf
					return Icons.ICONS[if iconOf then iconOf() else spec.icon]
				end,
				ImageColor3 = function()
					return if isLit()
						then NEON.GLASS
						elseif isEnabled() then Layout.iconColor(colorNow())
						else NEON.MUTED
				end,
			}),
			if spec.label
				then create("TextLabel")({
					Name = "Label",
					ZIndex = 2,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, LABEL_Y),
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_SMALL,
					TextColor3 = NEON.TEXT,
					Text = spec.label,
					Layout.textStroke(),
				})
				else nil,
			-- The dark sector over a cooling button.
			ProgressRing({
				fraction = fraction,
				color = Color3.new(0, 0, 0),
				share = 1,
				zIndex = 3,
				transparency = COOLDOWN_TRANSPARENCY,
			}),
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
	-- The key cap on a round button's corner, for anything drawn like a flight button.
	KeyCap = KeyCap,
})
