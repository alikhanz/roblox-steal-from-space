--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen while a guardian's hit stuns the player: a red wash and a shout.
--
-- The wash is a ScreenGui of its own: a ScreenGui with the default insets clips everything in it
-- to its safe area, so a wash inside the HUD left the notch, the rounded corners and Roblox's top
-- bar uncoloured on a phone however far it reached past the edges (Prod v1.0.5). This one has no
-- insets and no clipping, and lies under the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local WASH_TRANSPARENCY = 0.7
local SHOUT_TEXT_SIZE = 44
-- The shout's height on the screen, a share of it.
local SHOUT_HEIGHT = 0.4
-- Under the HUD (its ScreenGui keeps the default order 0): the buttons stay readable over the wash.
local DISPLAY_ORDER = -1

export type Props = {
	visible: () -> boolean,
	-- Static, or a source when the words depend on who hit.
	text: string | () -> string,
}

local function HitFlash(props: Props): ScreenGui
	return create("ScreenGui")({
		Name = "HitFlash",
		ResetOnSpawn = false,
		DisplayOrder = DISPLAY_ORDER,
		ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false,
		Enabled = props.visible,

		create("Frame")({
			Name = "Wash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.DANGER,
			BackgroundTransparency = WASH_TRANSPARENCY,
			BorderSizePixel = 0,

			create("TextLabel")({
				Name = "Shout",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, SHOUT_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = SHOUT_TEXT_SIZE,
				TextColor3 = Theme.TEXT,
				TextStrokeTransparency = 0.2,
				Text = props.text,
			}),
		}),
	}) :: ScreenGui
end

return HitFlash
