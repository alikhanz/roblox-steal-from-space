--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The screen while a rejoin teleports the player (decision 146, docs/design/screens/rejoin.md):
-- dark glass over everything, and in the middle a plaque outlined in the own island's colour with
-- the home icon, "Reconnecting…" and a line that the progress is saved. Roblox shows it during
-- the teleport (TeleportService:SetTeleportGui), when the game's scripts no longer run: so it is
-- built still, with nothing reactive or animated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local PLAQUE_WIDTH = 320
local ICON_SIZE = 40
local LINE_GAP = 6

export type Props = {
	title: string,
	hint: string,
}

local function RejoinScreen(props: Props): ScreenGui
	local glass = Layout.glass(NEON.HOME, NEON.WINDOW_CORNER, true)
	return create("ScreenGui")({
		Name = "RejoinScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		AutoLocalize = false,
		DisplayOrder = 100,
		create("Frame")({
			Name = "Backdrop",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NEON.GLASS,
			BorderSizePixel = 0,
			create("Frame")({
				Name = "Plaque",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(PLAQUE_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = NEON.GLASS,
				create("UICorner")({ CornerRadius = NEON.WINDOW_CORNER }),
				-- Points of the reference screen, scaled up by the screen's height like the HUD.
				Layout.screenScale(),
				glass,
				Layout.padding(NEON.EDGE, NEON.EDGE),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, LINE_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					BackgroundTransparency = 1,
					Image = Icons.ICONS.Home,
					ImageColor3 = Layout.iconColor(NEON.HOME),
				}),
				create("TextLabel")({
					Name = "Title",
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_WINDOW_TITLE,
					TextColor3 = NEON.TEXT,
					TextWrapped = true,
					Text = props.title,
					Layout.textStroke(),
				}),
				create("TextLabel")({
					Name = "Hint",
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_HINT,
					TextColor3 = NEON.MUTED,
					TextWrapped = true,
					Text = props.hint,
					Layout.textStroke(),
				}),
			}),
		}),
	}) :: ScreenGui
end

return RejoinScreen
