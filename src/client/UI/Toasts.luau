--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Short messages stacked at the top of the screen (docs/design/screens/toasts-and-signs.md): a
-- pill of dark glass outlined in the toast's colour, with a round badge in front that says
-- what kind of news it is (good, refused, an egg, an alien, speed, coins, a gift). The text is
-- white; amounts carry their marks (UI/IconText).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AlienPicture = require(script.Parent.AlienPicture)
local IconText = require(script.Parent.IconText)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local indexes = Vide.indexes

local NEON = Theme.NEON
local TOP_OFFSET = 72
local GAP = 6
local PADDING_LEFT = 5
local PADDING_RIGHT = 14
local PADDING_Y = 4
local BADGE_SIZE = 26
local BADGE_GAP = 8
-- An alien's picture in the badge, a share of it: a little past the circle, so it reads at 26 points.
local ALIEN_SHARE = 1.25
-- The text wraps past this width, points.
local MAX_TEXT_WIDTH = 380
-- Denser than the HUD's glass: a toast must read over anything.
local GLASS_TRANSPARENCY = 0.25

export type Kind = "Good" | "Bad" | "Egg" | "Alien" | "Speed" | "Coins" | "Gift" | "Jetpack"

export type Toast = {
	id: number,
	text: string,
	kind: Kind,
	-- News about one alien (a hatch, a crossbreed): its picture is the badge, on its tier's colour
	-- (docs/design/screens/alien-icons.md).
	alienId: string?,
}

-- Each kind's colour and badge: an icon, or a glyph for the plain good and bad.
local KINDS: { [Kind]: { color: Color3, icon: Icons.Name?, glyph: string? } } = {
	Good = { color = NEON.ACTION.Main, glyph = "✓" },
	Bad = { color = NEON.DANGER, glyph = "×" },
	Egg = { color = NEON.EGG, icon = "Egg" },
	Alien = { color = NEON.TILE.Bay, icon = "Bay" },
	Speed = { color = NEON.SPEED, icon = "Bolt" },
	Coins = { color = NEON.COINS, icon = "Coin" },
	Gift = { color = NEON.TILE.Gift, icon = "Gift" },
	-- Flight hints (the double jump, decision 096): the flight buttons' cyan.
	Jetpack = { color = NEON.FLIGHT.Vertical, icon = "Jetpack" },
}

export type Props = {
	toasts: () -> { Toast },
}

local function Badge(toast: () -> Toast): Frame
	local function look()
		return KINDS[toast().kind]
	end
	-- The alien's icon, when the toast is about one whose guardian has a sheet.
	local function alienIcon(): AlienIcons.Icon?
		local alienId = toast().alienId
		return if alienId then AlienIcons.iconOf(alienId) else nil
	end
	local function color(): Color3
		local alien = AlienConfig.ALIENS[toast().alienId or ""]
		return if alien and alienIcon() then AlienLooks.TIERS[alien.tier].color else look().color
	end
	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(NEON.ACTION.Main, corner, true)
	local fill = glass[1] :: Frame
	local line = glass[2] :: UIStroke
	Vide.effect(function()
		local current = color()
		fill.BackgroundColor3 = current
		line.Color = Layout.lineColor(current)
	end)
	return create("Frame")({
		Name = "Badge",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
		BackgroundTransparency = 1,
		create("UICorner")({ CornerRadius = corner }),
		glass,
		create("ImageLabel")({
			Name = "Icon",
			ZIndex = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.68, 0.68),
			BackgroundTransparency = 1,
			Image = function()
				local icon = look().icon
				return if icon then Icons.ICONS[icon] else ""
			end,
			ImageColor3 = function()
				return Layout.iconColor(look().color)
			end,
			Visible = function()
				return look().icon ~= nil and alienIcon() == nil
			end,
		}),
		create("Frame")({
			Name = "Alien",
			ZIndex = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ALIEN_SHARE, ALIEN_SHARE),
			BackgroundTransparency = 1,
			Visible = function()
				return alienIcon() ~= nil
			end,
			AlienPicture({ icon = alienIcon, color = color }),
		}),
		create("TextLabel")({
			Name = "Glyph",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_RESOURCE,
			TextColor3 = NEON.TEXT,
			Text = function()
				return look().glyph or ""
			end,
			Visible = function()
				return look().glyph ~= nil
			end,
			Layout.textStroke(),
		}),
	}) :: Frame
end

local function ToastView(toast: () -> Toast, index: number): Frame
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = NEON.LINE_THICKNESS
	Vide.effect(function()
		outline.Color = KINDS[toast().kind].color
	end)
	local padding = Layout.padding(0, PADDING_Y)
	padding.PaddingLeft = UDim.new(0, PADDING_LEFT)
	padding.PaddingRight = UDim.new(0, PADDING_RIGHT)
	return create("Frame")({
		Name = "Toast",
		LayoutOrder = index,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = NEON.GLASS,
		BackgroundTransparency = GLASS_TRANSPARENCY,
		create("UICorner")({ CornerRadius = UDim.new(0, (BADGE_SIZE + PADDING_Y * 2) / 2) }),
		outline,
		padding,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, BADGE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Badge(toast),
		IconText({
			name = "Text",
			layoutOrder = 2,
			text = function()
				return toast().text
			end,
			textSize = NEON.TEXT_HINT,
			color = NEON.TEXT,
			outline = "Neon",
			wrapWidth = MAX_TEXT_WIDTH,
		}),
	}) :: Frame
end

local function Toasts(props: Props): Frame
	return create("Frame")({
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		-- Points of the reference screen, like the HUD.
		Layout.screenScale(),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		indexes(props.toasts, ToastView),
	}) :: Frame
end

return Toasts
