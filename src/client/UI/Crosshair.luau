--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The aim point in the middle of the screen while flying: every attack goes where the camera
-- looks. It grows into a ring with a word when an egg carrier is in the harpoon's reach.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local DOT_SIZE = 8
local RING_SIZE = 36
local RING_THICKNESS = 3
local LABEL_OFFSET = 28

export type Props = {
	visible: () -> boolean,
	-- True while a harpoon target is in reach.
	locked: () -> boolean,
	lockedText: string,
}

-- Vide's instance types do not list UIStroke, so it is made directly.
local function ring(color: Color3, thickness: number, visible: () -> boolean): UIStroke
	local instance = Instance.new("UIStroke")
	instance.Color = color
	instance.Thickness = thickness
	Vide.effect(function()
		instance.Enabled = visible()
	end)
	return instance
end

local function Crosshair(props: Props): Frame
	return create("Frame")({
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
		BackgroundTransparency = 1,
		Visible = props.visible,

		create("Frame")({
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE),
			BackgroundColor3 = function()
				return if props.locked() then Theme.DANGER else Theme.TEXT
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("Frame")({
			Name = "Ring",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			ring(Theme.DANGER, RING_THICKNESS, props.locked),
		}),
		create("TextLabel")({
			Name = "Locked",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, LABEL_OFFSET - RING_SIZE / 2),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.DANGER,
			TextStrokeTransparency = 0.4,
			Visible = props.locked,
			Text = props.lockedText,
		}),
	}) :: Frame
end

return Crosshair
