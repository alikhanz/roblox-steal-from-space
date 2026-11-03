--!strict
-- Layout helpers for instances Vide's typed `create` does not list (UIPadding, UISizeConstraint,
-- UIStroke); they are made directly and dropped into a component's children.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- An outline that follows `visible`.
function Layout.stroke(color: Color3, thickness: number, visible: () -> boolean): UIStroke
	local instance = Instance.new("UIStroke")
	instance.Thickness = thickness
	instance.Color = color
	Vide.effect(function()
		instance.Enabled = visible()
	end)
	return instance
end

return table.freeze(Layout)
