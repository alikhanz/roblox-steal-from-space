--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The banner on a screen of the station's ring (decision 087): the kiosks' names with their icons,
-- big, running along the screen without end, so from an island or from the platform the ring
-- reads as a turning sign of what the station has. Still under reduced motion.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(script.Parent.Layout)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local BANNER = StationLooks.BANNER
-- Within an item: the icon's share of the screen's height and the gap after it, the name's share
-- of the height.
local ICON_SHARE = 0.62
local NAME_SHARE = 0.56
local ICON_GAP_SHARE = 0.1
-- Roblox draws no text bigger than this.
local MAX_TEXT_SIZE = 100

export type Item = {
	name: string,
	icon: string,
	color: Color3,
}

local RingBanner = {}

-- One kiosk: its icon and name, centred in an item at least `minWidth` pixels wide. A name too long
-- for that widens its own item (the text has a fixed size), so it never runs under the next icon
-- in any language.
local function item(spec: Item, order: number, minWidth: number, height: number): Frame
	local tint = Color3.new(1, 1, 1):Lerp(spec.color, StationLooks.KIOSK_ICON_TINT)
	local iconSize = math.round(height * ICON_SHARE)
	return create("Frame")({
		Name = "Item",
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Layout.minSize(minWidth, 0),
		-- Half a gap each side, so neighbours' names never touch.
		Layout.padding(math.round(height * BANNER.itemGapShare / 2)),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, math.round(height * ICON_GAP_SHARE)),
		}),
		create("ImageLabel")({
			LayoutOrder = 1,
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			Image = spec.icon,
			ImageColor3 = tint,
			ScaleType = Enum.ScaleType.Fit,
		}),
		create("TextLabel")({
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, NAME_SHARE),
			BackgroundTransparency = 1,
			FontFace = Theme.NEON.FONT,
			Text = spec.name,
			TextColor3 = tint,
			TextSize = math.min(MAX_TEXT_SIZE, math.round(height * NAME_SHARE)),
		}),
	}) :: Frame
end

-- The banner on the Front face of `adornee`, running `items` from right to left.
function RingBanner.create(adornee: BasePart, items: { Item }): SurfaceGui
	local count = #items
	-- The screen in the SurfaceGui's pixels.
	local width = adornee.Size.X * BANNER.pixelsPerStud
	local height = adornee.Size.Y * BANNER.pixelsPerStud
	-- Two runs of the items side by side: when the first has slid out, the second stands where it
	-- began, and the strip jumps back unseen. A run is at least `count` items of `itemShare` of the
	-- screen each — wider than the screen — so the screen is always full.
	local list = create("UIListLayout")({
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIListLayout
	local children: { Instance } = { list }
	for run = 0, 1 do
		for index, spec in items do
			table.insert(children, item(spec, run * count + index, math.round(width * BANNER.itemShare), height))
		end
	end
	local strip = create("Frame")({
		Name = "Strip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		children,
	}) :: Frame
	if count > 0 and not GuiService.ReducedMotionEnabled then
		-- A run's width is only known once the names are laid out (and again if the font comes in
		-- late), so the slide starts over whenever it changes.
		local slide: Tween? = nil
		local function run()
			local runWidth = list.AbsoluteContentSize.X / 2
			if slide then
				slide:Cancel()
			end
			strip.Position = UDim2.new()
			if runWidth <= 0 then
				return
			end
			local tween = TweenService:Create(
				strip,
				TweenInfo.new(count * BANNER.secondsPerItem, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
				{ Position = UDim2.fromOffset(-runWidth, 0) }
			)
			tween:Play()
			slide = tween
		end
		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(run)
		run()
	end
	return create("SurfaceGui")({
		Name = "RingBanner",
		Adornee = adornee,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = BANNER.pixelsPerStud,
		MaxDistance = BANNER.maxDistance,
		LightInfluence = 0,
		ClipsDescendants = true,
		strip,
	}) :: SurfaceGui
end

return table.freeze(RingBanner)
