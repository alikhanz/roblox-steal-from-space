--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen while a guardian's hit stuns the player: a red wash and a shout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local WASH_TRANSPARENCY = 0.7
local SHOUT_TEXT_SIZE = 44
-- The HUD's ScreenGui keeps Roblox's top bar and the phone's safe area (notch, rounded corners)
-- out: the wash reaches past its edges by this much so it covers the whole screen.
local BLEED = 400

export type Props = {
	visible: () -> boolean,
	-- Static, or a source when the words depend on who hit.
	text: string | () -> string,
}

local function HitFlash(props: Props): Frame
	return create("Frame")({
		Name = "HitFlash",
		Position = UDim2.fromOffset(-BLEED, -BLEED),
		Size = UDim2.new(1, 2 * BLEED, 1, 2 * BLEED),
		BackgroundColor3 = Theme.DANGER,
		BackgroundTransparency = WASH_TRANSPARENCY,
		BorderSizePixel = 0,
		Visible = props.visible,

		create("TextLabel")({
			Name = "Shout",
			AnchorPoint = Vector2.new(0.5, 0.5),
			-- At 40% of the visible screen's height: the frame is bigger by BLEED on every side.
			Position = UDim2.new(0.5, 0, 0.4, 0.2 * BLEED),
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
