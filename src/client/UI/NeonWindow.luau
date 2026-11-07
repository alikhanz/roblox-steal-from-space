--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The frame of a window in the neon style (DESIGN.md, "Окно"): the scene dimmed behind it, a
-- panel of dark glass with a header (title, the player's coins, a round close button), a body
-- and a footer for the actions. The window brings its own content for the body and the footer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local ResourcePill = require(script.Parent.ResourcePill)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
-- Points of the reference screen; never more than this share of the screen.
local SIZE = Vector2.new(675, 363)
local SCREEN_SHARE = 0.94
local HEADER_HEIGHT = 44
local FOOTER_HEIGHT = 50
local PADDING = 12
local CLOSE_SIZE = 32
local GLASS_TRANSPARENCY = 0.1
local WINDOW_TOP = Color3.fromHex("#181E56")
local WINDOW_BOTTOM = Color3.fromHex("#0A0C28")
local HEADER_FROM = Color3.fromHex("#50DCFF")
local HEADER_TO = Color3.fromHex("#FF50C8")
local HEADER_TRANSPARENCY = 0.82
local VEIL = Color3.fromHex("#02040E")
local VEIL_TRANSPARENCY = 0.5
-- The widest coin count (BigNum.format), so the header does not twitch.
local WIDEST_NUMBER = "88.8Qad"

export type Props = {
	name: string,
	visible: () -> boolean,
	title: string,
	-- The player's coins in the header; nil for none (a window that is about coins itself).
	coins: (() -> string)?,
	-- The largest size, points of the reference screen; a compact window passes its own.
	size: Vector2?,
	onClose: () -> (),
	-- The body's and the footer's own children.
	body: any,
	footer: any,
}

-- The header's tint: a horizontal cyan-to-pink wash. Rounded on top only: a second, square
-- piece covers the lower corners.
local function headerTint(): { Instance }
	local function piece(name: string, position: UDim2, size: UDim2, rounded: boolean): Frame
		return create("Frame")({
			Name = name,
			Position = position,
			Size = size,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = HEADER_TRANSPARENCY,
			BorderSizePixel = 0,
			ZIndex = 0,
			if rounded then create("UICorner")({ CornerRadius = NEON.WINDOW_CORNER }) else nil,
			create("UIGradient")({ Color = ColorSequence.new(HEADER_FROM, HEADER_TO) }),
		}) :: Frame
	end
	return {
		piece("Tint", UDim2.new(), UDim2.fromScale(1, 1), true),
		piece("TintSquare", UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0.5), false),
	}
end

local function CloseButton(onClose: () -> ()): TextButton
	local corner = UDim.new(0.5, 0)
	return create("TextButton")({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PADDING, 0.5, 0),
		Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			onClose()
		end,
		create("UICorner")({ CornerRadius = corner }),
		Layout.glass(NEON.DANGER, corner, true),
		create("TextLabel")({
			Name = "Cross",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_WINDOW_TITLE,
			TextColor3 = NEON.TEXT,
			Text = "×",
			Layout.textStroke(),
		}),
	}) :: TextButton
end

local function NeonWindow(props: Props): Frame
	return create("Frame")({
		Name = props.name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.visible,

		-- The dimmed scene: a tap on it closes the window (it also lies over the HUD, so a second
		-- tap on the window's menu tile closes it too, as the HUD brief wants).
		create("TextButton")({
			Name = "Veil",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = VEIL,
			BackgroundTransparency = VEIL_TRANSPARENCY,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Activated = function()
				props.onClose()
			end,
		}),
		create("Frame")({
			Name = "Window",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(SCREEN_SHARE, SCREEN_SHARE),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = GLASS_TRANSPARENCY,
			Active = true,
			create("UICorner")({ CornerRadius = NEON.WINDOW_CORNER }),
			create("UIGradient")({ Rotation = 90, Color = ColorSequence.new(WINDOW_TOP, WINDOW_BOTTOM) }),
			Layout.panelLine(),
			Layout.maxSize((props.size or SIZE).X, (props.size or SIZE).Y),
			Layout.screenScale(),

			create("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				BackgroundTransparency = 1,
				headerTint(),
				create("TextLabel")({
					Name = "Title",
					ZIndex = 1,
					Position = UDim2.fromOffset(PADDING + 4, 0),
					Size = UDim2.fromScale(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_WINDOW_TITLE,
					TextColor3 = NEON.TEXT,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = props.title,
					Layout.textStroke(),
				}),
				if props.coins
					then create("Frame")({
						Name = "CoinsSlot",
						ZIndex = 1,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -(PADDING + CLOSE_SIZE + PADDING), 0.5, 0),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						ResourcePill({
							name = "Coins",
							icon = "Coin",
							color = NEON.COINS,
							value = props.coins,
							textSize = NEON.TEXT_SECTION,
							widest = WIDEST_NUMBER,
							layoutOrder = 1,
						}),
					})
					else nil,
				CloseButton(props.onClose),
				create("Frame")({
					Name = "Line",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = NEON.LINE,
					BackgroundTransparency = 0.7,
					BorderSizePixel = 0,
				}),
			}),
			create("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, HEADER_HEIGHT),
				Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + FOOTER_HEIGHT)),
				BackgroundTransparency = 1,
				Layout.padding(PADDING, PADDING - 2),
				props.body,
			}),
			create("Frame")({
				Name = "Footer",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
				BackgroundTransparency = 1,
				create("Frame")({
					Name = "Line",
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = NEON.LINE,
					BackgroundTransparency = 0.8,
					BorderSizePixel = 0,
				}),
				create("Frame")({
					Name = "Content",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Layout.padding(PADDING, 0),
					props.footer,
				}),
			}),
		}),
	}) :: Frame
end

return NeonWindow
