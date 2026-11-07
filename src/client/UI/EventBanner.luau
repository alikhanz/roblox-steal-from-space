--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Server events on the screen: a line per event, side by side at the top (in Roblox's button
-- row), each with its countdown, and a big announcement across the middle when one is about to
-- start or starts. Texts come in resolved.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local TOP_OFFSET = 8
local LINE_HEIGHT = 30
local LINE_TEXT_SIZE = 18
local ANNOUNCE_TEXT_SIZE = 40
local ANNOUNCE_WIDTH = 0.9

export type Line = {
	text: string,
	color: Color3,
}

export type Announcement = {
	text: string,
	color: Color3,
}

export type Props = {
	lines: () -> { Line },
	-- Nil: nothing announced right now.
	announcement: () -> Announcement?,
}

local function EventBanner(props: Props): ScreenGui
	local function line(entry: () -> Line, order: number): TextLabel
		return create("TextLabel")({
			Name = "Line",
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, LINE_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.PANEL,
			BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
			FontFace = Theme.FONT,
			TextSize = LINE_TEXT_SIZE,
			TextColor3 = function()
				return entry().color
			end,
			Text = function()
				return entry().text
			end,
			create("UICorner")({ CornerRadius = Theme.CORNER }),
			Layout.padding(12),
		}) :: TextLabel
	end

	-- The lines sit in the row of Roblox's own buttons, centred on it: that row is free in the
	-- middle on every device, while just under it the HUD's resources (with the newbie shield)
	-- reach the middle of a phone, and windows start (docs/design/screens/hud.md).
	local topbarMiddle = Vide.source(TOP_OFFSET + LINE_HEIGHT / 2)
	local function readTopbar()
		local inset = GuiService.TopbarInset
		topbarMiddle(if inset.Height > 0 then (inset.Min.Y + inset.Max.Y) / 2 else TOP_OFFSET + LINE_HEIGHT / 2)
	end
	readTopbar()
	local topbarConnection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(readTopbar)
	Vide.cleanup(function()
		topbarConnection:Disconnect()
	end)

	return create("ScreenGui")({
		Name = "EventBanner",
		ResetOnSpawn = false,
		DisplayOrder = 15,
		-- Positions count from the very top of the screen, Roblox's button row included.
		IgnoreGuiInset = true,

		create("Frame")({
			Name = "Lines",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = function()
				return UDim2.new(0.5, 0, 0, topbarMiddle() - LINE_HEIGHT / 2)
			end,
			Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
			BackgroundTransparency = 1,
			-- Side by side, so a second event stays in the button row too.
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			indexes(props.lines, line),
		}),

		create("TextLabel")({
			Name = "Announcement",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(ANNOUNCE_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = ANNOUNCE_TEXT_SIZE,
			TextWrapped = true,
			TextStrokeTransparency = 0.2,
			Visible = function()
				return props.announcement() ~= nil
			end,
			TextColor3 = function()
				local current = props.announcement()
				return if current then current.color else Theme.TEXT
			end,
			Text = function()
				local current = props.announcement()
				return if current then current.text else ""
			end,
		}),
	}) :: ScreenGui
end

return EventBanner
