--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- An alien in a window (docs/design/screens/alien-icons.md): its kind's icon at its tier, cut out
-- of its guardian's sheet (Config/AlienIcons), or a dark silhouette of it for one not found yet.
-- A guardian with no sheet yet shows the ball the windows had before: a disc in the tier's colour
-- with a light spot and two eyes. Fills its parent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AssetQueue = require(script.Parent.Parent.Loading.AssetQueue)
local Icons = require(script.Parent.Icons)
local LoadConfig = require(ReplicatedStorage.Shared.Config.LoadConfig)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

-- The silhouette: the icon tinted almost black, so its shape shows on the glass but not who it is.
local SILHOUETTE_COLOR = Color3.fromRGB(8, 10, 26)
-- The ball: its share of the parent, and its eyes (points).
local BALL_WIDTH = 0.66
local BALL_HEIGHT = 0.6
local EYE_SIZE = Vector2.new(4, 6)
local EYE_SPREAD = 0.2
local EYE_HEIGHT = 0.4
local EYE_COLOR = Color3.fromHex("#14141E")

export type Props = {
	icon: () -> AlienIcons.Icon?,
	-- The tier's colour, for the ball.
	color: () -> Color3,
	-- A dark silhouette instead of the icon (nothing when there is no icon).
	silhouette: (() -> boolean)?,
	-- How faded it is (a dimmed row); 0 by default.
	transparency: (() -> number)?,
}

local function Ball(props: Props, shown: () -> boolean): Frame
	local function eye(name: string, side: number): Frame
		return create("Frame")({
			Name = name,
			ZIndex = 2,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + side * EYE_SPREAD, EYE_HEIGHT),
			Size = UDim2.fromOffset(EYE_SIZE.X, EYE_SIZE.Y),
			BackgroundColor3 = EYE_COLOR,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}) :: Frame
	end
	return create("Frame")({
		Name = "Ball",
		ZIndex = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(BALL_WIDTH, BALL_HEIGHT),
		BackgroundTransparency = 1,
		Visible = shown,
		create("ImageLabel")({
			Name = "Body",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageColor3 = props.color,
		}),
		create("ImageLabel")({
			Name = "Shine",
			ZIndex = 2,
			Position = UDim2.fromScale(0.18, 0.1),
			Size = UDim2.fromScale(0.28, 0.28),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageTransparency = 0.55,
		}),
		eye("LeftEye", -1),
		eye("RightEye", 1),
	}) :: Frame
end

-- The sheets load together the first time a window draws an alien, and last of the join's
-- preloads (AssetQueue; the brief: they must not slow the way in).
local preloaded = false
local function preload()
	if preloaded then
		return
	end
	preloaded = true
	local sheets: { AssetQueue.Asset } = {}
	for _, sheet in AlienIcons.SHEETS do
		table.insert(sheets, sheet)
	end
	AssetQueue.later("alien icon sheets", LoadConfig.PRIORITY.ICONS, sheets)
end

local function AlienPicture(props: Props): Frame
	preload()
	local readIcon = props.icon :: () -> AlienIcons.Icon?
	local function silhouette(): boolean
		return props.silhouette ~= nil and props.silhouette()
	end
	local function transparency(): number
		return if props.transparency then props.transparency() else 0
	end
	return create("Frame")({
		Name = "AlienPicture",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		create("ImageLabel")({
			Name = "Icon",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = function()
				local icon = readIcon()
				return if icon then icon.image else ""
			end,
			ImageRectOffset = function()
				local icon = readIcon()
				return if icon then Vector2.new(icon.x, icon.y) else Vector2.zero
			end,
			ImageRectSize = function()
				local icon = readIcon()
				return if icon then Vector2.new(icon.size, icon.size) else Vector2.zero
			end,
			ImageColor3 = function()
				return if silhouette() then SILHOUETTE_COLOR else Color3.new(1, 1, 1)
			end,
			ImageTransparency = transparency,
			Visible = function()
				return readIcon() ~= nil
			end,
		}),
		Ball(props, function()
			return readIcon() == nil and not silhouette()
		end),
	}) :: Frame
end

return AlienPicture
