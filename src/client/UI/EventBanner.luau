--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Server events on the screen: a line per event, side by side at the top (in Roblox's button
-- row), each with its countdown, and a big announcement across the middle when one is about to
-- start or starts. Texts come in resolved.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local NEON = Theme.NEON
local TOP_OFFSET = 8
local LINE_HEIGHT = 30
local LINE_TEXT_SIZE = 16
local BADGE_SIZE = 22
-- A line that is on: its colour fills it from this transparency at the top to that at the
-- bottom; one coming soon is glass with an outline of its colour.
local ON_FILL_TOP = 0.45
local ON_FILL_BOTTOM = 0.75
local SOON_LINE_DARKEN = 0.3
-- The words on a line coming soon: the event's colour, lifted towards white.
local TIME_LIGHTEN = 0.55
local ANNOUNCE_BADGE_SIZE = 64
local ANNOUNCE_GLOW_TRANSPARENCY = 0.35
-- Lines stand side by side, so every event stays in the button row.
local ROW_GAP = 8
-- Room between the lines and Roblox's buttons or the screen's edge.
local ROW_EDGE = 8
local ANNOUNCE_TEXT_SIZE = 40
local ANNOUNCE_WIDTH = 0.9

export type Line = {
	-- "Solar storm in 4:35", "Meteor shower! 1:20 left".
	text: string,
	color: Color3,
	-- The event's icon (UI/Icons).
	icon: string,
	-- The event is on (filled and glowing), not just coming.
	active: boolean,
}

export type Announcement = {
	text: string,
	color: Color3,
	icon: string,
}

export type Props = {
	lines: () -> { Line },
	-- Nil: nothing announced right now.
	announcement: () -> Announcement?,
}

