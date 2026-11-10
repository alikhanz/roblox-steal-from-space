--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- What a station kiosk shows (decision 087), drawn on its parts in this client's language: the
-- name on its plate, its icon on the round badge and, floating gently, in the hologram in its
-- opening. The icons are the HUD menu's (UI/Icons), tinted towards the kiosk's colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local PIXELS_PER_STUD = 40
-- Readable from across the platform and a little beyond; the station's look from the islands is
-- the ring's, studs.
local MAX_DISTANCE = 300
-- The badge's icon fills this share of the disc; the hologram's, of its plate's height.
local BADGE_ICON_SHARE = 0.62
local HOLO_ICON_SHARE = 0.8
-- The hologram's icon floats up and down by this share of its plate's height, every this many
-- seconds.
local HOLO_BOB_SHARE = 0.06
local HOLO_BOB_SECONDS = 1.6

local KioskSign = {}

local function surface(adornee: BasePart, face: Enum.NormalId, child: Instance): SurfaceGui
	return create("SurfaceGui")({
		Name = "KioskSign",
		Adornee = adornee,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ClipsDescendants = true,
		child,
	}) :: SurfaceGui
end

local function tinted(color: Color3): Color3
	return Color3.new(1, 1, 1):Lerp(color, StationLooks.KIOSK_ICON_TINT)
end

-- The kiosk's name across its plate's front.
function KioskSign.plate(adornee: BasePart, text: string): SurfaceGui
	return surface(
		adornee,
		Enum.NormalId.Front,
		create("TextLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.7),
			BackgroundTransparency = 1,
			FontFace = Theme.NEON.FONT,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		})
	)
end

-- The icon on the badge's disc (a cylinder turned so its Right face looks out of the front).
function KioskSign.badge(adornee: BasePart, image: string, color: Color3): SurfaceGui
	return surface(
		adornee,
		Enum.NormalId.Right,
		create("ImageLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(BADGE_ICON_SHARE, BADGE_ICON_SHARE),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = tinted(color),
			ScaleType = Enum.ScaleType.Fit,
		})
	)
end

-- The icon in the hologram's plate, floating up and down.
function KioskSign.hologram(adornee: BasePart, image: string, color: Color3): SurfaceGui
	local icon = create("ImageLabel")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5 + HOLO_BOB_SHARE),
		Size = UDim2.fromScale(HOLO_ICON_SHARE, HOLO_ICON_SHARE),
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = tinted(color),
		ScaleType = Enum.ScaleType.Fit,
	}) :: ImageLabel
	local bob = TweenService:Create(
		icon,
		TweenInfo.new(HOLO_BOB_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromScale(0.5, 0.5 - HOLO_BOB_SHARE) }
	)
	bob:Play()
	return surface(adornee, Enum.NormalId.Front, icon)
end

return table.freeze(KioskSign)
