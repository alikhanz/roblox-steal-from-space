--!strict
-- Layout helpers: instances Vide's typed `create` does not list (UIPadding, UISizeConstraint,
-- UIStroke, UITextSizeConstraint), made directly and dropped into a component's children, and
-- the places of the HUD's menu buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local Layout = {}

function Layout.padding(horizontal: number, vertical: number?): UIPadding
	local instance = Instance.new("UIPadding")
	instance.PaddingLeft = UDim.new(0, horizontal)
	instance.PaddingRight = UDim.new(0, horizontal)
	instance.PaddingTop = UDim.new(0, vertical or 0)
	instance.PaddingBottom = UDim.new(0, vertical or 0)
	return instance
end

function Layout.maxSize(width: number, height: number): UISizeConstraint
	local instance = Instance.new("UISizeConstraint")
	instance.MaxSize = Vector2.new(width, height)
	return instance
end

-- The largest size a scaled text may take, following `size`.
function Layout.maxTextSize(size: () -> number): UITextSizeConstraint
	local instance = Instance.new("UITextSizeConstraint")
	Vide.effect(function()
		instance.MaxTextSize = size()
	end)
	return instance
end

-- The column of window buttons in the bottom-left corner, from the bottom up. Every button in
-- it takes its place here, so they never overlap.
export type MenuSlot = "Bay" | "Quests" | "Gift" | "Index" | "Store"
local MENU_SLOTS: { MenuSlot } = { "Bay", "Quests", "Gift", "Index", "Store" }
-- From one button's bottom edge to the next one's, pixels: a button and a gap.
local MENU_STEP = 48

-- Puts `button` at its place in the bottom-left menu column; returns it, to sit among children.
function Layout.placeInMenu(button: TextButton, slot: MenuSlot): TextButton
	local index = assert(table.find(MENU_SLOTS, slot), `no menu slot {slot}`)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, Theme.MARGIN, 1, -(Theme.MARGIN + (index - 1) * MENU_STEP))
	return button
end

-- An outline around the element that follows `visible`. The mode is set explicitly: the
-- default (Contextual) outlines the text of a text element, which for a button with no text is
-- nothing at all.
function Layout.stroke(color: Color3, thickness: number, visible: () -> boolean): UIStroke
	local instance = Instance.new("UIStroke")
	instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	instance.Thickness = thickness
	instance.Color = color
	Vide.effect(function()
		instance.Enabled = visible()
	end)
	return instance
end

return table.freeze(Layout)
