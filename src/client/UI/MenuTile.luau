--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A menu tile of the HUD (DESIGN.md, "Плитка меню"): a square of coloured glass with the
-- window's icon, no words. A red count in the top corner when something waits inside; on a
-- keyboard, the window's key in the bottom corner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local NEON = Theme.NEON
local ICON_SIZE = 31
local PRESSED_SCALE = 0.93
local BADGE_SIZE = 20
local KEY_SIZE = 17
-- How far the badge and the key cap stick out of the tile's corners.
local CORNER_OUT = 6

export type Props = {
	name: string,
	icon: Icons.Name,
	color: Color3,
	onPress: () -> (),
	-- Something waits inside: a count, hidden at 0.
	badge: () -> number,
	-- The key that opens it, shown on a keyboard; empty: none shown.
	keyText: () -> string,
	visible: () -> boolean,
	layoutOrder: number,
}

local function MenuTile(props: Props): ImageButton
	local pressed = source(false)
	-- Vide's typed `create` does not list UIScale, so it is made directly.
	local pressScale = Instance.new("UIScale")
	Vide.effect(function()
		pressScale.Scale = if pressed() then PRESSED_SCALE else 1
	end)
	return create("ImageButton")({
		Name = props.name,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(NEON.TILE_SIZE, NEON.TILE_SIZE),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Visible = props.visible,
		Activated = function()
			props.onPress()
		end,
		Layout.followPress(pressed),

		-- What is seen shrinks on a press; the tile's place in the row stays, so the neighbours
		-- do not move.
		create("Frame")({
			Name = "Face",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("UICorner")({ CornerRadius = NEON.CORNER }),
			pressScale,
			Layout.glass(props.color, NEON.CORNER),
			create("ImageLabel")({
				Name = "Icon",
				ZIndex = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				BackgroundTransparency = 1,
				Image = Icons.ICONS[props.icon],
				ImageColor3 = Layout.iconColor(props.color),
			}),
		}),
		create("TextLabel")({
			Name = "Badge",
			ZIndex = 2,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(NEON.TILE_SIZE + CORNER_OUT, -CORNER_OUT),
			Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
			BackgroundColor3 = NEON.DANGER,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SMALL,
			TextColor3 = Color3.new(1, 1, 1),
			Text = function()
				return tostring(props.badge())
			end,
			Visible = function()
				return props.badge() > 0
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			Layout.stroke(Color3.new(1, 1, 1), 2, function()
				return true
			end),
		}),
		create("TextLabel")({
			Name = "Key",
			ZIndex = 2,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromOffset(NEON.TILE_SIZE + CORNER_OUT, NEON.TILE_SIZE + CORNER_OUT),
			Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
			BackgroundColor3 = NEON.GLASS,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SMALL,
			TextColor3 = NEON.TEXT,
			Text = props.keyText,
			Visible = function()
				return props.keyText() ~= ""
			end,
			create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			Layout.panelLine(),
		}),
	}) :: ImageButton
end

return MenuTile
