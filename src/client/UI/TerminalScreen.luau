--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen of a terminal on a player's island (docs/design/screens/terminals.md): a SurfaceGui
-- on the terminal's screen part with a title in the zone's colour, a big number, a hint, and for
-- the owner a full-width button with just the price (or a line once everything is bought): the
-- title already says what it buys, and a big price reads on a phone from a few steps away. With
-- the screen comes the fan of light up to it from the terminal's lens.
--
-- The canvas is laid out at screen size and scaled up to the part (UIScale), so the neon
-- components (ActionButton, IconText) keep their own sizes and proportions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)

local ActionButton = require(script.Parent.ActionButton)
local IconText = require(script.Parent.IconText)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- The canvas in screen pixels, in the screen part's proportions (BayLooks.TERMINAL_SCREEN_SIZE,
-- 6 x 4 studs), scaled up to fill it. Only the front face has writing: from behind the screen is
-- the part's dim glass.
local CANVAS = Vector2.new(180, 120)
local PIXELS_PER_STUD = 100
-- Screens fade out beyond this distance, as the signs before them, studs.
local MAX_DISTANCE = 80
local TITLE_SIZE = 17
local VALUE_SIZE = 26
local HINT_SIZE = 13
local SCREEN_TOP = Color3.fromRGB(22, 32, 96)
local SCREEN_BOTTOM = Color3.fromRGB(10, 13, 44)
-- The screen is a hologram's glass (brief version 2): the scene shows faintly through it. Over
-- the screen part's own dim glass (BayLooks.TERMINAL_SCREEN_TRANSPARENCY).
local GLASS_TRANSPARENCY = 0.25
local DONE_COLOR = NEON.SHIELD
-- How far the title's colour goes towards white: the zone's colour, readable on the dark glass.
local TITLE_LIGHTEN = 0.45
-- A purchase's flash: how long the gold fades, seconds, and the edge's thickness, pixels.
local FLASH_SECONDS = 0.8
local FLASH_EDGE = 3

export type ButtonProps = {
	text: () -> string,
	enabled: () -> boolean,
	onClick: () -> (),
}

export type Props = {
	adornee: BasePart,
	color: Color3,
	title: string,
	value: () -> string,
	hint: () -> string,
	hintColor: Color3?,
	-- The owner's purchase; nil on someone else's island.
	button: ButtonProps?,
	-- True once there is nothing left to buy: the button gives way to `doneText`.
	done: (() -> boolean)?,
	doneText: string?,
}

-- The fan of light from the terminal's lens up to its screen (decision 086), between the
-- attachments the server put on the screen part: an effect, so each client makes its own. Nil when
-- the screen has no attachments.
local function beamFor(screen: BasePart, color: Color3): Beam?
	local from = screen:FindFirstChild(BayConfig.TERMINAL_BEAM_FROM_NAME)
	local to = screen:FindFirstChild(BayConfig.TERMINAL_BEAM_TO_NAME)
	if not (from and from:IsA("Attachment") and to and to:IsA("Attachment")) then
		return nil
	end
	local looks = BayLooks.TERMINAL_BEAM
	local beam = Instance.new("Beam")
	beam.Name = "TerminalBeam"
	beam.Attachment0 = from
	beam.Attachment1 = to
	-- Fixed in the screen's plane by the attachments' secondary axis, not turned to the camera.
	beam.FaceCamera = false
	beam.Segments = 1
	beam.Width0 = looks.width0
	beam.Width1 = looks.width1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(looks.transparency0, looks.transparency1)
	beam.Parent = screen
	return beam
end

-- Vide's create does not know UIScale.
local function scaleTo(scale: number): UIScale
	local instance = Instance.new("UIScale")
	instance.Scale = scale
	return instance
end

local function TerminalScreen(props: Props): SurfaceGui
	local button = props.button
	local done = props.done or function()
		return false
	end
	local beam = beamFor(props.adornee, props.color)
	if beam then
		Vide.cleanup(function()
			beam:Destroy()
		end)
	end
	-- A purchase went through (docs/design/screens/buttons.md): the number it raised flashes gold
	-- and fades back, and the screen's edge glows gold a moment. The number changes only when the
	-- server has it, so the flash marks a real purchase, not a press.
	local valueLabel: TextLabel? = nil
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = NEON.ACTION.Coins
	edge.Thickness = FLASH_EDGE
	edge.Transparency = 1
	local shown: string? = nil
	Vide.effect(function()
		local now = props.value()
		local before = shown
		shown = now
		local label = valueLabel
		if before == nil or before == now or not label then
			return
		end
		local fade = TweenInfo.new(FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		label.TextColor3 = NEON.ACTION.Coins
		TweenService:Create(label, fade, { TextColor3 = NEON.TEXT }):Play()
		edge.Transparency = 0
		TweenService:Create(edge, fade, { Transparency = 1 }):Play()
	end)
	return create("SurfaceGui")({
		Name = "TerminalScreen",
		Adornee = props.adornee,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		-- Needed for the button to take clicks and touches.
		Active = button ~= nil,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = GLASS_TRANSPARENCY,
			BorderSizePixel = 0,
			scaleTo(props.adornee.Size.X * PIXELS_PER_STUD / CANVAS.X),
			edge,
			create("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(SCREEN_TOP, SCREEN_BOTTOM),
			}),
			Layout.padding(NEON.GAP, NEON.GAP),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),

			create("TextLabel")({
				Name = "Title",
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = TITLE_SIZE,
				TextColor3 = props.color:Lerp(Color3.new(1, 1, 1), TITLE_LIGHTEN),
				Text = props.title,
				Layout.textStroke(),
			}),
			create("TextLabel")({
				Name = "Value",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = VALUE_SIZE,
				TextColor3 = NEON.TEXT,
				Text = props.value,
				Layout.textStroke(),
				Vide.action(function(instance)
					valueLabel = instance :: TextLabel
				end),
			}),
			-- Amounts of ⚡ show their icon (Locale/Marks).
			IconText({
				name = "Hint",
				layoutOrder = 3,
				text = props.hint,
				textSize = HINT_SIZE,
				color = props.hintColor or NEON.MUTED,
				font = NEON.FONT,
				outline = "Neon",
				wrapWidth = CANVAS.X - NEON.GAP * 2,
			}),
			if button
				then ActionButton({
					name = "Buy",
					layoutOrder = 4,
					text = button.text,
					size = "Huge",
					width = 1,
					color = NEON.ACTION.Coins,
					enabled = button.enabled,
					onClick = button.onClick,
					visible = function()
						return not done()
					end,
				})
				else nil,
			if button
				then create("TextLabel")({
					Name = "Done",
					LayoutOrder = 5,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = HINT_SIZE,
					TextColor3 = DONE_COLOR,
					Text = props.doneText or "",
					Visible = done,
					Layout.textStroke(),
				})
				else nil,
		}),
	}) :: SurfaceGui
end

return TerminalScreen
