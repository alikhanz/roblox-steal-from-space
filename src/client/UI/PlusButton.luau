--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A small round "+" beside a resource plaque (docs/design/screens/hud-phone.md): on a touch
-- screen the way to more ⚡ sits on the ⚡ plaque itself, as games of the genre do, instead of a
-- word button under the goal. In its row it takes only the small circle's room; the finger's
-- target is the style's minimum around it and hangs over the neighbours, so the row stays
-- compact and the button is still easy to hit. Presses like every button (UI/Press).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Press = require(script.Parent.Press)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- What is seen, and the press target around it (DESIGN.md: never under 44).
local FACE_SIZE = 26
local TARGET_SIZE = 44
local GLYPH = "+"

export type Props = {
	name: string,
	-- What the press does (NEON.ACTION.*).
	color: Color3,
	onClick: () -> (),
	layoutOrder: number,
	visible: () -> boolean,
}

local function PlusButton(props: Props): Frame
	local press = Press.new({ shrinks = true })
	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(props.color, corner, true)
	local fill = glass[1] :: Frame
	local scale = Instance.new("UIScale")
	Vide.effect(function()
		scale.Scale = press.scale()
		fill.BackgroundColor3 = props.color:Lerp(Color3.new(1, 1, 1), press.light())
	end)
	return create("Frame")({
		Name = props.name,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(FACE_SIZE, FACE_SIZE),
		BackgroundTransparency = 1,
		Visible = props.visible,
		create("TextButton")({
			Name = "Target",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(TARGET_SIZE, TARGET_SIZE),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Activated = function()
				props.onClick()
			end,
			press.action,
			create("Frame")({
				Name = "Face",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(FACE_SIZE, FACE_SIZE),
				BackgroundTransparency = 1,
				scale,
				create("UICorner")({ CornerRadius = corner }),
				glass,
				create("TextLabel")({
					Name = "Glyph",
					ZIndex = 1,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_RESOURCE,
					TextColor3 = NEON.TEXT,
					Text = GLYPH,
					Layout.textStroke(),
				}),
			}),
		}),
	}) :: Frame
end

return PlusButton
