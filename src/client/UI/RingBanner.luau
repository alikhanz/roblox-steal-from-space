--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The banner on a screen of the station's ring (decision 087): the kiosks' names with their icons,
-- big, running along the screen without end, so from an island or from the platform the ring
-- reads as a turning sign of what the station has. Still under reduced motion.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local BANNER = StationLooks.BANNER
-- Within an item: the icon's share of the screen's height and the gap after it, the name's share
-- of the height.
local ICON_SHARE = 0.62
local NAME_SHARE = 0.56

export type Item = {
	name: string,
	icon: string,
	color: Color3,
}

local RingBanner = {}

local function item(spec: Item, order: number, width: number): Frame
	local tint = Color3.new(1, 1, 1):Lerp(spec.color, StationLooks.KIOSK_ICON_TINT)
	return create("Frame")({
		Name = "Item",
		LayoutOrder = order,
		Size = UDim2.fromScale(width, 1),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.03, 0),
		}),
		create("ImageLabel")({
			LayoutOrder = 1,
			Size = UDim2.fromScale(ICON_SHARE, ICON_SHARE),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
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
			TextScaled = true,
		}),
	}) :: Frame
end

-- The banner on the Front face of `adornee`, running `items` from right to left.
function RingBanner.create(adornee: BasePart, items: { Item }): SurfaceGui
	local count = #items
	-- Two runs of the items side by side: when the first has slid out, the second stands where it
	-- began, and the strip jumps back unseen.
	local runShare = count * BANNER.itemShare
	local children: { Instance } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for run = 0, 1 do
		for index, spec in items do
			table.insert(children, item(spec, run * count + index, 1 / (2 * count)))
		end
	end
	local strip = create("Frame")({
		Name = "Strip",
		Size = UDim2.fromScale(2 * runShare, 1),
		BackgroundTransparency = 1,
		children,
	}) :: Frame
	if count > 0 and not GuiService.ReducedMotionEnabled then
		TweenService:Create(
			strip,
			TweenInfo.new(count * BANNER.secondsPerItem, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Position = UDim2.fromScale(-runShare, 0) }
		):Play()
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
