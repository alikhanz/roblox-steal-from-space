--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Server events on the screen: a line per event at the top with its countdown, and a big
-- announcement across the middle when one is about to start or starts. Texts come in resolved.

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

	return create("ScreenGui")({
		Name = "EventBanner",
		ResetOnSpawn = false,
		DisplayOrder = 15,

		create("Frame")({
			Name = "Lines",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
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
