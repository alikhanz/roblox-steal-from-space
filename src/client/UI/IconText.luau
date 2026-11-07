--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A line of text with its resource marks drawn as icons (Locale/Marks): `●` as the coin and `⚡`
-- as the bolt, each in its resource's colour, sized to the text. Words and icons stand in a row
-- as wide as they are. A text without marks is a single label, which can wrap (`wrapWidth`);
-- a text with marks stays on one line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Marks = require(ReplicatedStorage.Shared.Locale.Marks)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local NEON = Theme.NEON
-- Icons are a little larger than the letters, like the icons next to numbers in the HUD.
local ICON_SHARE = 1.1
-- The gap between words and icons, against the text size: about a space.
local GAP_SHARE = 0.2
-- The outline of greybox signs over the 3D world.
local LEGACY_STROKE_TRANSPARENCY = 0.4

local ICON_COLORS: { [Marks.Icon]: Color3 } = {
	Coin = NEON.COINS,
	Bolt = NEON.SPEED,
}

-- Neon: the style's thin dark outline; Legacy: Roblox's text stroke of the greybox signs.
export type Outline = "Neon" | "Legacy"

export type Props = {
	name: string,
	text: string | () -> string,
	textSize: number,
	color: Color3 | () -> Color3,
	font: Font?,
	-- Fades the words and icons together (a disabled button, a claimed card).
	transparency: (() -> number)?,
	outline: Outline?,
	-- A text without marks wraps within this width; without it, it stays on one line.
	wrapWidth: number?,
	-- Where the row sits when its frame is wider than it.
	align: Enum.HorizontalAlignment?,
	layoutOrder: number?,
	zIndex: number?,
	visible: (() -> boolean)?,
}

local function IconText(props: Props): Frame
	local function read(): string
		local text = props.text
		return if type(text) == "function" then text() else text
	end
	local function transparency(): number
		return if props.transparency then props.transparency() else 0
	end
	local function pieces(): { Marks.Piece }
		return Marks.split(read())
	end
	local wraps = props.wrapWidth ~= nil
	local iconSize = math.round(props.textSize * ICON_SHARE)
	local zIndex = props.zIndex or 1

	local function outline(): any
		if props.outline == "Neon" then
			local stroke = Layout.textStroke()
			Vide.effect(function()
				stroke.Transparency = 1 - (1 - NEON.TEXT_STROKE_TRANSPARENCY) * (1 - transparency())
			end)
			return stroke
		end
		return nil
	end

	-- One slot per piece: words, or an icon in a box of the icon's size. The same slot can turn
	-- from one into the other when the text changes.
	local function slot(piece: () -> Marks.Piece, index: number): TextLabel
		local function icon(): Marks.Icon?
			return piece().icon
		end
		local function isIcon(): boolean
			return icon() ~= nil
		end
		return create("TextLabel")({
			Name = "Piece",
			LayoutOrder = index,
			ZIndex = zIndex,
			Size = function()
				return if isIcon() then UDim2.fromOffset(iconSize, iconSize) else UDim2.new()
			end,
			AutomaticSize = function()
				return if isIcon() then Enum.AutomaticSize.None else Enum.AutomaticSize.XY
			end,
			BackgroundTransparency = 1,
			FontFace = props.font or NEON.FONT,
			TextSize = props.textSize,
			TextColor3 = props.color,
			TextTransparency = transparency,
			TextStrokeTransparency = if props.outline == "Legacy" then LEGACY_STROKE_TRANSPARENCY else 1,
			-- Only a lone piece of words wraps: a row with icons stays on one line.
			TextWrapped = function()
				return wraps and not isIcon() and #pieces() == 1
			end,
			Text = function()
				local current = piece()
				return current.text or ""
			end,
			if props.wrapWidth then Layout.maxSize(props.wrapWidth, math.huge) else nil,
			outline(),
			create("ImageLabel")({
				Name = "Icon",
				ZIndex = zIndex,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = function()
					local current = icon()
					return if current then Icons.ICONS[current] else ""
				end,
				ImageColor3 = function()
					local current = icon()
					return if current then ICON_COLORS[current] else NEON.TEXT
				end,
				ImageTransparency = transparency,
				Visible = isIcon,
			}),
		}) :: TextLabel
	end

	return create("Frame")({
		Name = props.name,
		LayoutOrder = props.layoutOrder or 0,
		ZIndex = zIndex,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.visible or true,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = props.align or Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, math.round(props.textSize * GAP_SHARE)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		indexes(pieces, slot),
	}) :: Frame
end

return IconText
