--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The tutorial's line (decision 065, docs/design/screens/tutorial-arrows.md): what to do now,
-- on glass in the HUD's bottom stack, above the oxygen bar (docs/design/screens/hud.md). On the
-- left, a dot per step (passed ones green, the current one lit in the guide's colour) and the
-- step's icon; the farewell line after the last step has neither. The hints after the tutorial
-- (decision 106) show here too: an icon without dots, and maybe a button that does it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local PADDING_X = 14
local PADDING_Y = 7
local GAP = 8
-- The text wraps past this width, points.
local MAX_TEXT_WIDTH = 392
local DOT_SIZE = 8
local CURRENT_DOT_SIZE = 11
local DOT_GAP = 4
local ICON_SIZE = 20
local DIVIDER_HEIGHT = 16
-- The guide's colour: the path, the pin and the current dot.
local GUIDE = NEON.FLIGHT.Vertical
local DONE_COLOR = Color3.fromHex("#5BDB6E")
local AHEAD_TRANSPARENCY = 0.82

-- A button after the line: its word and what it does (it opens a window: the "move" blue).
export type Action = {
	text: string,
	onPress: () -> (),
}

export type Props = {
	-- The line to show; empty hides the panel.
	text: () -> string,
	-- The current step, 1..`steps`; nil for none (the farewell line).
	step: () -> number?,
	steps: number,
	-- The current step's (or hint's) icon.
	icon: () -> Icons.Name?,
	-- A button after the line; nil: none.
	action: () -> Action?,
	layoutOrder: number,
}

local function Dot(index: number, step: () -> number?): Frame
	local function state(): "Done" | "Now" | "Ahead"
		local current = step() or 0
		return if index < current then "Done" elseif index == current then "Now" else "Ahead"
	end
	local glow = Instance.new("UIStroke")
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Color = GUIDE
	glow.Thickness = 2
	glow.Transparency = 0.5
	Vide.effect(function()
		glow.Enabled = state() == "Now"
	end)
	return create("Frame")({
		Name = `Dot{index}`,
		LayoutOrder = index,
		Size = function()
			local size = if state() == "Now" then CURRENT_DOT_SIZE else DOT_SIZE
			return UDim2.fromOffset(size, size)
		end,
		BackgroundColor3 = function()
			local current = state()
			return if current == "Done" then DONE_COLOR elseif current == "Now" then GUIDE else Color3.new(1, 1, 1)
		end,
		BackgroundTransparency = function()
			return if state() == "Ahead" then AHEAD_TRANSPARENCY else 0
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		glow,
	}) :: Frame
end

-- The glass and its outline are on the frame, the text's own outline on the label: one object
-- takes one stroke.
local function TutorialPanel(props: Props): Frame
	local function hasStep(): boolean
		return props.step() ~= nil
	end
	local dots = {}
	for index = 1, props.steps do
		table.insert(dots, Dot(index, props.step))
	end
	return create("Frame")({
		Name = "TutorialPanel",
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = NEON.GLASS,
		BackgroundTransparency = NEON.GLASS_TRANSPARENCY,
		Visible = function()
			return props.text() ~= ""
		end,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		Layout.panelLine(),
		Layout.padding(PADDING_X, PADDING_Y),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("Frame")({
			Name = "Steps",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = hasStep,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, DOT_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			dots,
		}),
		create("Frame")({
			Name = "Divider",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(1, DIVIDER_HEIGHT),
			BackgroundColor3 = NEON.LINE,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			Visible = hasStep,
		}),
		create("ImageLabel")({
			Name = "Icon",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			BackgroundTransparency = 1,
			Image = function()
				local icon = props.icon()
				return if icon then Icons.ICONS[icon] else ""
			end,
			ImageColor3 = Layout.iconColor(GUIDE),
			Visible = function()
				return props.icon() ~= nil
			end,
		}),
		create("TextLabel")({
			Name = "Line",
			LayoutOrder = 4,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_HINT,
			TextColor3 = NEON.TEXT,
			TextWrapped = true,
			Text = props.text,
			Layout.textStroke(),
			Layout.maxSize(MAX_TEXT_WIDTH, math.huge),
		}),
		ActionButton({
			name = "Action",
			text = function()
				local action = props.action()
				return if action then action.text else ""
			end,
			color = NEON.ACTION.Move,
			size = "Small",
			layoutOrder = 5,
			visible = function()
				return props.action() ~= nil
			end,
			onClick = function()
				local action = props.action()
				if action then
					action.onPress()
				end
			end,
		}),
	}) :: Frame
end

return TutorialPanel