local function EventBanner(props: Props): ScreenGui
	-- The event's round badge: its icon on glass of its colour.
	local function badge(color: () -> Color3, icon: () -> string, size: number, order: number): Frame
		local corner = UDim.new(0.5, 0)
		local glass = Layout.glass(NEON.TILE.Bay, corner, true)
		local fill = glass[1] :: Frame
		local line = glass[2] :: UIStroke
		Vide.effect(function()
			fill.BackgroundColor3 = color()
			line.Color = color()
		end)
		return create("Frame")({
			Name = "Badge",
			LayoutOrder = order,
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			create("UICorner")({ CornerRadius = corner }),
			glass,
			create("ImageLabel")({
				Name = "Icon",
				ZIndex = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.7),
				BackgroundTransparency = 1,
				Image = function()
					return (Icons.ICONS :: any)[icon()] or ""
				end,
				ImageColor3 = function()
					return Layout.iconColor(color())
				end,
			}),
		}) :: Frame
	end

	local function line(entry: () -> Line, order: number): Frame
		local function color(): Color3
			return entry().color
		end
		local function active(): boolean
			return entry().active
		end
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Thickness = NEON.LINE_THICKNESS
		local fill = Instance.new("UIGradient")
		fill.Rotation = 90
		Vide.effect(function()
			local on = active()
			outline.Color = if on then color() else color():Lerp(NEON.GLASS, SOON_LINE_DARKEN)
			fill.Transparency = if on
				then NumberSequence.new(ON_FILL_TOP, ON_FILL_BOTTOM)
				else NumberSequence.new(NEON.GLASS_TRANSPARENCY)
		end)
		local padding = Layout.padding(0, 0)
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 12)
		return create("Frame")({
			Name = "Line",
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, LINE_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = function()
				return if active() then color() else NEON.GLASS
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			fill,
			outline,
			padding,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			badge(color, function()
				return entry().icon
			end, BADGE_SIZE, 1),
			create("TextLabel")({
				Name = "Text",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = LINE_TEXT_SIZE,
				-- Coming soon: the event's colour, lifted towards white; on: white over its fill.
				TextColor3 = function()
					return if active() then NEON.TEXT else color():Lerp(Color3.new(1, 1, 1), TIME_LIGHTEN)
				end,
				Text = function()
					return entry().text
				end,
				Layout.textStroke(),
			}),
		}) :: Frame
	end

	-- The big announcement: the event's badge in a soft light, and the words in its colour with
	-- a glowing outline of it. It takes no touches: the game goes on under it.
	local function announcementView(): Frame
		local function color(): Color3
			local current = props.announcement()
			return if current then current.color else NEON.TEXT
		end
		local glow = Instance.new("UIStroke")
		glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		glow.Thickness = 2.5
		glow.Transparency = 0.35
		Vide.effect(function()
			glow.Color = color()
		end)
		return create("Frame")({
			Name = "Announcement",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(ANNOUNCE_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = function()
				return props.announcement() ~= nil
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("Frame")({
				Name = "Mark",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(ANNOUNCE_BADGE_SIZE, ANNOUNCE_BADGE_SIZE),
				BackgroundTransparency = 1,
				create("ImageLabel")({
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.9, 1.9),
					BackgroundTransparency = 1,
					Image = Icons.GLOW,
					ImageColor3 = color,
					ImageTransparency = ANNOUNCE_GLOW_TRANSPARENCY,
				}),
				badge(color, function()
					local current = props.announcement()
					return if current then current.icon else ""
				end, ANNOUNCE_BADGE_SIZE, 1),
			}),
			create("TextLabel")({
				Name = "Text",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = ANNOUNCE_TEXT_SIZE,
				TextWrapped = true,
				TextColor3 = function()
					return color():Lerp(Color3.new(1, 1, 1), 0.25)
				end,
				Text = function()
					local current = props.announcement()
					return if current then current.text else ""
				end,
				glow,
			}),
		}) :: Frame
	end

	-- The lines sit in the row of Roblox's own buttons, in its free part (between Roblox's
	-- buttons, as TopbarInset tells): that row is free on every device, while just under it the
	-- HUD's resources (with the newbie shield) reach the middle of a phone, and windows start
	-- (docs/design/screens/hud.md). Lines too wide for it shrink together.
	local area = Vide.source(UDim2.fromOffset(ROW_EDGE, TOP_OFFSET + LINE_HEIGHT / 2))
	local areaWidth = Vide.source(UDim2.new(1, -2 * ROW_EDGE, 0, LINE_HEIGHT))
	local function readTopbar()
		local inset = GuiService.TopbarInset
		if inset.Height > 0 and inset.Width > 0 then
			area(UDim2.fromOffset(inset.Min.X + ROW_EDGE, (inset.Min.Y + inset.Max.Y) / 2))
			areaWidth(UDim2.fromOffset(math.max(0, inset.Width - 2 * ROW_EDGE), LINE_HEIGHT))
		else
			area(UDim2.fromOffset(ROW_EDGE, TOP_OFFSET + LINE_HEIGHT / 2))
			areaWidth(UDim2.new(1, -2 * ROW_EDGE, 0, LINE_HEIGHT))
		end
	end
	readTopbar()
	local topbarConnection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(readTopbar)

	local slot = create("Frame")({
		Name = "Lines",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = area,
		Size = areaWidth,
		BackgroundTransparency = 1,
	}) :: Frame
	local fit = Instance.new("UIScale")
	local row = create("Frame")({
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, LINE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		fit,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		indexes(props.lines, line),
	}) :: Frame
	row.Parent = slot
	-- The row's own width is its scaled width over the scale; it shrinks to the slot, never grows.
	local function fitRow()
		local natural = row.AbsoluteSize.X / fit.Scale
		local room = slot.AbsoluteSize.X
		fit.Scale = if natural > room and natural > 0 then room / natural else 1
	end
	local rowConnection = row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRow)
	local slotConnection = slot:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRow)
	Vide.cleanup(function()
		topbarConnection:Disconnect()
		rowConnection:Disconnect()
		slotConnection:Disconnect()
	end)

	return create("ScreenGui")({
		Name = "EventBanner",
		ResetOnSpawn = false,
		DisplayOrder = 15,
		-- Positions count from the very top of the screen, Roblox's button row included.
		IgnoreGuiInset = true,

		slot,

		announcementView(),
	}) :: ScreenGui
end

return EventBanner
