--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The bar of the way to the speed goal: a faint track and a fill running from deep to light
-- gold. The goal card and the phone's goal strip both draw it (docs/design/screens/hud.md,
-- hud-phone.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local FILL_FROM = Color3.fromHex("#E3901F")
local FILL_TO = Color3.fromHex("#F0D06A")
local TRACK_TRANSPARENCY = 0.9

export type Props = {
	-- 0..1 of the way to the goal.
	progress: () -> number,
	height: number,
	layoutOrder: number,
}

local function GoalBar(props: Props): Frame
	return create("Frame")({
		Name = "Bar",
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, props.height),
		BackgroundColor3 = NEON.TEXT,
		BackgroundTransparency = TRACK_TRANSPARENCY,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		Layout.panelLine(),
		create("Frame")({
			Name = "Fill",
			Size = function()
				return UDim2.fromScale(math.clamp(props.progress(), 0, 1), 1)
			end,
			BackgroundColor3 = Color3.new(1, 1, 1),
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			create("UIGradient")({ Color = ColorSequence.new(FILL_FROM, FILL_TO) }),
		}),
	}) :: Frame
end

return GoalBar
