--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The tutorial's line (decision 065): what to do now, on glass in the HUD's bottom stack, above
-- the oxygen bar (docs/design/screens/hud.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local PADDING_X = 14
local PADDING_Y = 7
-- The text wraps past this width, points.
local MAX_TEXT_WIDTH = 392

export type Props = {
	-- The line to show; empty hides the panel.
	text: () -> string,
	layoutOrder: number,
}

-- The glass and its outline are on the frame, the text's own outline on the label: one object
-- takes one stroke.
local function TutorialPanel(props: Props): Frame
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
		create("TextLabel")({
			Name = "Line",
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
	}) :: Frame
end

return TutorialPanel
