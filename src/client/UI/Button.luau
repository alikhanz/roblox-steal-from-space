--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A text button of the HUD: rounded, dims when disabled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local HEIGHT = 40
local PADDING = 14
local DISABLED_TRANSPARENCY = 0.6

export type Props = {
	name: string,
	text: string | () -> string,
	onClick: () -> (),
	enabled: (() -> boolean)?,
	color: Color3?,
	layoutOrder: number?,
}

local function Button(props: Props): TextButton
	local function isEnabled(): boolean
		return if props.enabled then props.enabled() else true
	end
	return create("TextButton")({
		Name = props.name,
		LayoutOrder = props.layoutOrder or 0,
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = props.color or Theme.ACCENT,
		BackgroundTransparency = function()
			return if isEnabled() then 0 else DISABLED_TRANSPARENCY
		end,
		FontFace = Theme.FONT,
		TextSize = Theme.TEXT_SIZE,
		TextColor3 = Theme.TEXT,
		TextTransparency = function()
			return if isEnabled() then 0 else DISABLED_TRANSPARENCY
		end,
		Text = props.text,
		AutoButtonColor = isEnabled,
		Activated = function()
			if isEnabled() then
				props.onClick()
			end
		end,
		create("UICorner")({ CornerRadius = Theme.CORNER }),
		Layout.padding(PADDING),
	}) :: TextButton
end

return Button
