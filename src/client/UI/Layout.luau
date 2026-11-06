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

-- Scales a ScreenGui's contents from the reference phone screen to the current one: by screen
-- height, never below 1 and never above NEON.MAX_SCALE (docs/design/DESIGN.md, "Масштаб").
-- Call inside a Vide scope: it stops following the camera when the scope ends.
function Layout.screenScale(): UIScale
	local instance = Instance.new("UIScale")
	local function update()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else Theme.NEON.REFERENCE_HEIGHT
		instance.Scale = math.clamp(height / Theme.NEON.REFERENCE_HEIGHT, 1, Theme.NEON.MAX_SCALE)
	end
	update()
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		cameraConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) else nil
		update()
	end
	watchCamera()
	local workspaceConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	Vide.cleanup(function()
		workspaceConnection:Disconnect()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
	end)
	return instance
end

-- The dark outline under text on glass, so it reads over any scene.
function Layout.textStroke(): UIStroke
	local instance = Instance.new("UIStroke")
	instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	instance.Color = Color3.new(0, 0, 0)
	instance.Transparency = Theme.NEON.TEXT_STROKE_TRANSPARENCY
	instance.Thickness = 1
	return instance
end

-- The outline colour of a coloured glass element: its colour, mixed towards the glass.
function Layout.lineColor(color: Color3): Color3
	return color:Lerp(Theme.NEON.GLASS, Theme.NEON.LINE_DARKEN)
end

-- An icon's colour on a coloured element: its colour, lifted towards white.
function Layout.iconColor(color: Color3): Color3
	return color:Lerp(Color3.new(1, 1, 1), Theme.NEON.ICON_LIGHTEN)
end

-- Coloured glass for an element whose BackgroundColor3 is `color` and BackgroundTransparency
-- is 0: a fill fading downwards and an outline (DESIGN.md, "Как цвет ложится на кнопку").
-- `dense` is the thicker fill of action buttons. Returns the instances to put among children.
function Layout.glass(color: Color3, dense: boolean?): { Instance }
	local top = if dense then Theme.NEON.DENSE_FILL_TOP else Theme.NEON.FILL_TOP
	local bottom = if dense then Theme.NEON.DENSE_FILL_BOTTOM else Theme.NEON.FILL_BOTTOM
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new(top, bottom)
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = Layout.lineColor(color)
	outline.Thickness = Theme.NEON.LINE_THICKNESS
	return { gradient, outline }
end

return table.freeze(Layout)
