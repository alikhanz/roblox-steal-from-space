--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The tutorial's line (decision 065): what to do now, above the oxygen bar at the bottom of the
-- screen. Greybox until the art pass (docs/plans/POLISH.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

-- Clear of the oxygen bar and its warning, pixels from the bottom edge.
local BOTTOM_OFFSET = 96
local PADDING = 14
local MAX_WIDTH = 520
local TEXT_SIZE = 22

export type Props = {
	-- The line to show; empty hides the panel.
	text: () -> string,
}

local function TutorialPanel(props: Props): TextLabel
	return create("TextLabel")({
		Name = "TutorialPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.PANEL,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
		FontFace = Theme.FONT,
		TextSize = TEXT_SIZE,
		TextColor3 = Theme.SPEED,
		TextWrapped = true,
		Visible = function()
			return props.text() ~= ""
		end,
		Text = props.text,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.maxSize(MAX_WIDTH, math.huge),
		Layout.padding(PADDING, PADDING / 2),
	}) :: TextLabel
end

return TutorialPanel
