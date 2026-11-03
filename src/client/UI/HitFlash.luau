--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen while a guardian's hit stuns the player: a red wash and a shout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local WASH_TRANSPARENCY = 0.7
local SHOUT_TEXT_SIZE = 44

export type Props = {
	visible: () -> boolean,
	text: string,
}

local function HitFlash(props: Props): Frame
	return create("Frame")({
		Name = "HitFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.DANGER,
		BackgroundTransparency = WASH_TRANSPARENCY,
		BorderSizePixel = 0,
		Visible = props.visible,

		create("TextLabel")({
			Name = "Shout",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = SHOUT_TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextStrokeTransparency = 0.2,
			Text = props.text,
		}),
	}) :: Frame
end

return HitFlash
