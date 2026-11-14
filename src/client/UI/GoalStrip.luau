--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The speed goal folded under the ⚡ plaque on a touch screen (docs/design/screens/hud-phone.md):
-- one small line, "→ Ice Worm · ⚡34.7K", over a thin bar of the way there. It takes no room
-- under the plaques, so the menu tiles stand above the movement stick's area. Nothing on it is
-- pressed: the way to more ⚡ is the "+" on the plaque.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoalBar = require(script.Parent.GoalBar)
local IconText = require(script.Parent.IconText)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- Wide enough for the longest guardian's name and a target ("→ Кислотный слизень · ⚡412K").
local WIDTH = 180
local BAR_HEIGHT = 6
local LINE_GAP = 2

export type Props = {
	-- "→ Ice Worm · ⚡34.7K".
	text: () -> string,
	-- 0..1 of the way to the goal.
	progress: () -> number,
	layoutOrder: number,
	visible: () -> boolean,
}

local function GoalStrip(props: Props): Frame
	return create("Frame")({
		Name = "GoalStrip",
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = props.visible,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, LINE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		IconText({
			name = "Text",
			layoutOrder = 1,
			text = props.text,
			textSize = NEON.TEXT_SMALL,
			color = NEON.MUTED,
			outline = "Neon",
		}),
		GoalBar({ progress = props.progress, height = BAR_HEIGHT, layoutOrder = 2 }),
	}) :: Frame
end

return GoalStrip
